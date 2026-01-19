const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { authenticateUser } = require('../middleware/auth');

const db = admin.firestore();

// Get campus activity feed
router.get('/campus', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { limit = 20, startAfter } = req.query;
    
    // Get user's college for campus-specific activities
    const userDoc = await db.collection('users').doc(uid).get();
    const userCollege = userDoc.exists ? userDoc.data().college : null;
    
    if (!userCollege) {
      return res.status(400).json({
        success: false,
        message: 'User college information not found'
      });
    }
    
    let query = db.collection('activities')
      .where('visibility', '==', 'campus')
      .where('college', '==', userCollege)
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit));
    
    if (startAfter) {
      const startAfterDoc = await db.collection('activities').doc(startAfter).get();
      query = query.startAfter(startAfterDoc);
    }
    
    const snapshot = await query.get();
    const activities = [];
    
    // Get user details for each activity
    for (const doc of snapshot.docs) {
      const activityData = doc.data();
      const userDoc = await db.collection('users').doc(activityData.uid).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      
      activities.push({
        id: doc.id,
        ...activityData,
        user: {
          name: userData.name || 'Anonymous',
          avatar: userData.avatar || null,
          trustScore: userData.trustScore || 0,
          college: userData.college
        }
      });
    }
    
    res.json({
      success: true,
      activities,
      hasMore: snapshot.size === parseInt(limit)
    });
    
  } catch (error) {
    console.error('Error fetching campus activities:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch campus activities'
    });
  }
});

// Get trending activities (most engaged)
router.get('/trending', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { timeframe = '24h' } = req.query;
    
    // Calculate time threshold
    const now = new Date();
    let timeThreshold;
    switch (timeframe) {
      case '1h':
        timeThreshold = new Date(now.getTime() - 60 * 60 * 1000);
        break;
      case '24h':
        timeThreshold = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case '7d':
        timeThreshold = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      default:
        timeThreshold = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    }
    
    // Get user's college
    const userDoc = await db.collection('users').doc(uid).get();
    const userCollege = userDoc.exists ? userDoc.data().college : null;
    
    let query = db.collection('activities')
      .where('timestamp', '>=', timeThreshold)
      .orderBy('timestamp', 'desc')
      .limit(50);
    
    if (userCollege) {
      query = query.where('college', '==', userCollege);
    }
    
    const snapshot = await query.get();
    const activities = [];
    
    for (const doc of snapshot.docs) {
      const activityData = doc.data();
      
      // Calculate engagement score (likes + comments + shares)
      const engagementScore = (activityData.likes || 0) + 
                            (activityData.comments || 0) * 2 + 
                            (activityData.shares || 0) * 3;
      
      const userDoc = await db.collection('users').doc(activityData.uid).get();
      const userData = userDoc.exists ? userDoc.data() : {};
      
      activities.push({
        id: doc.id,
        ...activityData,
        engagementScore,
        user: {
          name: userData.name || 'Anonymous',
          avatar: userData.avatar || null,
          trustScore: userData.trustScore || 0,
          college: userData.college
        }
      });
    }
    
    // Sort by engagement score
    activities.sort((a, b) => b.engagementScore - a.engagementScore);
    
    res.json({
      success: true,
      activities: activities.slice(0, 10),
      timeframe
    });
    
  } catch (error) {
    console.error('Error fetching trending activities:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch trending activities'
    });
  }
});

// Create new activity
router.post('/create', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { type, title, description, metadata, visibility = 'campus' } = req.body;
    
    // Validate required fields
    if (!type || !title) {
      return res.status(400).json({
        success: false,
        message: 'Activity type and title are required'
      });
    }
    
    // Get user details
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    
    const activityData = {
      uid,
      type,
      title,
      description: description || '',
      metadata: metadata || {},
      visibility,
      college: userData.college,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      likes: 0,
      comments: 0,
      shares: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = await db.collection('activities').add(activityData);
    
    res.json({
      success: true,
      message: 'Activity created successfully',
      activityId: docRef.id
    });
    
  } catch (error) {
    console.error('Error creating activity:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create activity'
    });
  }
});

// Like/unlike activity
router.post('/:activityId/like', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { activityId } = req.params;
    
    const activityRef = db.collection('activities').doc(activityId);
    const likeRef = db.collection('activityLikes').doc(`${activityId}_${uid}`);
    
    const [activityDoc, likeDoc] = await Promise.all([
      activityRef.get(),
      likeRef.get()
    ]);
    
    if (!activityDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Activity not found'
      });
    }
    
    const batch = db.batch();
    
    if (likeDoc.exists) {
      // Unlike
      batch.delete(likeRef);
      batch.update(activityRef, {
        likes: admin.firestore.FieldValue.increment(-1)
      });
    } else {
      // Like
      batch.set(likeRef, {
        activityId,
        uid,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
      batch.update(activityRef, {
        likes: admin.firestore.FieldValue.increment(1)
      });
    }
    
    await batch.commit();
    
    res.json({
      success: true,
      liked: !likeDoc.exists
    });
    
  } catch (error) {
    console.error('Error toggling activity like:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to toggle like'
    });
  }
});

// Get user's personal activity feed
router.get('/user', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.user;
    const { limit = 20, startAfter } = req.query;
    
    let query = db.collection('activities')
      .where('uid', '==', uid)
      .orderBy('timestamp', 'desc')
      .limit(parseInt(limit));
    
    if (startAfter) {
      const startAfterDoc = await db.collection('activities').doc(startAfter).get();
      query = query.startAfter(startAfterDoc);
    }
    
    const snapshot = await query.get();
    const activities = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({
      success: true,
      activities,
      hasMore: snapshot.size === parseInt(limit)
    });
    
  } catch (error) {
    console.error('Error fetching user activities:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch user activities'
    });
  }
});

module.exports = router;
