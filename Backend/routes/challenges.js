const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { authenticateUser } = require('../middleware/auth');

const db = admin.firestore();

// Get daily challenge for user
router.get('/daily', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const today = new Date().toISOString().split('T')[0];
    
    // Check if user has completed today's challenge
    const userChallengeRef = db.collection('userChallenges')
      .where('uid', '==', uid)
      .where('date', '==', today);
      
    const userChallengeSnapshot = await userChallengeRef.get();
    const hasCompleted = !userChallengeSnapshot.empty;
    
    // Get or create daily challenge
    let challengeDoc = await db.collection('dailyChallenges').doc(today).get();
    
    if (!challengeDoc.exists) {
      // Create new daily challenge if doesn't exist
      const challenges = [
        {
          title: "List Your First Item",
          description: "Share something you don't need with your campus community",
          reward: 50,
          type: "list_item",
          target: 1
        },
        {
          title: "Help a Fellow Student",
          description: "Complete a transaction to help someone in need",
          reward: 30,
          type: "complete_transaction",
          target: 1
        },
        {
          title: "Join Campus Community",
          description: "Join a new group or connect with 3 students",
          reward: 25,
          type: "social_connect",
          target: 3
        },
        {
          title: "Share Your Impact",
          description: "Share your positive impact story with campus",
          reward: 40,
          type: "share_impact",
          target: 1
        },
        {
          title: "Campus Explorer",
          description: "Check out items from 5 different categories",
          reward: 35,
          type: "explore_categories",
          target: 5
        }
      ];
      
      const randomChallenge = challenges[Math.floor(Math.random() * challenges.length)];
      
      await db.collection('dailyChallenges').doc(today).set({
        ...randomChallenge,
        date: today,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      challengeDoc = await db.collection('dailyChallenges').doc(today).get();
    }
    
    const challenge = challengeDoc.data();
    
    // Get user's progress on this challenge
    let progress = 0;
    if (!hasCompleted) {
      // Calculate progress based on challenge type
      switch (challenge.type) {
        case 'list_item':
          const itemsToday = await db.collection('items')
            .where('ownerId', '==', uid)
            .where('createdAt', '>=', new Date(today))
            .get();
          progress = itemsToday.size;
          break;
          
        case 'complete_transaction':
          const transactionsToday = await db.collection('transactions')
            .where('borrowerId', '==', uid)
            .where('status', '==', 'completed')
            .where('completedAt', '>=', new Date(today))
            .get();
          progress = transactionsToday.size;
          break;
          
        case 'social_connect':
          const connectionsToday = await db.collection('friendships')
            .where('userId', '==', uid)
            .where('createdAt', '>=', new Date(today))
            .get();
          progress = connectionsToday.size;
          break;
          
        default:
          progress = 0;
      }
    }
    
    res.json({
      success: true,
      challenge: {
        ...challenge,
        progress: Math.min(progress, challenge.target),
        completed: hasCompleted,
        canClaim: progress >= challenge.target && !hasCompleted
      }
    });
    
  } catch (error) {
    console.error('Error fetching daily challenge:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch daily challenge'
    });
  }
});

// Complete daily challenge
router.post('/complete', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const today = new Date().toISOString().split('T')[0];
    
    // Check if already completed
    const userChallengeRef = db.collection('userChallenges')
      .where('uid', '==', uid)
      .where('date', '==', today);
      
    const existingChallenge = await userChallengeRef.get();
    if (!existingChallenge.empty) {
      return res.status(400).json({
        success: false,
        message: 'Challenge already completed today'
      });
    }
    
    // Get today's challenge
    const challengeDoc = await db.collection('dailyChallenges').doc(today).get();
    if (!challengeDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'No challenge found for today'
      });
    }
    
    const challenge = challengeDoc.data();
    
    // Verify completion criteria (simplified for demo)
    // In production, this should verify actual completion
    
    const batch = db.batch();
    
    // Mark challenge as completed
    const userChallengeRef2 = db.collection('userChallenges').doc();
    batch.set(userChallengeRef2, {
      uid,
      challengeId: today,
      date: today,
      reward: challenge.reward,
      completedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Update user coins
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      coins: admin.firestore.FieldValue.increment(challenge.reward),
      totalChallengesCompleted: admin.firestore.FieldValue.increment(1)
    });
    
    // Add activity log
    const activityRef = db.collection('activities').doc();
    batch.set(activityRef, {
      uid,
      type: 'challenge_completed',
      challengeTitle: challenge.title,
      reward: challenge.reward,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      visibility: 'campus'
    });
    
    await batch.commit();
    
    res.json({
      success: true,
      message: 'Challenge completed successfully!',
      reward: challenge.reward
    });
    
  } catch (error) {
    console.error('Error completing challenge:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to complete challenge'
    });
  }
});

// Get user's challenge history
router.get('/history', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { limit = 10, startAfter } = req.query;
    
    let query = db.collection('userChallenges')
      .where('uid', '==', uid)
      .orderBy('completedAt', 'desc')
      .limit(parseInt(limit));
    
    if (startAfter) {
      const startAfterDoc = await db.collection('userChallenges').doc(startAfter).get();
      query = query.startAfter(startAfterDoc);
    }
    
    const snapshot = await query.get();
    const challenges = [];
    
    for (const doc of snapshot.docs) {
      const challengeData = doc.data();
      const challengeDetails = await db.collection('dailyChallenges')
        .doc(challengeData.challengeId)
        .get();
      
      challenges.push({
        id: doc.id,
        ...challengeData,
        challengeDetails: challengeDetails.exists ? challengeDetails.data() : null
      });
    }
    
    res.json({
      success: true,
      challenges,
      hasMore: snapshot.size === parseInt(limit)
    });
    
  } catch (error) {
    console.error('Error fetching challenge history:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch challenge history'
    });
  }
});


// Auto-detect and complete challenges based on user actions
router.post('/auto-complete/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    const { actionType, metadata } = req.body;
    
    const today = new Date().toISOString().split('T')[0];
    
    // Get today's challenge
    const challengeDoc = await db.collection('dailyChallenges').doc(today).get();
    if (!challengeDoc.exists) {
      return res.json({ success: true, message: 'No challenge for today' });
    }
    
    const challenge = challengeDoc.data();
    
    // Check if user already completed today's challenge
    const existingCompletion = await db.collection('userChallenges')
      .where('uid', '==', uid)
      .where('date', '==', today)
      .get();
    
    if (!existingCompletion.empty) {
      return res.json({ success: true, message: 'Challenge already completed' });
    }
    
    // Check if action matches challenge type
    let shouldComplete = false;
    let progress = 0;
    
    switch (challenge.type) {
      case 'list_item':
        if (actionType === 'item_listed') {
          shouldComplete = true;
          progress = 1;
        }
        break;
        
      case 'complete_transaction':
        if (actionType === 'transaction_completed') {
          shouldComplete = true;
          progress = 1;
        }
        break;
        
      case 'social_connect':
        if (actionType === 'friend_added') {
          // Check total friends added today
          const friendsToday = await db.collection('friendships')
            .where('userId', '==', uid)
            .where('createdAt', '>=', new Date(today))
            .get();
          progress = friendsToday.size;
          shouldComplete = progress >= challenge.target;
        }
        break;
    }
    
    if (shouldComplete) {
      const batch = db.batch();
      
      // Mark challenge as completed
      const userChallengeRef = db.collection('userChallenges').doc();
      batch.set(userChallengeRef, {
        uid,
        challengeId: today,
        date: today,
        reward: challenge.reward,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        actionType,
        metadata
      });
      
      // Award coins
      const walletRef = db.collection('wallets').doc(uid);
      batch.update(walletRef, {
        balance: admin.firestore.FieldValue.increment(challenge.reward),
        totalEarned: admin.firestore.FieldValue.increment(challenge.reward)
      });
      
      // Add transaction record
      const transactionRef = db.collection('transactions').doc();
      batch.set(transactionRef, {
        uid,
        type: 'earned_challenge',
        amount: challenge.reward,
        description: `Daily Challenge: ${challenge.title}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: { challengeId: today, ...metadata }
      });
      
      await batch.commit();
      
      res.json({ 
        success: true, 
        message: 'Challenge completed!', 
        reward: challenge.reward,
        challengeTitle: challenge.title
      });
    } else {
      res.json({ 
        success: true, 
        message: 'Action recorded', 
        progress,
        target: challenge.target
      });
    }
  } catch (error) {
    console.error('Error in auto-complete challenge:', error);
    res.status(500).json({ error: 'Failed to process challenge completion' });
  }
});

module.exports = router;
