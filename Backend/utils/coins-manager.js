const admin = require('firebase-admin');
const db = admin.firestore();

const COIN_CONFIG = {
  // Earning opportunities
  EARNINGS: {
    ID_VERIFICATION: 100,
    COMPLETE_LEND: 50,
    COMPLETE_BORROW: 30,
    COMPLETE_RENT: 40,
    COMPLETE_SALE: 25,
    REFERRAL_BONUS: 75,
    DAILY_STREAK_BASE: 5,
    DAILY_STREAK_MAX: 25,
    ACHIEVEMENT_BASE: 50,
    ACHIEVEMENT_MAX: 200,
    RATING_5_STAR_BONUS: 10,
    EARLY_RETURN_BONUS: 15,
    FIRST_TRANSACTION: 100
  },

  // Spending costs
  COSTS: {
    LIST_ITEM: 10,
    BOOST_LISTING_7D: 50,
    PREMIUM_BADGE_30D: 200,
    FEATURED_LISTING_3D: 75,
    TRANSACTION_FEE_PERCENT: 15, // 15% of transaction value
    UNLOCK_PREMIUM_CHAT: 30,
    PRIORITY_SUPPORT: 100
  },

  // Limits and restrictions
  LIMITS: {
    MIN_BALANCE: 0,
    MAX_BALANCE: 1000000,
    MIN_TRANSACTION: 1,
    MAX_TRANSACTION_PER_DAY: 10000,
    WITHDRAWAL_DISABLED: true, // Cannot convert coins to real money
  },

  // Coin value equivalents (for reference only)
  VALUE_REFERENCE: {
    ONE_COIN_VALUE_INR: 1, // 1 coin ≈ ₹1 (conceptual, not redeemable)
  }
};

class CoinsManager {

  /**
   * Initialize wallet for new user
   */
  static async initializeWallet(uid, signupBonus = 0) {
    try {
      const walletRef = db.collection('wallets').doc(uid);
      const walletDoc = await walletRef.get();

      if (walletDoc.exists) {
        console.log(`[COINS] Wallet already exists for ${uid}`);
        return walletDoc.data();
      }

      const initialWallet = {
        uid,
        balance: signupBonus,
        totalEarned: signupBonus,
        totalSpent: 0,
        transactionCount: 0,
        lastEarned: null,
        lastSpent: null,
        streak: {
          current: 0,
          longest: 0,
          lastLogin: null
        },
        achievements: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await walletRef.set(initialWallet);

      console.log(`[COINS] Wallet initialized for ${uid} with ${signupBonus} coins`);
      return initialWallet;
    } catch (error) {
      console.error('[COINS] Error initializing wallet:', error);
      throw error;
    }
  }

  /**
   * Award coins to user
   */
  static async awardCoins(uid, amount, reason, metadata = {}) {
    try {
      if (amount <= 0) {
        throw new Error('Amount must be positive');
      }

      const walletRef = db.collection('wallets').doc(uid);
      const walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        await this.initializeWallet(uid);
      }

      const currentBalance = walletDoc.exists ? (walletDoc.data().balance || 0) : 0;
      const newBalance = Math.min(currentBalance + amount, COIN_CONFIG.LIMITS.MAX_BALANCE);
      const actualAwarded = newBalance - currentBalance;

      // Update wallet
      await walletRef.update({
        balance: newBalance,
        totalEarned: admin.firestore.FieldValue.increment(actualAwarded),
        lastEarned: admin.firestore.FieldValue.serverTimestamp(),
        transactionCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log transaction
      await db.collection('coinTransactions').add({
        uid,
        type: 'earned',
        amount: actualAwarded,
        reason,
        metadata,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[COINS] Awarded ${actualAwarded} coins to ${uid}: ${reason}`);
      return { newBalance, awarded: actualAwarded };
    } catch (error) {
      console.error('[COINS] Error awarding coins:', error);
      throw error;
    }
  }

  /**
   * Deduct coins from user
   */
  static async deductCoins(uid, amount, reason, metadata = {}) {
    try {
      if (amount <= 0) {
        throw new Error('Amount must be positive');
      }

      const walletRef = db.collection('wallets').doc(uid);
      const walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        throw new Error('Wallet not found');
      }

      const currentBalance = walletDoc.data().balance || 0;
      
      if (currentBalance < amount) {
        throw new Error(`Insufficient balance. Required: ${amount}, Available: ${currentBalance}`);
      }

      const newBalance = currentBalance - amount;

      // Update wallet
      await walletRef.update({
        balance: newBalance,
        totalSpent: admin.firestore.FieldValue.increment(amount),
        lastSpent: admin.firestore.FieldValue.serverTimestamp(),
        transactionCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log transaction
      await db.collection('coinTransactions').add({
        uid,
        type: 'spent',
        amount,
        reason,
        metadata,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[COINS] Deducted ${amount} coins from ${uid}: ${reason}`);
      return { newBalance, deducted: amount };
    } catch (error) {
      console.error('[COINS] Error deducting coins:', error);
      throw error;
    }
  }

  /**
   * Award coins for ID verification
   */
  static async onIDVerification(uid) {
    try {
      return await this.awardCoins(
        uid,
        COIN_CONFIG.EARNINGS.ID_VERIFICATION,
        'ID verification completed',
        { type: 'id_verification' }
      );
    } catch (error) {
      console.error('[COINS] Error on ID verification:', error);
      throw error;
    }
  }

  /**
   * Award coins for transaction completion
   */
  static async onTransactionComplete(uid, transactionType, isFirst = false, transactionId) {
    try {
      let amount = 0;
      let reason = '';

      switch (transactionType.toLowerCase()) {
        case 'lend':
          amount = COIN_CONFIG.EARNINGS.COMPLETE_LEND;
          reason = 'Completed lending transaction';
          break;
        case 'borrow':
          amount = COIN_CONFIG.EARNINGS.COMPLETE_BORROW;
          reason = 'Completed borrowing transaction';
          break;
        case 'rent':
          amount = COIN_CONFIG.EARNINGS.COMPLETE_RENT;
          reason = 'Completed rental transaction';
          break;
        case 'sell':
          amount = COIN_CONFIG.EARNINGS.COMPLETE_SALE;
          reason = 'Completed sale transaction';
          break;
      }

      // Bonus for first transaction
      if (isFirst) {
        amount += COIN_CONFIG.EARNINGS.FIRST_TRANSACTION;
        reason += ' (first transaction bonus!)';
      }

      return await this.awardCoins(uid, amount, reason, {
        type: 'transaction_complete',
        transactionType,
        transactionId,
        isFirst
      });
    } catch (error) {
      console.error('[COINS] Error on transaction complete:', error);
      throw error;
    }
  }

  /**
   * Award bonus for rating
   */
  static async onHighRating(uid, rating, transactionId) {
    try {
      if (rating >= 5) {
        return await this.awardCoins(
          uid,
          COIN_CONFIG.EARNINGS.RATING_5_STAR_BONUS,
          'Received 5-star rating',
          { type: 'rating_bonus', rating, transactionId }
        );
      }
      return { newBalance: null, awarded: 0 };
    } catch (error) {
      console.error('[COINS] Error on high rating:', error);
      throw error;
    }
  }

  /**
   * Award referral bonus
   */
  static async onReferralComplete(referrerUid, refereeUid) {
    try {
      // Award to both referrer and referee
      const referrerResult = await this.awardCoins(
        referrerUid,
        COIN_CONFIG.EARNINGS.REFERRAL_BONUS,
        'Referral bonus - someone joined using your code',
        { type: 'referral_bonus', refereeUid, role: 'referrer' }
      );

      const refereeResult = await this.awardCoins(
        refereeUid,
        COIN_CONFIG.EARNINGS.REFERRAL_BONUS,
        'Welcome! Referral bonus for joining',
        { type: 'referral_bonus', referrerUid, role: 'referee' }
      );

      console.log(`[COINS] Referral bonus: ${referrerUid} and ${refereeUid} each received ${COIN_CONFIG.EARNINGS.REFERRAL_BONUS} coins`);
      return { referrerResult, refereeResult };
    } catch (error) {
      console.error('[COINS] Error on referral:', error);
      throw error;
    }
  }

  /**
   * Charge for listing an item
   */
  static async chargeForListing(uid, itemId, itemTitle) {
    try {
      return await this.deductCoins(
        uid,
        COIN_CONFIG.COSTS.LIST_ITEM,
        'Listed new item',
        { type: 'list_item', itemId, itemTitle }
      );
    } catch (error) {
      console.error('[COINS] Error charging for listing:', error);
      throw error;
    }
  }

  /**
   * Charge for boosting listing
   */
  static async chargeForBoost(uid, itemId, duration = 7) {
    try {
      return await this.deductCoins(
        uid,
        COIN_CONFIG.COSTS.BOOST_LISTING_7D,
        `Boosted listing for ${duration} days`,
        { type: 'boost_listing', itemId, duration }
      );
    } catch (error) {
      console.error('[COINS] Error charging for boost:', error);
      throw error;
    }
  }

  /**
   * Charge transaction fee
   */
  static async chargeTransactionFee(uid, transactionValue, transactionId) {
    try {
      const feeAmount = Math.ceil((transactionValue * COIN_CONFIG.COSTS.TRANSACTION_FEE_PERCENT) / 100);
      
      return await this.deductCoins(
        uid,
        feeAmount,
        `Transaction fee (${COIN_CONFIG.COSTS.TRANSACTION_FEE_PERCENT}%)`,
        { type: 'transaction_fee', transactionId, transactionValue, feePercent: COIN_CONFIG.COSTS.TRANSACTION_FEE_PERCENT }
      );
    } catch (error) {
      console.error('[COINS] Error charging transaction fee:', error);
      throw error;
    }
  }

  /**
   * Get wallet balance
   */
  static async getBalance(uid) {
    try {
      const walletRef = db.collection('wallets').doc(uid);
      const walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        await this.initializeWallet(uid);
        return 0;
      }

      return walletDoc.data().balance || 0;
    } catch (error) {
      console.error('[COINS] Error getting balance:', error);
      throw error;
    }
  }

  /**
   * Get wallet details
   */
  static async getWalletDetails(uid) {
    try {
      const walletRef = db.collection('wallets').doc(uid);
      const walletDoc = await walletRef.get();

      if (!walletDoc.exists) {
        const wallet = await this.initializeWallet(uid);
        return wallet;
      }

      return walletDoc.data();
    } catch (error) {
      console.error('[COINS] Error getting wallet details:', error);
      throw error;
    }
  }

  /**
   * Get transaction history
   */
  static async getTransactionHistory(uid, limit = 50) {
    try {
      const transactionsRef = db.collection('coinTransactions')
        .where('uid', '==', uid)
        .orderBy('createdAt', 'desc')
        .limit(limit);

      const snapshot = await transactionsRef.get();
      const transactions = [];

      snapshot.forEach(doc => {
        transactions.push({
          id: doc.id,
          ...doc.data(),
          createdAt: doc.data().createdAt?.toDate()
        });
      });

      return transactions;
    } catch (error) {
      console.error('[COINS] Error getting transaction history:', error);
      throw error;
    }
  }

  /**
   * Check if user has sufficient balance
   */
  static async hasSufficientBalance(uid, requiredAmount) {
    try {
      const balance = await this.getBalance(uid);
      return balance >= requiredAmount;
    } catch (error) {
      console.error('[COINS] Error checking balance:', error);
      throw error;
    }
  }

  /**
   * Get earning opportunities for user
   */
  static getEarningOpportunities() {
    return {
      verification: {
        coins: COIN_CONFIG.EARNINGS.ID_VERIFICATION,
        description: 'Complete ID verification',
        oneTime: true
      },
      transactions: {
        lend: { coins: COIN_CONFIG.EARNINGS.COMPLETE_LEND, description: 'Complete a lending transaction' },
        borrow: { coins: COIN_CONFIG.EARNINGS.COMPLETE_BORROW, description: 'Complete a borrowing transaction' },
        rent: { coins: COIN_CONFIG.EARNINGS.COMPLETE_RENT, description: 'Complete a rental transaction' },
        sell: { coins: COIN_CONFIG.EARNINGS.COMPLETE_SALE, description: 'Complete a sale transaction' }
      },
      bonuses: {
        referral: { coins: COIN_CONFIG.EARNINGS.REFERRAL_BONUS, description: 'Refer a friend' },
        firstTransaction: { coins: COIN_CONFIG.EARNINGS.FIRST_TRANSACTION, description: 'First transaction bonus' },
        fiveStarRating: { coins: COIN_CONFIG.EARNINGS.RATING_5_STAR_BONUS, description: 'Receive a 5-star rating' },
        earlyReturn: { coins: COIN_CONFIG.EARNINGS.EARLY_RETURN_BONUS, description: 'Return item early' }
      }
    };
  }

  /**
   * Get spending options
   */
  static getSpendingOptions() {
    return {
      listings: {
        list: { coins: COIN_CONFIG.COSTS.LIST_ITEM, description: 'List a new item' },
        boost: { coins: COIN_CONFIG.COSTS.BOOST_LISTING_7D, description: 'Boost listing for 7 days' },
        featured: { coins: COIN_CONFIG.COSTS.FEATURED_LISTING_3D, description: 'Featured listing for 3 days' }
      },
      premium: {
        badge: { coins: COIN_CONFIG.COSTS.PREMIUM_BADGE_30D, description: 'Premium badge for 30 days' },
        chat: { coins: COIN_CONFIG.COSTS.UNLOCK_PREMIUM_CHAT, description: 'Unlock premium chat features' },
        support: { coins: COIN_CONFIG.COSTS.PRIORITY_SUPPORT, description: 'Priority customer support' }
      },
      fees: {
        transaction: { percent: COIN_CONFIG.COSTS.TRANSACTION_FEE_PERCENT, description: 'Transaction processing fee' }
      }
    };
  }
}

module.exports = {
  CoinsManager,
  COIN_CONFIG
};

