const express = require('express');
const admin = require('firebase-admin');
const { sanitizeHtml } = require('../utils/validators');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { authenticateUser } = require('../middleware/auth');
const { validateBody, validateQuery, validateParams } = require('../middleware/validation');
const transactionSchemas = require('../validation/transactions.schemas');
const { TrustScoreManager } = require('../utils/trust-score-manager');
const { CoinsManager } = require('../utils/coins-manager');
const { LendlyQueryOptimizer } = require('../utils/advanced-query-optimizer');
const { globalPaginationManager, extractPaginationParams, formatPaginatedResponse } = require('../utils/advanced-pagination');

const router = express.Router();
const db = admin.firestore();

// Transaction state machine
const TRANSACTION_STATES = {
  PENDING: 'pending',
  ACCEPTED: 'accepted',
  REJECTED: 'rejected',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled'
};

// Valid state transitions
const VALID_TRANSITIONS = {
  [TRANSACTION_STATES.PENDING]: [TRANSACTION_STATES.ACCEPTED, TRANSACTION_STATES.REJECTED, TRANSACTION_STATES.CANCELLED],
  [TRANSACTION_STATES.ACCEPTED]: [TRANSACTION_STATES.COMPLETED, TRANSACTION_STATES.CANCELLED],
  [TRANSACTION_STATES.REJECTED]: [],
  [TRANSACTION_STATES.COMPLETED]: [],
  [TRANSACTION_STATES.CANCELLED]: []
};

const TRANSACTION_TYPES_LIST = ['borrow', 'lend', 'exchange', 'donate'];

// Validate state transition
const canTransition = (currentState, newState) => {
  const allowedTransitions = VALID_TRANSITIONS[currentState] || [];
  return allowedTransitions.includes(newState);
};

// Check if user can perform action on transaction
const canPerformAction = (transaction, userId, action) => {
  switch (action) {
    case 'accept':
    case 'reject':
      return transaction.itemOwnerId === userId && transaction.status === TRANSACTION_STATES.PENDING;
    case 'complete':
      return (transaction.requesterId === userId || transaction.itemOwnerId === userId) 
             && transaction.status === TRANSACTION_STATES.ACCEPTED;
    case 'cancel':
      return transaction.requesterId === userId 
             && (transaction.status === TRANSACTION_STATES.PENDING || transaction.status === TRANSACTION_STATES.ACCEPTED);
    default:
      return false;
  }
};

// POST /transactions/request - Create a transaction request with atomic item locking
router.post('/request', authenticateUser, validateBody(transactionSchemas.createRequest), async (req, res) => {
  try {
    const { 
      requesterId, 
      itemOwnerId, 
      itemId, 
      type, 
      message, 
      duration, 
      proposedPrice 
    } = req.body;
    
    // Verify authenticated user matches requester
    if (req.user.uid !== requesterId) {
      return res.status(403).json({ error: 'Cannot create request for another user' });
    }
    
    // Cannot request your own item
    if (requesterId === itemOwnerId) {
      return res.status(400).json({ error: 'Cannot request your own item' });
    }
    
    // Use Firestore transaction to atomically lock item and create request
    const transactionResult = await db.runTransaction(async (transaction) => {
      const itemRef = db.collection('items').doc(itemId);
      const itemDoc = await transaction.get(itemRef);
      
      if (!itemDoc.exists) {
        throw new Error('Item not found');
      }
      
      const itemData = itemDoc.data();
      
      // Verify item is available
      if (itemData.available !== true) {
        throw new Error('Item is not available');
      }
      
      if (itemData.ownerId !== itemOwnerId) {
        throw new Error('Invalid item owner');
      }
      
      // Check for existing pending request for this item
      const existingRequests = await transaction.get(
        db.collection('transactions')
          .where('itemId', '==', itemId)
          .where('status', '==', TRANSACTION_STATES.PENDING)
          .limit(1)
      );
      
      if (!existingRequests.empty) {
        throw new Error('This item already has a pending request');
      }
      
      // Check if requester already has pending request for this item
      const requesterPending = await transaction.get(
        db.collection('transactions')
          .where('requesterId', '==', requesterId)
          .where('itemId', '==', itemId)
          .where('status', '==', TRANSACTION_STATES.PENDING)
          .limit(1)
      );
      
      if (!requesterPending.empty) {
        throw new Error('You already have a pending request for this item');
      }
      
      // Create transaction request
      const transactionData = {
        requesterId,
        itemOwnerId,
        itemId,
        itemName: itemData.name,
        itemImage: itemData.image || '',
        type,
        status: TRANSACTION_STATES.PENDING,
        message: message ? sanitizeHtml(message) : '',
        duration: duration || null,
        proposedPrice: proposedPrice || itemData.price || 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      const newTransactionRef = db.collection('transactions').doc();
      transaction.set(newTransactionRef, transactionData);
      
      return { id: newTransactionRef.id, ...transactionData };
    });
    
    // Send notification to item owner
    await db.collection('notifications').add({
      userId: itemOwnerId,
      type: 'transaction_request',
      title: `New ${type} request`,
      message: `Someone wants to ${type} your ${transactionResult.itemName}`,
      data: {
        transactionId: transactionResult.id,
        itemId,
        requesterId
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(201).json({ 
      success: true, 
      transactionId: transactionResult.id,
      transaction: transactionResult
    });
    
  } catch (err) {
    console.error('Error creating transaction request:', err);
    const errorMessage = err.message || 'Failed to create transaction request';
    const statusCode = errorMessage.includes('not found') ? 404 : 
                       errorMessage.includes('not available') || errorMessage.includes('already has') ? 400 : 500;
    res.status(statusCode).json({ error: errorMessage });
  }
});

// GET /transactions/my/:uid - Get user's transactions
router.get('/my/:uid', validateQuery(transactionSchemas.getMyTransactions), async (req, res) => {
  try {
    const { uid } = req.params;
    const { type, status, limit } = req.query;
    
    let query;
    
    if (type === 'requested') {
      query = db.collection('transactions').where('requesterId', '==', uid);
    } else if (type === 'received') {
      query = db.collection('transactions').where('itemOwnerId', '==', uid);
    } else {
      // Get both - transactions where user is requester OR owner
      const [requestedSnap, receivedSnap] = await Promise.all([
        db.collection('transactions')
          .where('requesterId', '==', uid)
          .orderBy('createdAt', 'desc')
          .limit(limit)
          .get(),
        db.collection('transactions')
          .where('itemOwnerId', '==', uid)
          .orderBy('createdAt', 'desc')
          .limit(limit)
          .get()
      ]);
      
      const transactions = [
        ...requestedSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), role: 'requester' })),
        ...receivedSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), role: 'owner' }))
      ].sort((a, b) => {
        const aTime = a.createdAt?.toDate?.() || new Date(0);
        const bTime = b.createdAt?.toDate?.() || new Date(0);
        return bTime - aTime;
      }).slice(0, limit);
      
      return res.json(transactions);
    }
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    const snapshot = await query
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();
      
    const transactions = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      role: type === 'requested' ? 'requester' : 'owner'
    }));
    
    res.json(transactions);
    
  } catch (err) {
    console.error('Error fetching transactions:', err);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// POST /transactions/:id/respond - Accept/reject a transaction request
router.post('/:id/respond', authenticateUser, validateParams(transactionSchemas.transactionId), validateBody(transactionSchemas.respondToRequest), async (req, res) => {
  try {
    const { id } = req.params;
    const { ownerId, action, message } = req.body;
    
    // Verify authenticated user matches owner
    if (req.user.uid !== ownerId) {
      return res.status(403).json({ error: 'Cannot respond to another user\'s transaction' });
    }
    
    // Use Firestore transaction for atomic updates
    const result = await db.runTransaction(async (transaction) => {
      const transactionRef = db.collection('transactions').doc(id);
      const transactionDoc = await transaction.get(transactionRef);
      
      if (!transactionDoc.exists) {
        throw new Error('Transaction not found');
      }
      
      const transactionData = transactionDoc.data();
      
      if (transactionData.itemOwnerId !== ownerId) {
        throw new Error('Only the item owner can respond to this request');
      }
      
      // Verify permission
      if (!canPerformAction(transactionData, ownerId, action)) {
        throw new Error(`Cannot ${action} transaction in ${transactionData.status} state`);
      }
      
      const newStatus = action === 'accept' ? TRANSACTION_STATES.ACCEPTED : TRANSACTION_STATES.REJECTED;
      
      // Validate state transition
      if (!canTransition(transactionData.status, newStatus)) {
        throw new Error(`Invalid state transition from ${transactionData.status} to ${newStatus}`);
      }
      
      const updateData = {
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        responseMessage: message ? sanitizeHtml(message) : null
      };
      
      transaction.update(transactionRef, updateData);
      
      // If accepted, mark item as unavailable and deduct points from requester wallet
      if (action === 'accept') {
        const itemRef = db.collection('items').doc(transactionData.itemId);
        transaction.update(itemRef, {
          available: false,
          currentBorrowerId: transactionData.requesterId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Deduct points from requester's wallet
        const requesterWalletRef = db.collection('wallets').doc(transactionData.requesterId);
        const requesterWalletDoc = await transaction.get(requesterWalletRef);
        
        if (!requesterWalletDoc.exists) {
          throw new Error('Requester wallet not found');
        }
        
        const requesterWallet = requesterWalletDoc.data();
        const cost = transactionData.proposedPrice || 0;
        
        if (cost > 0) {
          if (requesterWallet.balance < cost) {
            throw new Error('Insufficient balance');
          }
          
          transaction.update(requesterWalletRef, {
            balance: admin.firestore.Firestore.FieldValue.increment(-cost),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Add wallet transaction for deduction
          const walletTransactionRef = db.collection('walletTransactions').doc();
          transaction.set(walletTransactionRef, {
            userId: transactionData.requesterId,
            type: TRANSACTION_TYPES.SPEND,
            amount: -cost,
            description: `Borrowed ${transactionData.itemName}`,
            metadata: {
              transactionId: id,
              itemId: transactionData.itemId
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        // Reject all other pending requests for this item
        const otherRequestsSnapshot = await transaction.get(
          db.collection('transactions')
            .where('itemId', '==', transactionData.itemId)
            .where('status', '==', TRANSACTION_STATES.PENDING)
        );
        
        otherRequestsSnapshot.docs.forEach(doc => {
          if (doc.id !== id) {
            transaction.update(doc.ref, {
              status: TRANSACTION_STATES.REJECTED,
              responseMessage: 'Item no longer available',
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
        });
      }
      
      return { ...transactionData, ...updateData, id };
    });
    
    // Send notification to requester
    await db.collection('notifications').add({
      userId: result.requesterId,
      type: `transaction_${action}ed`,
      title: `Request ${action}ed`,
      message: `Your ${result.type} request for ${result.itemName} was ${action}ed`,
      data: {
        transactionId: id,
        itemId: result.itemId
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true, 
      transaction: result
    });
    
  } catch (err) {
    console.error('Error responding to transaction:', err);
    const errorMessage = err.message || 'Failed to respond to transaction';
    const statusCode = errorMessage.includes('not found') ? 404 :
                       errorMessage.includes('Cannot') || errorMessage.includes('Invalid') || errorMessage.includes('Insufficient') ? 400 :
                       errorMessage.includes('Only the item owner') ? 403 : 500;
    res.status(statusCode).json({ error: errorMessage });
  }
});

// POST /transactions/:id/complete - Mark transaction as completed
router.post('/:id/complete', authenticateUser, validateParams(transactionSchemas.transactionId), validateBody(transactionSchemas.completeTransaction), async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, rating, review } = req.body;
    
    // Verify authenticated user matches userId
    if (req.user.uid !== userId) {
      return res.status(403).json({ error: 'Cannot complete transaction for another user' });
    }
    
    // Use Firestore transaction for atomic completion
    const result = await db.runTransaction(async (transaction) => {
      const transactionRef = db.collection('transactions').doc(id);
      const transactionDoc = await transaction.get(transactionRef);
      
      if (!transactionDoc.exists) {
        throw new Error('Transaction not found');
      }
      
      const transactionData = transactionDoc.data();
      
      // Verify permission
      if (!canPerformAction(transactionData, userId, 'complete')) {
        throw new Error(`Cannot complete transaction in ${transactionData.status} state`);
      }
      
      // Validate state transition
      if (!canTransition(transactionData.status, TRANSACTION_STATES.COMPLETED)) {
        throw new Error(`Invalid state transition from ${transactionData.status} to ${TRANSACTION_STATES.COMPLETED}`);
      }
      
      const isRequester = userId === transactionData.requesterId;
      const otherUserId = isRequester ? transactionData.itemOwnerId : transactionData.requesterId;
      
      // Update transaction status
      transaction.update(transactionRef, {
        status: TRANSACTION_STATES.COMPLETED,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        [`${isRequester ? 'requester' : 'owner'}Rating`]: rating,
        [`${isRequester ? 'requester' : 'owner'}Review`]: review ? sanitizeHtml(review) : null
      });
      
      // Mark item as available again and remove current borrower
      const itemRef = db.collection('items').doc(transactionData.itemId);
      transaction.update(itemRef, {
        available: true,
        currentBorrowerId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Note: Wallet rewards now handled by CoinsManager after transaction commit
      
      // Update user stats
      const requesterRef = db.collection('users').doc(transactionData.requesterId);
      const ownerRef = db.collection('users').doc(transactionData.itemOwnerId);
      
      transaction.update(requesterRef, {
        borrowed: admin.firestore.FieldValue.increment(1)
      });
      
      transaction.update(ownerRef, {
        lent: admin.firestore.FieldValue.increment(1)
      });
      
      // Update ratings if provided
      if (rating) {
        const otherUserRef = db.collection('users').doc(otherUserId);
        transaction.update(otherUserRef, {
          totalRatings: admin.firestore.FieldValue.increment(1),
          rating: admin.firestore.FieldValue.increment(rating)
        });
      }
      
      return { ...transactionData, status: TRANSACTION_STATES.COMPLETED, id };
    });
    
    // === POST-TRANSACTION: TRUST SCORE & COINS INTEGRATION ===
    const isRequester = userId === result.requesterId;
    const isOwner = userId === result.itemOwnerId;
    
    // Check if this is user's first transaction
    const userTransactionsSnap = await db.collection('transactions')
      .where('requesterId', '==', userId)
      .where('status', '==', TRANSACTION_STATES.COMPLETED)
      .limit(2) // Get 2 to check if this is the first
      .get();
    const isFirstTransaction = userTransactionsSnap.size === 1; // Only this transaction
    
    // Update Trust Score for transaction completion
    try {
      if (isRequester) {
        await TrustScoreManager.onTransactionComplete(
          userId,
          result.type || 'borrow',
          { transactionId: id, role: 'borrower' }
        );
        console.log(`[TRANSACTION] Trust score updated for borrower ${userId}`);
      }
      
      if (isOwner) {
        await TrustScoreManager.onTransactionComplete(
          userId,
          'lend',
          { transactionId: id, role: 'lender' }
        );
        console.log(`[TRANSACTION] Trust score updated for lender ${userId}`);
      }
    } catch (trustError) {
      console.error('[TRANSACTION] Failed to update trust score:', trustError);
    }
    
    // Award coins for transaction completion
    try {
      if (isRequester) {
        await CoinsManager.onTransactionComplete(
          userId,
          result.type || 'borrow',
          isFirstTransaction,
          id
        );
        console.log(`[TRANSACTION] Coins awarded to borrower ${userId}`);
      }
      
      if (isOwner) {
        await CoinsManager.onTransactionComplete(
          userId,
          'lend',
          false, // Owner doesn't get first transaction bonus
          id
        );
        console.log(`[TRANSACTION] Coins awarded to lender ${userId}`);
      }
    } catch (coinsError) {
      console.error('[TRANSACTION] Failed to award coins:', coinsError);
    }
    
    // Update Trust Score and award bonus for high rating
    if (rating && rating >= 4) {
      try {
        const otherUserId = isRequester ? result.itemOwnerId : result.requesterId;
        await TrustScoreManager.onRatingReceived(otherUserId, rating, { transactionId: id });
        
        if (rating >= 5) {
          await CoinsManager.onHighRating(otherUserId, rating, id);
        }
        console.log(`[TRANSACTION] Trust score and coins updated for rating ${rating}`);
      } catch (ratingError) {
        console.error('[TRANSACTION] Failed to process rating rewards:', ratingError);
      }
    }
    
    // Notify other user
    const otherUserId = result.requesterId === userId ? result.itemOwnerId : result.requesterId;
    await db.collection('notifications').add({
      userId: otherUserId,
      type: 'transaction_completed',
      title: 'Transaction completed',
      message: `Transaction for ${result.itemName} has been completed`,
      data: {
        transactionId: id,
        itemId: result.itemId
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true, 
      transaction: result
    });
    
  } catch (err) {
    console.error('Error completing transaction:', err);
    const errorMessage = err.message || 'Failed to complete transaction';
    const statusCode = errorMessage.includes('not found') ? 404 :
                       errorMessage.includes('Cannot') || errorMessage.includes('Invalid') ? 400 :
                       errorMessage.includes('Unauthorized') ? 403 : 500;
    res.status(statusCode).json({ error: errorMessage });
  }
});

// POST /transactions/:id/cancel - Cancel a transaction request
router.post('/:id/cancel', authenticateUser, validateParams(transactionSchemas.transactionId), validateBody(transactionSchemas.cancelTransaction), async (req, res) => {
  try {
    const { id } = req.params;
    const { userId } = req.body;
    
    // Verify authenticated user matches userId
    if (req.user.uid !== userId) {
      return res.status(403).json({ error: 'Cannot cancel transaction for another user' });
    }
    
    // Use Firestore transaction for atomic cancellation
    const result = await db.runTransaction(async (transaction) => {
      const transactionRef = db.collection('transactions').doc(id);
      const transactionDoc = await transaction.get(transactionRef);
      
      if (!transactionDoc.exists) {
        throw new Error('Transaction not found');
      }
      
      const transactionData = transactionDoc.data();
      
      // Verify permission
      if (!canPerformAction(transactionData, userId, 'cancel')) {
        throw new Error(`Cannot cancel transaction in ${transactionData.status} state`);
      }
      
      // Validate state transition
      if (!canTransition(transactionData.status, TRANSACTION_STATES.CANCELLED)) {
        throw new Error(`Invalid state transition from ${transactionData.status} to ${TRANSACTION_STATES.CANCELLED}`);
      }
      
      // Update transaction status
      transaction.update(transactionRef, {
        status: TRANSACTION_STATES.CANCELLED,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // If transaction was accepted, refund points and mark item as available
      if (transactionData.status === TRANSACTION_STATES.ACCEPTED) {
        const cost = transactionData.proposedPrice || 0;
        
        if (cost > 0) {
          // Refund points to requester
          const requesterWalletRef = db.collection('wallets').doc(transactionData.requesterId);
          transaction.update(requesterWalletRef, {
            balance: admin.firestore.FieldValue.increment(cost),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          // Add wallet transaction for refund
          const walletTransactionRef = db.collection('walletTransactions').doc();
          transaction.set(walletTransactionRef, {
            userId: transactionData.requesterId,
            type: TRANSACTION_TYPES.REFUND,
            amount: cost,
            description: `Refund for cancelled ${transactionData.itemName}`,
            metadata: {
              transactionId: id,
              itemId: transactionData.itemId
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        // Mark item as available again
        const itemRef = db.collection('items').doc(transactionData.itemId);
        transaction.update(itemRef, {
          available: true,
          currentBorrowerId: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }
      
      return { ...transactionData, status: TRANSACTION_STATES.CANCELLED, id };
    });
    
    // Notify other user
    const otherUserId = result.requesterId === userId ? result.itemOwnerId : result.requesterId;
    await db.collection('notifications').add({
      userId: otherUserId,
      type: 'transaction_cancelled',
      title: 'Transaction cancelled',
      message: `Transaction for ${result.itemName} has been cancelled`,
      data: {
        transactionId: id,
        itemId: result.itemId
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true, 
      transaction: result
    });
    
  } catch (err) {
    console.error('Error cancelling transaction:', err);
    const errorMessage = err.message || 'Failed to cancel transaction';
    const statusCode = errorMessage.includes('not found') ? 404 :
                       errorMessage.includes('Cannot') || errorMessage.includes('Invalid') ? 400 : 500;
    res.status(statusCode).json({ error: errorMessage });
  }
});

// POST /transactions/:id/mark-late - Mark transaction as late return
router.post('/:id/mark-late', authenticateUser, async (req, res) => {
  try {
    const { id } = req.params;
    const { itemOwnerId, daysLate } = req.body;
    
    // Verify authenticated user is the item owner
    if (req.user.uid !== itemOwnerId) {
      return res.status(403).json({ error: 'Only item owner can mark as late' });
    }
    
    if (!daysLate || daysLate < 1) {
      return res.status(400).json({ error: 'Days late must be at least 1' });
    }
    
    const transactionRef = db.collection('transactions').doc(id);
    const transactionDoc = await transactionRef.get();
    
    if (!transactionDoc.exists) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    
    const transactionData = transactionDoc.data();
    
    if (transactionData.itemOwnerId !== itemOwnerId) {
      return res.status(403).json({ error: 'You are not the owner of this transaction' });
    }
    
    if (transactionData.status !== TRANSACTION_STATES.ACCEPTED) {
      return res.status(400).json({ error: 'Only active transactions can be marked as late' });
    }
    
    // Update transaction with late marker
    await transactionRef.update({
      isLate: true,
      daysLate,
      markedLateAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Apply trust score penalty for late return
    try {
      await TrustScoreManager.onLateReturn(
        transactionData.requesterId,
        daysLate,
        { transactionId: id, itemName: transactionData.itemName }
      );
      console.log(`[LATE] Trust score penalty applied to ${transactionData.requesterId} for ${daysLate} days late`);
    } catch (trustError) {
      console.error('[LATE] Failed to apply trust score penalty:', trustError);
    }
    
    // Notify borrower
    await db.collection('notifications').add({
      userId: transactionData.requesterId,
      type: 'late_return_warning',
      title: '⚠️ Late Return Notice',
      message: `Your return of ${transactionData.itemName} is ${daysLate} day(s) late. Please return it as soon as possible.`,
      data: {
        transactionId: id,
        itemId: transactionData.itemId,
        daysLate
      },
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({
      success: true,
      message: 'Transaction marked as late',
      daysLate,
      penaltyApplied: true
    });
    
  } catch (err) {
    console.error('Error marking transaction as late:', err);
    res.status(500).json({ error: 'Failed to mark transaction as late' });
  }
});

// --- GET OPTIMIZED TRANSACTION HISTORY ---
router.get('/history/:userId', authenticateUser, async (req, res) => {
  try {
    const { userId } = req.params;
    const { status, type } = req.query;
    const paginationParams = extractPaginationParams(req);
    
    // Verify user can access this data
    if (req.user.uid !== userId) {
      return res.status(403).json({ error: 'Cannot access another user\'s transaction history' });
    }
    
    // Use optimized query with composite indexes
    const result = await LendlyQueryOptimizer.getTransactionHistory({
      userId,
      status,
      type,
      limit: paginationParams.pageSize,
      cursor: paginationParams.cursor
    });
    
    // Format response with pagination metadata
    const response = formatPaginatedResponse(
      result,
      `/api/transactions/history/${userId}`,
      req
    );
    
    res.json(response);
    
  } catch (err) {
    console.error('Error fetching transaction history:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch transaction history',
      details: err.message 
    });
  }
});

module.exports = router;
