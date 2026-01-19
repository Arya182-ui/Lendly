
const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Trust Score Management System
 * Range: 0-100
 * 
 * Base Rules:
 * - New user: 50
 * - ID Verified: 70
 * - Increases: +2-5 per successful transaction (based on transaction type)
 * - Decreases: -5 to -20 for late returns, disputes, cancellations
 * - Max decrease cap: -30 per incident to prevent complete score destruction
 * 
 * Score Tiers:
 * - 90-100: Excellent (Gold Badge)
 * - 70-89: Good (Silver Badge)
 * - 50-69: Average (Bronze Badge)
 * - 30-49: Below Average (Warning)
 * - 0-29: Poor (Restricted Access)
 */

const TRUST_SCORE_CONFIG = {
  // Initial scores
  NEW_USER: 50,
  ID_VERIFIED_BASE: 70,
  
  // Transaction rewards
  SUCCESSFUL_BORROW: 3,
  SUCCESSFUL_LEND: 4,
  SUCCESSFUL_RENT: 3,
  SUCCESSFUL_SELL: 2,
  ON_TIME_RETURN: 5,
  EARLY_RETURN: 7,
  
  // Penalties
  LATE_RETURN_1_DAY: -2,
  LATE_RETURN_3_DAYS: -5,
  LATE_RETURN_7_DAYS: -10,
  LATE_RETURN_14_DAYS: -15,
  FAILED_TRANSACTION: -10,
  DISPUTE_RAISED: -15,
  DISPUTE_LOST: -20,
  CANCELLATION: -5,
  
  // Rating-based adjustments
  RATING_5_STAR: 3,
  RATING_4_STAR: 1,
  RATING_3_STAR: 0,
  RATING_2_STAR: -2,
  RATING_1_STAR: -5,
  
  // Boundaries
  MIN_SCORE: 0,
  MAX_SCORE: 100,
  MAX_PENALTY_PER_INCIDENT: -30,
  
  // Tiers
  TIER_EXCELLENT: 90,
  TIER_GOOD: 70,
  TIER_AVERAGE: 50,
  TIER_BELOW_AVERAGE: 30
};

class TrustScoreManager {
  
  /**
   * Calculate trust score tier and badge
   */
  static getTier(score) {
    if (score >= TRUST_SCORE_CONFIG.TIER_EXCELLENT) {
      return {
        tier: 'Excellent',
        badge: 'gold',
        color: '#FFD700',
        icon: '🏆',
        benefits: ['Priority support', 'Higher borrowing limits', 'Featured listings']
      };
    }
    if (score >= TRUST_SCORE_CONFIG.TIER_GOOD) {
      return {
        tier: 'Good',
        badge: 'silver',
        color: '#C0C0C0',
        icon: '⭐',
        benefits: ['Standard support', 'Normal borrowing limits', 'Verified badge']
      };
    }
    if (score >= TRUST_SCORE_CONFIG.TIER_AVERAGE) {
      return {
        tier: 'Average',
        badge: 'bronze',
        color: '#CD7F32',
        icon: '📋',
        benefits: ['Basic support', 'Limited borrowing']
      };
    }
    if (score >= TRUST_SCORE_CONFIG.TIER_BELOW_AVERAGE) {
      return {
        tier: 'Below Average',
        badge: 'warning',
        color: '#FFA500',
        icon: '⚠️',
        benefits: ['Restricted access', 'Lower limits']
      };
    }
    return {
      tier: 'Poor',
      badge: 'restricted',
      color: '#FF0000',
      icon: '🚫',
      benefits: ['Limited access only']
    };
  }

  /**
   * Initialize trust score for new user
   */
  static async initializeTrustScore(uid) {
    try {
      const userRef = db.collection('users').doc(uid);
      const trustScoreHistoryRef = db.collection('trustScoreHistory');

      await userRef.update({
        trustScore: TRUST_SCORE_CONFIG.NEW_USER,
        trustScoreTier: this.getTier(TRUST_SCORE_CONFIG.NEW_USER).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log initial score
      await trustScoreHistoryRef.add({
        uid,
        previousScore: 0,
        newScore: TRUST_SCORE_CONFIG.NEW_USER,
        change: TRUST_SCORE_CONFIG.NEW_USER,
        reason: 'Account created',
        type: 'initialization',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] Initialized for user ${uid}: ${TRUST_SCORE_CONFIG.NEW_USER}`);
      return TRUST_SCORE_CONFIG.NEW_USER;
    } catch (error) {
      console.error('[TRUST_SCORE] Error initializing:', error);
      throw error;
    }
  }

  /**
   * Set trust score to 70 when ID is verified
   */
  static async onIDVerification(uid) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const currentScore = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      const newScore = TRUST_SCORE_CONFIG.ID_VERIFIED_BASE;
      const change = newScore - currentScore;

      await userRef.update({
        trustScore: newScore,
        trustScoreTier: this.getTier(newScore).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isVerified: true
      });

      // Log verification bonus
      await db.collection('trustScoreHistory').add({
        uid,
        previousScore: currentScore,
        newScore,
        change,
        reason: 'ID verification completed',
        type: 'id_verification',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] ID verified for user ${uid}: ${currentScore} → ${newScore} (+${change})`);
      return { newScore, change };
    } catch (error) {
      console.error('[TRUST_SCORE] Error on ID verification:', error);
      throw error;
    }
  }

  /**
   * Adjust trust score based on transaction completion
   */
  static async onTransactionComplete(uid, transactionType, details = {}) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const currentScore = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      let change = 0;
      let reason = '';

      // Determine score change based on transaction type
      switch (transactionType.toLowerCase()) {
        case 'borrow':
          change = TRUST_SCORE_CONFIG.SUCCESSFUL_BORROW;
          reason = 'Completed borrowing transaction';
          break;
        case 'lend':
          change = TRUST_SCORE_CONFIG.SUCCESSFUL_LEND;
          reason = 'Completed lending transaction';
          break;
        case 'rent':
          change = TRUST_SCORE_CONFIG.SUCCESSFUL_RENT;
          reason = 'Completed rental transaction';
          break;
        case 'sell':
          change = TRUST_SCORE_CONFIG.SUCCESSFUL_SELL;
          reason = 'Completed sale transaction';
          break;
      }

      // Bonus for on-time or early return
      if (details.returnedOnTime === true) {
        change += TRUST_SCORE_CONFIG.ON_TIME_RETURN;
        reason += ' (on-time return bonus)';
      } else if (details.returnedEarly === true) {
        change += TRUST_SCORE_CONFIG.EARLY_RETURN;
        reason += ' (early return bonus)';
      }

      const newScore = Math.max(
        TRUST_SCORE_CONFIG.MIN_SCORE,
        Math.min(TRUST_SCORE_CONFIG.MAX_SCORE, currentScore + change)
      );

      await userRef.update({
        trustScore: newScore,
        trustScoreTier: this.getTier(newScore).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log transaction impact
      await db.collection('trustScoreHistory').add({
        uid,
        previousScore: currentScore,
        newScore,
        change,
        reason,
        type: 'transaction_complete',
        transactionType,
        transactionId: details.transactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] Transaction complete for ${uid}: ${currentScore} → ${newScore} (+${change})`);
      return { newScore, change };
    } catch (error) {
      console.error('[TRUST_SCORE] Error on transaction complete:', error);
      throw error;
    }
  }

  /**
   * Penalize for late return
   */
  static async onLateReturn(uid, daysLate, transactionId) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const currentScore = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      let change = 0;

      // Progressive penalties based on how late
      if (daysLate >= 14) {
        change = TRUST_SCORE_CONFIG.LATE_RETURN_14_DAYS;
      } else if (daysLate >= 7) {
        change = TRUST_SCORE_CONFIG.LATE_RETURN_7_DAYS;
      } else if (daysLate >= 3) {
        change = TRUST_SCORE_CONFIG.LATE_RETURN_3_DAYS;
      } else if (daysLate >= 1) {
        change = TRUST_SCORE_CONFIG.LATE_RETURN_1_DAY;
      }

      // Apply max penalty cap
      change = Math.max(change, TRUST_SCORE_CONFIG.MAX_PENALTY_PER_INCIDENT);

      const newScore = Math.max(
        TRUST_SCORE_CONFIG.MIN_SCORE,
        currentScore + change
      );

      await userRef.update({
        trustScore: newScore,
        trustScoreTier: this.getTier(newScore).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log penalty
      await db.collection('trustScoreHistory').add({
        uid,
        previousScore: currentScore,
        newScore,
        change,
        reason: `Late return: ${daysLate} day(s) overdue`,
        type: 'late_return',
        daysLate,
        transactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] Late return penalty for ${uid}: ${currentScore} → ${newScore} (${change})`);
      return { newScore, change };
    } catch (error) {
      console.error('[TRUST_SCORE] Error on late return:', error);
      throw error;
    }
  }

  /**
   * Adjust score based on rating received
   */
  static async onRatingReceived(uid, rating, fromUid, transactionId) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const currentScore = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      let change = 0;

      // Score adjustment based on rating
      if (rating >= 5) change = TRUST_SCORE_CONFIG.RATING_5_STAR;
      else if (rating >= 4) change = TRUST_SCORE_CONFIG.RATING_4_STAR;
      else if (rating >= 3) change = TRUST_SCORE_CONFIG.RATING_3_STAR;
      else if (rating >= 2) change = TRUST_SCORE_CONFIG.RATING_2_STAR;
      else change = TRUST_SCORE_CONFIG.RATING_1_STAR;

      const newScore = Math.max(
        TRUST_SCORE_CONFIG.MIN_SCORE,
        Math.min(TRUST_SCORE_CONFIG.MAX_SCORE, currentScore + change)
      );

      await userRef.update({
        trustScore: newScore,
        trustScoreTier: this.getTier(newScore).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log rating impact
      await db.collection('trustScoreHistory').add({
        uid,
        previousScore: currentScore,
        newScore,
        change,
        reason: `Received ${rating}-star rating`,
        type: 'rating_received',
        rating,
        fromUid,
        transactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] Rating received for ${uid}: ${currentScore} → ${newScore} (${change})`);
      return { newScore, change };
    } catch (error) {
      console.error('[TRUST_SCORE] Error on rating received:', error);
      throw error;
    }
  }

  /**
   * Handle dispute or cancellation
   */
  static async onDispute(uid, disputeType, won, transactionId) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const currentScore = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      let change = 0;
      let reason = '';

      if (disputeType === 'cancellation') {
        change = TRUST_SCORE_CONFIG.CANCELLATION;
        reason = 'Transaction cancelled';
      } else if (won) {
        change = TRUST_SCORE_CONFIG.DISPUTE_RAISED; // Partial penalty even if won
        reason = 'Dispute raised (won)';
      } else {
        change = TRUST_SCORE_CONFIG.DISPUTE_LOST;
        reason = 'Dispute lost';
      }

      // Apply max penalty cap
      change = Math.max(change, TRUST_SCORE_CONFIG.MAX_PENALTY_PER_INCIDENT);

      const newScore = Math.max(
        TRUST_SCORE_CONFIG.MIN_SCORE,
        currentScore + change
      );

      await userRef.update({
        trustScore: newScore,
        trustScoreTier: this.getTier(newScore).tier,
        trustScoreUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Log dispute impact
      await db.collection('trustScoreHistory').add({
        uid,
        previousScore: currentScore,
        newScore,
        change,
        reason,
        type: 'dispute',
        disputeType,
        won,
        transactionId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`[TRUST_SCORE] Dispute handled for ${uid}: ${currentScore} → ${newScore} (${change})`);
      return { newScore, change };
    } catch (error) {
      console.error('[TRUST_SCORE] Error on dispute:', error);
      throw error;
    }
  }

  /**
   * Get trust score history for a user
   */
  static async getHistory(uid, limit = 20) {
    try {
      const historyRef = db.collection('trustScoreHistory')
        .where('uid', '==', uid)
        .orderBy('createdAt', 'desc')
        .limit(limit);

      const snapshot = await historyRef.get();
      const history = [];

      snapshot.forEach(doc => {
        history.push({
          id: doc.id,
          ...doc.data(),
          createdAt: doc.data().createdAt?.toDate()
        });
      });

      return history;
    } catch (error) {
      console.error('[TRUST_SCORE] Error getting history:', error);
      throw error;
    }
  }

  /**
   * Get current trust score and details
   */
  static async getCurrentScore(uid) {
    try {
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }

      const score = userDoc.data().trustScore || TRUST_SCORE_CONFIG.NEW_USER;
      const tier = this.getTier(score);

      return {
        score,
        ...tier,
        lastUpdated: userDoc.data().trustScoreUpdatedAt?.toDate()
      };
    } catch (error) {
      console.error('[TRUST_SCORE] Error getting current score:', error);
      throw error;
    }
  }
}

module.exports = {
  TrustScoreManager,
  TRUST_SCORE_CONFIG
};
