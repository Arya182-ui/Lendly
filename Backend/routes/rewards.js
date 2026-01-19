const express = require('express');
const admin = require('firebase-admin');
const { isValidUid } = require('../utils/validators');

const router = express.Router();
const db = admin.firestore();

// Transaction reward system
const TRANSACTION_REWARDS = {
  'completed': { lender: 50, borrower: 30 },
  'sold': { seller: 25, buyer: 0 },
  'rented': { owner: 40, renter: 0 },
  'returned_early': { bonus: 15 }
};

// Auto-award coins when transaction completes
router.post('/award-transaction-coins/:transactionId', async (req, res) => {
  try {
    const { transactionId } = req.params;
    const { status, lenderId, borrowerId, transactionType } = req.body;
    
    if (status !== 'completed') {
      return res.json({ success: true, message: 'No reward for non-completed transactions' });
    }
    
    const rewards = TRANSACTION_REWARDS[transactionType] || TRANSACTION_REWARDS['completed'];
    const batch = db.batch();
    
    // Award coins to lender/seller/owner
    if (lenderId && rewards.lender) {
      const lenderWalletRef = db.collection('wallets').doc(lenderId);
      batch.update(lenderWalletRef, {
        balance: admin.firestore.FieldValue.increment(rewards.lender),
        totalEarned: admin.firestore.FieldValue.increment(rewards.lender)
      });
      
      // Add transaction record
      const lenderTransactionRef = db.collection('transactions').doc();
      batch.set(lenderTransactionRef, {
        uid: lenderId,
        type: 'earned_transaction',
        amount: rewards.lender,
        description: `Transaction completed as ${transactionType === 'sold' ? 'seller' : 'lender'}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: { transactionId, role: 'lender' }
      });
    }
    
    // Award coins to borrower/buyer (if applicable)
    if (borrowerId && rewards.borrower) {
      const borrowerWalletRef = db.collection('wallets').doc(borrowerId);
      batch.update(borrowerWalletRef, {
        balance: admin.firestore.FieldValue.increment(rewards.borrower),
        totalEarned: admin.firestore.FieldValue.increment(rewards.borrower)
      });
      
      // Add transaction record
      const borrowerTransactionRef = db.collection('transactions').doc();
      batch.set(borrowerTransactionRef, {
        uid: borrowerId,
        type: 'earned_transaction',
        amount: rewards.borrower,
        description: `Transaction completed as ${transactionType === 'sold' ? 'buyer' : 'borrower'}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: { transactionId, role: 'borrower' }
      });
    }
    
    await batch.commit();
    
    // Trigger challenge completion check
    if (lenderId) {
      await triggerChallengeCheck(lenderId, 'transaction_completed', { transactionId });
    }
    if (borrowerId) {
      await triggerChallengeCheck(borrowerId, 'transaction_completed', { transactionId });
    }
    
    res.json({ 
      success: true, 
      message: 'Transaction rewards awarded',
      rewards: { lender: rewards.lender, borrower: rewards.borrower }
    });
  } catch (error) {
    console.error('Error awarding transaction coins:', error);
    res.status(500).json({ error: 'Failed to award transaction rewards' });
  }
});

// Helper function to trigger challenge completion check
async function triggerChallengeCheck(uid, actionType, metadata) {
  try {
    const axios = require('axios');
    const baseUrl = process.env.API_BASE_URL || 'http://localhost:4000';
    
    await axios.post(`${baseUrl}/challenges/auto-complete/${uid}`, {
      actionType,
      metadata
    });
  } catch (error) {
    console.error('Challenge trigger failed:', error.message);
    // Don't fail the main transaction
  }
}

// Daily login streak system
router.post('/daily-login/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    
    if (!isValidUid(uid)) {
      return res.status(400).json({ error: 'Invalid UID' });
    }
    
    const today = new Date().toISOString().split('T')[0];
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    
    const userDoc = await db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    const lastLoginDate = userData.lastLoginDate;
    const currentStreak = userData.loginStreak || 0;
    
    // Check if already logged in today
    if (lastLoginDate === today) {
      return res.json({ 
        success: true, 
        message: 'Already logged in today',
        streak: currentStreak,
        reward: 0
      });
    }
    
    // Calculate new streak
    let newStreak = 1;
    if (lastLoginDate === yesterday) {
      newStreak = currentStreak + 1;
    }
    
    // Calculate reward (5 base + 1 per streak day, max 25)
    const reward = Math.min(5 + newStreak - 1, 25);
    
    const batch = db.batch();
    
    // Update user login data
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      lastLoginDate: today,
      loginStreak: newStreak,
      totalLogins: admin.firestore.FieldValue.increment(1)
    });
    
    // Award coins
    const walletRef = db.collection('wallets').doc(uid);
    batch.update(walletRef, {
      balance: admin.firestore.FieldValue.increment(reward),
      totalEarned: admin.firestore.FieldValue.increment(reward)
    });
    
    // Add transaction record
    const transactionRef = db.collection('transactions').doc();
    batch.set(transactionRef, {
      uid,
      type: 'earned_daily_login',
      amount: reward,
      description: `Daily login streak day ${newStreak}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: { streak: newStreak, date: today }
    });
    
    await batch.commit();
    
    res.json({ 
      success: true, 
      message: `Login streak: ${newStreak} days!`,
      streak: newStreak,
      reward,
      isNewStreak: newStreak === 1 && lastLoginDate !== yesterday
    });
  } catch (error) {
    console.error('Error processing daily login:', error);
    res.status(500).json({ error: 'Failed to process daily login' });
  }
});

// Referral system
router.post('/process-referral', async (req, res) => {
  try {
    const { referrerUid, referredUid, referralCode } = req.body;
    
    if (!isValidUid(referrerUid) || !isValidUid(referredUid)) {
      return res.status(400).json({ error: 'Invalid UIDs' });
    }
    
    // Check if referral already exists
    const existingReferral = await db.collection('referrals')
      .where('referredUid', '==', referredUid)
      .get();
    
    if (!existingReferral.empty) {
      return res.status(400).json({ error: 'User already referred' });
    }
    
    const batch = db.batch();
    const bonusAmount = 75;
    
    // Create referral record
    const referralRef = db.collection('referrals').doc();
    batch.set(referralRef, {
      referrerUid,
      referredUid,
      referralCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'active',
      bonusAwarded: true
    });
    
    // Award coins to referrer
    const referrerWalletRef = db.collection('wallets').doc(referrerUid);
    batch.update(referrerWalletRef, {
      balance: admin.firestore.FieldValue.increment(bonusAmount),
      totalEarned: admin.firestore.FieldValue.increment(bonusAmount)
    });
    
    const referrerTransactionRef = db.collection('transactions').doc();
    batch.set(referrerTransactionRef, {
      uid: referrerUid,
      type: 'bonus_referral',
      amount: bonusAmount,
      description: 'Friend referral bonus',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: { referredUid, referralCode }
    });
    
    // Award coins to referred user
    const referredWalletRef = db.collection('wallets').doc(referredUid);
    batch.update(referredWalletRef, {
      balance: admin.firestore.FieldValue.increment(bonusAmount),
      totalEarned: admin.firestore.FieldValue.increment(bonusAmount)
    });
    
    const referredTransactionRef = db.collection('transactions').doc();
    batch.set(referredTransactionRef, {
      uid: referredUid,
      type: 'bonus_referral',
      amount: bonusAmount,
      description: 'Welcome! Referral bonus for joining',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      metadata: { referrerUid, referralCode }
    });
    
    await batch.commit();
    
    res.json({ 
      success: true, 
      message: 'Referral processed successfully',
      bonus: bonusAmount
    });
  } catch (error) {
    console.error('Error processing referral:', error);
    res.status(500).json({ error: 'Failed to process referral' });
  }
});

module.exports = router;
