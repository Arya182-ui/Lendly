const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();
const { authenticateUser, validateBody } = require('../middleware/auth');

const db = admin.firestore();

// Wallet Transaction Types
const TRANSACTION_TYPES = {
  EARNED_TRANSACTION: 'earned_transaction',
  BONUS_SIGNUP: 'bonus_signup',
  BONUS_REFERRAL: 'bonus_referral',
  BONUS_VERIFICATION: 'bonus_verification',
  SPENT_TRANSACTION: 'spent_transaction',
  SPENT_LISTING: 'spent_listing',
  ADMIN_ADJUSTMENT: 'admin_adjustment'
};

// Wallet configuration
const WALLET_CONFIG = {
  SIGNUP_BONUS: 100,
  REFERRAL_BONUS: 50,
  VERIFICATION_BONUS: 25,
  TRANSACTION_REWARD: 10,
  LISTING_COST: 5,
  INITIAL_BALANCE: 100
};

// Check if user is admin
const isAdmin = async (uid) => {
  try {
    const adminDoc = await db.collection('admins').doc(uid).get();
    return adminDoc.exists && adminDoc.data().isAdmin === true;
  } catch (error) {
    console.error('Error checking admin status:', error);
    return false;
  }
};

// Middleware to verify user can only access their own wallet
const verifyWalletAccess = (req, res, next) => {
  const { uid } = req.params;
  const requestingUid = req.uid;
  
  if (uid !== requestingUid) {
    return res.status(403).json({
      success: false,
      error: 'Access denied. You can only access your own wallet.'
    });
  }
  
  next();
};

// Middleware to verify admin access
const verifyAdminAccess = async (req, res, next) => {
  try {
    const requestingUid = req.uid;
    const adminStatus = await isAdmin(requestingUid);
    
    if (!adminStatus) {
      return res.status(403).json({
        success: false,
        error: 'Access denied. Admin privileges required.'
      });
    }
    
    next();
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: 'Failed to verify admin status'
    });
  }
};

// Initialize user wallet
const initializeWallet = async (uid) => {
  try {
    const walletRef = db.collection('wallets').doc(uid);
    const walletDoc = await walletRef.get();
    
    if (!walletDoc.exists) {
      const initialWallet = {
        uid: uid,
        balance: WALLET_CONFIG.INITIAL_BALANCE,
        totalEarned: WALLET_CONFIG.INITIAL_BALANCE,
        totalSpent: 0,
        transactionCount: 0,
        createdAt: new Date(),
        updatedAt: new Date()
      };
      
      await walletRef.set(initialWallet);
      
      // Create initial transaction record
      await addTransaction(uid, WALLET_CONFIG.INITIAL_BALANCE, TRANSACTION_TYPES.BONUS_SIGNUP, 'Welcome bonus');
      
      return initialWallet;
    }
    
    return walletDoc.data();
  } catch (error) {
    console.error('Error initializing wallet:', error);
    throw error;
  }
};

// Add transaction to wallet using Firestore transaction (race-condition safe)
const addTransaction = async (uid, amount, type, description, relatedId = null) => {
  const walletRef = db.collection('wallets').doc(uid);
  const transactionsRef = db.collection('wallet_transactions');
  
  try {
    // Use Firestore transaction for atomic operations
    const result = await db.runTransaction(async (transaction) => {
      // Read wallet data
      const walletDoc = await transaction.get(walletRef);
      
      if (!walletDoc.exists) {
        throw new Error('Wallet not found');
      }
      
      const currentWallet = walletDoc.data();
      const isEarning = type.startsWith('earned_') || type.startsWith('bonus_');
      
      // Calculate new balance
      const newBalance = isEarning 
        ? currentWallet.balance + amount 
        : currentWallet.balance - amount;
      
      // Prevent negative balance at DB level
      if (!isEarning && newBalance < 0) {
        throw new Error('Insufficient balance');
      }
      
      // Validate amount is positive
      if (amount <= 0) {
        throw new Error('Amount must be positive');
      }
      
      // Create transaction record with integrity hash
      const transactionDoc = transactionsRef.doc();
      const transactionData = {
        uid: uid,
        amount: amount,
        type: type,
        description: description,
        relatedId: relatedId,
        balanceBefore: currentWallet.balance,
        balanceAfter: newBalance,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        timestamp: Date.now(),
        // Add integrity hash to prevent tampering
        integrityHash: generateIntegrityHash({
          uid,
          amount,
          type,
          balanceBefore: currentWallet.balance,
          balanceAfter: newBalance,
          timestamp: Date.now()
        })
      };
      
      // Update wallet with new balance
      const walletUpdate = {
        balance: newBalance,
        totalEarned: isEarning ? currentWallet.totalEarned + amount : currentWallet.totalEarned,
        totalSpent: !isEarning ? currentWallet.totalSpent + amount : currentWallet.totalSpent,
        transactionCount: currentWallet.transactionCount + 1,
        lastTransactionAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      // Perform atomic updates
      transaction.update(walletRef, walletUpdate);
      transaction.set(transactionDoc, transactionData);
      
      return {
        transaction: transactionData,
        newBalance: newBalance
      };
    });
    
    return result;
  } catch (error) {
    console.error('Error adding transaction:', error);
    throw error;
  }
};

// Generate integrity hash for transaction verification
const generateIntegrityHash = (data) => {
  const crypto = require('crypto');
  const stringToHash = `${data.uid}:${data.amount}:${data.type}:${data.balanceBefore}:${data.balanceAfter}:${data.timestamp}`;
  return crypto.createHash('sha256').update(stringToHash).digest('hex');
};

// Get user wallet - Protected route, users can only access their own wallet
router.get('/:uid', authenticateUser, verifyWalletAccess, async (req, res) => {
  try {
    const { uid } = req.params;
    
    let wallet = await db.collection('wallets').doc(uid).get();
    
    if (!wallet.exists) {
      // Initialize wallet if it doesn't exist
      const newWallet = await initializeWallet(uid);
      return res.status(200).json({
        success: true,
        wallet: newWallet
      });
    }
    
    res.status(200).json({
      success: true,
      wallet: wallet.data()
    });
  } catch (error) {
    console.error('Error getting wallet:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get wallet'
    });
  }
});

// Get transaction history - Protected route, users can only access their own transactions
router.get('/:uid/transactions', authenticateUser, verifyWalletAccess, async (req, res) => {
  try {
    const { uid } = req.params;
    const { limit = 20, offset = 0, type } = req.query;
    
    let query = db.collection('wallet_transactions')
      .where('uid', '==', uid)
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit));
    
    if (type && type !== 'all') {
      query = query.where('type', '==', type);
    }
    
    if (offset > 0) {
      // For pagination, you'd need to implement proper cursor-based pagination
      // This is a simplified version
    }
    
    const snapshot = await query.get();
    const transactions = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      transactions.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate(),
      });
    });
    
    res.status(200).json({
      success: true,
      transactions: transactions,
      hasMore: transactions.length === parseInt(limit)
    });
  } catch (error) {
    console.error('Error getting transactions:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get transactions'
    });
  }
});

// Award points - ADMIN ONLY route for awarding points
router.post('/:uid/award', authenticateUser, verifyAdminAccess, validateBody(['amount', 'type', 'description']), async (req, res) => {
  try {
    const { uid } = req.params;
    const { amount, type, description, relatedId } = req.body;
    const adminUid = req.uid;
    
    // Validate amount is positive
    if (amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Amount must be positive'
      });
    }
    
    // Validate type is an earning type
    if (!type.startsWith('earned_') && !type.startsWith('bonus_')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid transaction type for awarding points'
      });
    }
    
    const enhancedDescription = `[Admin ${adminUid}] ${description}`;
    const result = await addTransaction(uid, amount, type, enhancedDescription, relatedId);
    
    // Log admin action
    await db.collection('admin_actions').add({
      adminUid: adminUid,
      action: 'award_points',
      targetUid: uid,
      amount: amount,
      type: type,
      description: description,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({
      success: true,
      transaction: result.transaction,
      newBalance: result.newBalance
    });
  } catch (error) {
    console.error('Error awarding points:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to award points'
    });
  }
});

// Spend points - Protected route, users can only spend from their own wallet
router.post('/:uid/spend', authenticateUser, verifyWalletAccess, validateBody(['amount', 'type', 'description']), async (req, res) => {
  try {
    const { uid } = req.params;
    const { amount, type, description, relatedId } = req.body;
    
    // Validate amount is positive
    if (amount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Amount must be positive'
      });
    }
    
    // Validate type is a spending type
    if (!type.startsWith('spent_')) {
      return res.status(400).json({
        success: false,
        error: 'Invalid transaction type for spending points'
      });
    }
    
    const result = await addTransaction(uid, amount, type, description, relatedId);
    
    res.status(200).json({
      success: true,
      transaction: result.transaction,
      newBalance: result.newBalance
    });
  } catch (error) {
    console.error('Error spending points:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to spend points'
    });
  }
});

// Get wallet statistics - Protected route, users can only access their own stats
router.get('/:uid/stats', authenticateUser, verifyWalletAccess, async (req, res) => {
  try {
    const { uid } = req.params;
    const { period = '30d' } = req.query;
    
    // Get wallet
    const walletDoc = await db.collection('wallets').doc(uid).get();
    if (!walletDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'Wallet not found'
      });
    }
    
    const wallet = walletDoc.data();
    
    // Calculate period start date
    const now = new Date();
    let startDate = new Date();
    
    switch (period) {
      case '7d':
        startDate.setDate(now.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(now.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(now.getDate() - 90);
        break;
      case '1y':
        startDate.setFullYear(now.getFullYear() - 1);
        break;
      default:
        startDate.setDate(now.getDate() - 30);
    }
    
    // Get transactions for period
    const transactionsSnapshot = await db.collection('wallet_transactions')
      .where('uid', '==', uid)
      .where('createdAt', '>=', startDate)
      .get();
    
    let periodEarned = 0;
    let periodSpent = 0;
    const transactionsByType = {};
    
    transactionsSnapshot.forEach(doc => {
      const transaction = doc.data();
      const isEarning = transaction.type.startsWith('earned_') || transaction.type.startsWith('bonus_');
      
      if (isEarning) {
        periodEarned += transaction.amount;
      } else {
        periodSpent += transaction.amount;
      }
      
      if (!transactionsByType[transaction.type]) {
        transactionsByType[transaction.type] = { count: 0, total: 0 };
      }
      transactionsByType[transaction.type].count++;
      transactionsByType[transaction.type].total += transaction.amount;
    });
    
    const stats = {
      currentBalance: wallet.balance,
      totalEarned: wallet.totalEarned,
      totalSpent: wallet.totalSpent,
      transactionCount: wallet.transactionCount,
      period: {
        earned: periodEarned,
        spent: periodSpent,
        net: periodEarned - periodSpent,
        transactionCount: transactionsSnapshot.size
      },
      transactionsByType: transactionsByType
    };
    
    res.status(200).json({
      success: true,
      stats: stats
    });
  } catch (error) {
    console.error('Error getting wallet stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get wallet statistics'
    });
  }
});

// Admin: Adjust wallet balance - ADMIN ONLY
router.post('/:uid/admin/adjust', authenticateUser, verifyAdminAccess, validateBody(['amount', 'description']), async (req, res) => {
  try {
    const { uid } = req.params;
    const { amount, description } = req.body;
    const adminUid = req.uid;
    
    if (amount === 0) {
      return res.status(400).json({
        success: false,
        error: 'Amount cannot be zero'
      });
    }
    
    const type = amount > 0 ? TRANSACTION_TYPES.ADMIN_ADJUSTMENT : TRANSACTION_TYPES.ADMIN_ADJUSTMENT;
    const adjustmentAmount = Math.abs(amount);
    const enhancedDescription = `[Admin ${adminUid}] ${description}`;
    
    const result = await addTransaction(
      uid, 
      adjustmentAmount, 
      type, 
      enhancedDescription, 
      adminUid
    );
    
    // Log admin action
    await db.collection('admin_actions').add({
      adminUid: adminUid,
      action: 'adjust_wallet',
      targetUid: uid,
      amount: amount,
      description: description,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({
      success: true,
      transaction: result.transaction,
      newBalance: result.newBalance
    });
  } catch (error) {
    console.error('Error adjusting wallet:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Failed to adjust wallet'
    });
  }
});

// Collect welcome bonus
router.post('/collect-welcome-bonus', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.body;
    
    if (!uid || uid !== req.uid) {
      return res.status(403).json({ error: 'Unauthorized access' });
    }
    
    // Check if user already collected welcome bonus
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    if (userData.welcomeBonusCollected) {
      return res.status(400).json({ error: 'Welcome bonus already collected' });
    }
    
    // Award welcome bonus using existing addTransaction function
    await addTransaction(uid, {
      amount: 100,
      type: TRANSACTION_TYPES.BONUS_SIGNUP,
      description: 'Welcome to Lendly! Enjoy your bonus coins',
      metadata: { reason: 'welcome_bonus' }
    });
    
    // Mark as collected
    await db.collection('users').doc(uid).update({
      welcomeBonusCollected: true,
      welcomeBonusCollectedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true, 
      message: 'Welcome bonus collected!',
      amount: 100
    });
  } catch (error) {
    console.error('Error collecting welcome bonus:', error);
    res.status(500).json({ error: 'Failed to collect welcome bonus' });
  }
});

// Export utility functions for use in other routes
module.exports = {
  router,
  initializeWallet,
  addTransaction,
  TRANSACTION_TYPES,
  WALLET_CONFIG
};
