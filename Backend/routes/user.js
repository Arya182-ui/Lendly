const express = require('express');
const admin = require('firebase-admin');
const { isValidUid, isValidLength, isValidEmail, sanitizeHtml, trimObjectStrings, pickFields } = require('../utils/validators');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { authenticateUser } = require('../middleware/auth');

const router = express.Router();
// Use the Firebase Admin app's Firestore instance explicitly
const db = admin.firestore();
const { TrustScoreManager } = require('../utils/trust-score-manager');
const { CoinsManager } = require('../utils/coins-manager');

// Rating Utilities (Trust Score now managed by TrustScoreManager)
function calculateUserRating(ratings) {
  if (!ratings || ratings.length === 0) return 0;
  const sum = ratings.reduce((total, r) => total + r.rating, 0);
  return Math.round((sum / ratings.length) * 10) / 10; // Round to 1 decimal
}

const ALLOWED_INTERESTS = ['tech', 'sports', 'music', 'art', 'reading', 'gaming', 'cooking', 'travel', 'photography', 'fitness', 'movies', 'writing', 'coding', 'design', 'business'];

// GET /user/profile - Get user's own profile
router.get('/profile', authenticateUser, async (req, res) => {
  try {
    console.log('[USER_PROFILE] Request received:', {
      query: req.query,
      uid: req.uid,
      timestamp: new Date().toISOString()
    });
    
    const { uid } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      console.log('[USER_PROFILE] Invalid UID:', uid);
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    // Fetch user doc and friends count in parallel
    const [userDoc, friendsSnap, itemsSnap] = await Promise.all([
      db.collection('users').doc(uid).get(),
      db.collection('users').doc(uid).collection('friends').count().get(),
      db.collection('items').where('ownerId', '==', uid).where('available', '==', true).count().get()
    ]);
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = userDoc.data();
    
    res.json({
      uid,
      name: data.name || '',
      email: data.email || '',
      college: data.college || '',
      hostel: data.hostel || '',
      avatar: data.avatar || data.avatarChoice || 'default',
      avatarChoice: data.avatarChoice || 'default',
      photo: data.photo || data.avatar || data.avatarChoice || 'default',
      interests: data.interests || [],
      bio: data.bio || '',
      trustScore: data.trustScore || 0,
      borrowed: data.borrowed || 0,
      lent: data.lent || 0,
      rating: data.rating || 0,
      totalRatings: data.totalRatings || 0,
      verificationStatus: data.verificationStatus || 'unknown',
      friendsCount: friendsSnap.data().count || 0,
      activeListings: itemsSnap.data().count || 0,
      createdAt: data.createdAt,
      socialProfile: data.socialProfile || ''
    });
  } catch (err) {
    console.error('Error fetching profile:', err);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PUT /user/profile - Update user profile
router.put('/profile', async (req, res) => {
  try {
    const body = trimObjectStrings(req.body);
    const { uid, name, college, hostel, bio, interests, socialProfile, avatar } = body;
    
    // Validation
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const errors = [];
    
    if (name !== undefined && !isValidLength(name, 2, 50)) {
      errors.push('Name must be 2-50 characters');
    }
    if (college !== undefined && !isValidLength(college, 0, 100)) {
      errors.push('College must be under 100 characters');
    }
    if (hostel !== undefined && !isValidLength(hostel, 0, 50)) {
      errors.push('Hostel must be under 50 characters');
    }
    if (bio !== undefined && !isValidLength(bio, 0, 300)) {
      errors.push('Bio must be under 300 characters');
    }
    if (interests !== undefined) {
      if (!Array.isArray(interests)) {
        errors.push('Interests must be an array');
      } else if (interests.length > 10) {
        errors.push('Maximum 10 interests allowed');
      } else {
        const invalidInterests = interests.filter(i => !ALLOWED_INTERESTS.includes(i.toLowerCase()));
        if (invalidInterests.length > 0) {
          errors.push(`Invalid interests: ${invalidInterests.join(', ')}. Allowed: ${ALLOWED_INTERESTS.join(', ')}`);
        }
      }
    }
    if (socialProfile !== undefined && socialProfile.length > 200) {
      errors.push('Social profile link must be under 200 characters');
    }
    if (avatar !== undefined && avatar.length > 500) {
      errors.push('Avatar URL too long');
    }
    
    if (errors.length > 0) {
      return res.status(400).json({ error: 'Validation failed', details: errors });
    }
    
    // Build update object
    const updateData = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    
    if (name !== undefined) updateData.name = sanitizeHtml(name);
    if (college !== undefined) updateData.college = sanitizeHtml(college);
    if (hostel !== undefined) updateData.hostel = sanitizeHtml(hostel);
    if (bio !== undefined) updateData.bio = sanitizeHtml(bio);
    if (interests !== undefined) updateData.interests = interests.map(i => i.toLowerCase());
    if (socialProfile !== undefined) updateData.socialProfile = socialProfile;
    if (avatar !== undefined) {
      updateData.avatar = avatar;
      updateData.avatarChoice = avatar; // Also update avatarChoice for backward compatibility
      updateData.photo = avatar; // Update photo field as well
    }
    
    await db.collection('users').doc(uid).update(updateData);
    
    res.json({ success: true, message: 'Profile updated successfully' });
  } catch (err) {
    console.error('Error updating profile:', err);
    if (err.code === 5) { // NOT_FOUND
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// GET /user/public-profile - Get another user's public profile
router.get('/public-profile', async (req, res) => {
  try {
    const { uid, viewerId } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    // Fetch user, their items, and check friendship in parallel
    const queries = [
      db.collection('users').doc(uid).get(),
      db.collection('items').where('ownerId', '==', uid).where('available', '==', true).limit(6).get()
    ];
    
    // Check friendship if viewerId provided
    if (viewerId && isValidUid(viewerId)) {
      queries.push(
        db.collection('users').doc(viewerId).collection('friends').doc(uid).get()
      );
    }
    
    const [userDoc, itemsSnap, friendDoc] = await Promise.all(queries);
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = userDoc.data();
    
    // Recent items
    const recentItems = itemsSnap.docs.map(doc => ({
      id: doc.id,
      name: doc.data().name || '',
      image: doc.data().image || '',
      type: doc.data().type || '',
      price: doc.data().price || 0
    }));
    
    res.json({
      uid,
      name: data.name || '',
      college: data.college || '',
      avatar: data.avatar || data.avatarChoice || 'default',
      avatarChoice: data.avatarChoice || 'default',
      photo: data.photo || data.avatar || data.avatarChoice || 'default',
      bio: data.bio || '',
      interests: data.interests || [],
      rating: data.rating || 0,
      totalRatings: data.totalRatings || 0,
      trustScore: data.trustScore || 0,
      verificationStatus: data.verificationStatus || 'unknown',
      borrowed: data.borrowed || 0,
      lent: data.lent || 0,
      recentItems,
      isFriend: friendDoc?.exists || false,
      memberSince: data.createdAt
    });
  } catch (err) {
    console.error('Error fetching public profile:', err);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// GET /user/search - Search users
router.get('/search', async (req, res) => {
  try {
    const { q, college, limit = 10, excludeUid } = req.query;
    
    if (!q || !isValidLength(q, 2, 50)) {
      return res.status(400).json({ error: 'Search query must be 2-50 characters' });
    }
    
    const parsedLimit = Math.min(parseInt(limit, 10) || 10, 20);
    const searchTerm = q.toLowerCase();
    
    let query = db.collection('users');
    
    // Filter by college if provided
    if (college && isValidLength(college, 1, 100)) {
      query = query.where('college', '==', college);
    }
    
    // Get users and filter by name (Firestore doesn't support full-text search)
    const snap = await query.limit(parsedLimit * 5).get();
    
    let users = snap.docs
      .filter(doc => {
        const name = doc.data().name?.toLowerCase() || '';
        return name.includes(searchTerm);
      })
      .filter(doc => !excludeUid || doc.id !== excludeUid)
      .slice(0, parsedLimit)
      .map(doc => {
        const d = doc.data();
        return {
          uid: doc.id,
          name: d.name || '',
          avatar: d.avatar || '',
          college: d.college || '',
          verificationStatus: d.verificationStatus || 'unknown'
        };
      });
    
    res.json(users);
  } catch (err) {
    console.error('Error searching users:', err);
    res.status(500).json({ error: 'Failed to search users' });
  }
});

// POST /user/rate - Rate a user after transaction
router.post('/rate', async (req, res) => {
  try {
    const { raterId, ratedUserId, rating, comment, transactionId } = req.body;
    
    if (!raterId || !isValidUid(raterId)) {
      return res.status(400).json({ error: 'Valid raterId is required' });
    }
    if (!ratedUserId || !isValidUid(ratedUserId)) {
      return res.status(400).json({ error: 'Valid ratedUserId is required' });
    }
    if (raterId === ratedUserId) {
      return res.status(400).json({ error: 'Cannot rate yourself' });
    }
    if (typeof rating !== 'number' || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }
    if (comment && !isValidLength(comment, 0, 200)) {
      return res.status(400).json({ error: 'Comment must be under 200 characters' });
    }
    
    const ratedUserRef = db.collection('users').doc(ratedUserId);
    
    // Use transaction to update rating atomically
    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(ratedUserRef);
      
      if (!userDoc.exists) {
        throw new Error('User not found');
      }
      
      const data = userDoc.data();
      const currentRating = data.rating || 0;
      const totalRatings = data.totalRatings || 0;
      
      // Calculate new average rating
      const newTotalRatings = totalRatings + 1;
      const newRating = ((currentRating * totalRatings) + rating) / newTotalRatings;
      
      // Save the rating record
      const ratingRef = ratedUserRef.collection('ratings').doc();
      transaction.set(ratingRef, {
        raterId,
        rating,
        comment: comment ? sanitizeHtml(comment) : '',
        transactionId: transactionId || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Update user's average rating
      transaction.update(ratedUserRef, {
        rating: Math.round(newRating * 10) / 10, // Round to 1 decimal
        totalRatings: newTotalRatings
      });
    });
    
    // Update trust score using TrustScoreManager
    try {
      await TrustScoreManager.onRatingReceived(ratedUserId, rating, { 
        transactionId, 
        raterId 
      });
      console.log(`[RATING] Trust score updated for ${ratedUserId} with rating ${rating}`);
    } catch (trustError) {
      console.error('[RATING] Failed to update trust score:', trustError);
    }
    
    res.json({ success: true, message: 'Rating submitted successfully' });
  } catch (err) {
    console.error('Error rating user:', err);
    if (err.message === 'User not found') {
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(500).json({ error: 'Failed to submit rating' });
  }
});

// GET /user/ratings/:uid - Get user's ratings
router.get('/ratings/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    const { limit = 10 } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const parsedLimit = Math.min(parseInt(limit, 10) || 10, 50);
    
    const ratingsSnap = await db.collection('users').doc(uid)
      .collection('ratings')
      .orderBy('createdAt', 'desc')
      .limit(parsedLimit)
      .get();
    
    // Batch fetch rater details
    const raterIds = [...new Set(ratingsSnap.docs.map(doc => doc.data().raterId))];
    const raterMap = await batchGetDocsAsMap('users', raterIds);
    
    const ratings = ratingsSnap.docs.map(doc => {
      const d = doc.data();
      const rater = raterMap[d.raterId] || {};
      return {
        id: doc.id,
        rating: d.rating,
        comment: d.comment || '',
        raterName: rater.name || 'Anonymous',
        raterAvatar: rater.avatar || '',
        createdAt: d.createdAt
      };
    });
    
    res.json(ratings);
  } catch (err) {
    console.error('Error fetching ratings:', err);
    res.status(500).json({ error: 'Failed to fetch ratings' });
  }
});

// POST /user/rate - Rate a user
router.post('/rate', async (req, res) => {
  try {
    const { raterUid, ratedUid, rating } = req.body;
    
    // Validation
    if (!raterUid || !isValidUid(raterUid)) {
      return res.status(400).json({ error: 'Valid raterUid is required' });
    }
    if (!ratedUid || !isValidUid(ratedUid)) {
      return res.status(400).json({ error: 'Valid ratedUid is required' });
    }
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }
    if (raterUid === ratedUid) {
      return res.status(400).json({ error: 'Cannot rate yourself' });
    }
    
    // Check if both users exist
    const [raterDoc, ratedDoc] = await Promise.all([
      db.collection('users').doc(raterUid).get(),
      db.collection('users').doc(ratedUid).get()
    ]);
    
    if (!raterDoc.exists || !ratedDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if users are friends (optional - you may remove this check)
    const friendshipDoc = await db.collection('users').doc(raterUid)
      .collection('friends').doc(ratedUid).get();
    
    if (!friendshipDoc.exists) {
      return res.status(403).json({ error: 'You can only rate friends' });
    }
    
    const ratingData = {
      raterId: raterUid,
      ratedUserId: ratedUid,
      rating: Number(rating),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Use transaction to handle rating update
    await db.runTransaction(async (transaction) => {
      // Check if user already rated this person
      const existingRatingQuery = await db.collection('ratings')
        .where('raterId', '==', raterUid)
        .where('ratedUserId', '==', ratedUid)
        .get();
      
      if (!existingRatingQuery.empty) {
        // Update existing rating
        const existingDoc = existingRatingQuery.docs[0];
        const existingRating = existingDoc.data().rating;
        transaction.update(existingDoc.ref, {
          rating: Number(rating),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Update rated user's average rating
        const ratedUserData = ratedDoc.data();
        const currentTotal = (ratedUserData.rating || 0) * (ratedUserData.totalRatings || 0);
        const newTotal = currentTotal - existingRating + Number(rating);
        const newAverage = newTotal / (ratedUserData.totalRatings || 1);
        
        transaction.update(db.collection('users').doc(ratedUid), {
          rating: Math.round(newAverage * 10) / 10 // Round to 1 decimal
        });
      } else {
        // Add new rating
        const newRatingRef = db.collection('ratings').doc();
        transaction.set(newRatingRef, ratingData);
        
        // Update rated user's average rating and count
        const ratedUserData = ratedDoc.data();
        const currentTotal = (ratedUserData.rating || 0) * (ratedUserData.totalRatings || 0);
        const newTotal = currentTotal + Number(rating);
        const newCount = (ratedUserData.totalRatings || 0) + 1;
        const newAverage = newTotal / newCount;
        
        transaction.update(db.collection('users').doc(ratedUid), {
          rating: Math.round(newAverage * 10) / 10, // Round to 1 decimal
          totalRatings: newCount
        });
      }
    });
    
    res.json({ success: true, message: 'Rating submitted successfully' });
  } catch (err) {
    console.error('Error submitting rating:', err);
    res.status(500).json({ error: 'Failed to submit rating' });
  }
});

// --- ENHANCED NOTIFICATION ROUTES ---

// GET /user/notifications - Get user's notifications with filtering and pagination
router.get('/notifications', async (req, res) => {
  try {
    const { uid, limit = 50, offset = 0, type, unreadOnly = 'false' } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    let query = db.collection('notifications')
      .where('uid', '==', uid)
      .orderBy('createdAt', 'desc');
    
    // Apply filters
    if (type) {
      query = query.where('type', '==', type);
    }
    
    if (unreadOnly === 'true') {
      query = query.where('read', '==', false);
    }
    
    // Apply pagination
    const parsedLimit = Math.min(parseInt(limit), 100);
    const parsedOffset = parseInt(offset) || 0;
    
    if (parsedOffset > 0) {
      const offsetSnapshot = await query.limit(parsedOffset).get();
      if (!offsetSnapshot.empty) {
        const lastDoc = offsetSnapshot.docs[offsetSnapshot.docs.length - 1];
        query = query.startAfter(lastDoc);
      }
    }
    
    const snapshot = await query.limit(parsedLimit).get();
    
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || doc.data().createdAt
    }));
    
    // Get total count and unread count
    const [totalCountSnap, unreadCountSnap] = await Promise.all([
      db.collection('notifications').where('uid', '==', uid).count().get(),
      db.collection('notifications')
        .where('uid', '==', uid)
        .where('read', '==', false)
        .count().get()
    ]);
    
    res.json({ 
      success: true, 
      notifications,
      pagination: {
        limit: parsedLimit,
        offset: parsedOffset,
        total: totalCountSnap.data().count,
        unread: unreadCountSnap.data().count,
        hasMore: notifications.length === parsedLimit
      }
    });
  } catch (err) {
    console.error('Error fetching notifications:', err);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

// GET /user/notifications/categories - Get notification types/categories
router.get('/notifications/categories', async (req, res) => {
  try {
    const categories = [
      { type: 'friend_request', label: 'Friend Requests', icon: 'person_add' },
      { type: 'friend_accepted', label: 'Friend Accepted', icon: 'person_check' },
      { type: 'group_member_joined', label: 'Group Activity', icon: 'group_add' },
      { type: 'group_joined', label: 'Group Joined', icon: 'group' },
      { type: 'transaction_request', label: 'Item Requests', icon: 'swap_horiz' },
      { type: 'transaction_completed', label: 'Transactions', icon: 'check_circle' },
      { type: 'achievement_unlocked', label: 'Achievements', icon: 'emoji_events' },
      { type: 'reward_earned', label: 'Rewards', icon: 'star' },
      { type: 'verification_approved', label: 'Verification', icon: 'verified' },
      { type: 'system', label: 'System Updates', icon: 'info' },
    ];
    
    res.json({ success: true, categories });
  } catch (err) {
    console.error('Error fetching notification categories:', err);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// GET /user/notifications/unread-count - Get unread notification count
router.get('/notifications/unread-count', async (req, res) => {
  try {
    const { uid } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const snapshot = await db.collection('notifications')
      .where('uid', '==', uid)
      .where('read', '==', false)
      .count()
      .get();
    
    res.json({ success: true, count: snapshot.data().count });
  } catch (err) {
    console.error('Error fetching notification count:', err);
    res.status(500).json({ error: 'Failed to fetch notification count' });
  }
});

// POST /user/notifications/mark-read - Mark notification as read
router.post('/notifications/mark-read', async (req, res) => {
  try {
    const { uid, notificationId } = trimObjectStrings(req.body);
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    if (!notificationId) {
      return res.status(400).json({ error: 'Notification ID is required' });
    }
    
    const notificationRef = db.collection('notifications').doc(notificationId);
    const notification = await notificationRef.get();
    
    if (!notification.exists) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    const notificationData = notification.data();
    if (notificationData.uid !== uid) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    await notificationRef.update({ read: true });
    res.json({ success: true, message: 'Notification marked as read' });
  } catch (err) {
    console.error('Error marking notification as read:', err);
    res.status(500).json({ error: 'Failed to mark notification as read' });
  }
});

// POST /user/notifications/mark-all-read - Mark all notifications as read
router.post('/notifications/mark-all-read', async (req, res) => {
  try {
    const { uid } = trimObjectStrings(req.body);
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const snapshot = await db.collection('notifications')
      .where('uid', '==', uid)
      .where('read', '==', false)
      .get();
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, { read: true });
    });
    
    await batch.commit();
    res.json({ success: true, message: 'All notifications marked as read' });
  } catch (err) {
    console.error('Error marking all notifications as read:', err);
    res.status(500).json({ error: 'Failed to mark all notifications as read' });
  }
});

// DELETE /user/notifications/clear-all - Clear all notifications
router.delete('/notifications/clear-all', async (req, res) => {
  try {
    const { uid } = req.body;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const snapshot = await db.collection('notifications')
      .where('uid', '==', uid)
      .get();
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    res.json({ success: true, message: 'All notifications cleared' });
  } catch (err) {
    console.error('Error clearing notifications:', err);
    res.status(500).json({ error: 'Failed to clear notifications' });
  }
});

// --- REWARD SYSTEM ROUTES ---

// GET /user/rewards - Get user's rewards and achievements
router.get('/rewards', async (req, res) => {
  try {
    const { uid } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    // Get user rewards
    const rewardsSnapshot = await db.collection('rewards')
      .where('uid', '==', uid)
      .orderBy('earnedAt', 'desc')
      .limit(100)
      .get();
    
    const rewards = rewardsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      earnedAt: doc.data().earnedAt?.toDate?.()?.toISOString() || doc.data().earnedAt
    }));
    
    // Get user achievements
    const achievementsSnapshot = await db.collection('achievements')
      .where('uid', '==', uid)
      .orderBy('unlockedAt', 'desc')
      .limit(100)
      .get();
    
    const achievements = achievementsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      unlockedAt: doc.data().unlockedAt?.toDate?.()?.toISOString() || doc.data().unlockedAt
    }));
    
    // Calculate total points
    const totalPoints = rewards.reduce((sum, reward) => sum + (reward.points || 0), 0);
    
    res.json({ 
      success: true, 
      rewards, 
      achievements, 
      totalPoints,
      summary: {
        totalRewards: rewards.length,
        totalAchievements: achievements.length,
        pointsEarned: totalPoints
      }
    });
  } catch (err) {
    console.error('Error fetching rewards:', err);
    res.status(500).json({ error: 'Failed to fetch rewards' });
  }
});

// POST /user/rewards/claim - Claim a reward
router.post('/rewards/claim', async (req, res) => {
  try {
    const { uid, rewardId } = trimObjectStrings(req.body);
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    if (!rewardId) {
      return res.status(400).json({ error: 'Reward ID is required' });
    }
    
    const rewardRef = db.collection('rewards').doc(rewardId);
    const reward = await rewardRef.get();
    
    if (!reward.exists) {
      return res.status(404).json({ error: 'Reward not found' });
    }
    
    const rewardData = reward.data();
    if (rewardData.uid !== uid) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (rewardData.claimed) {
      return res.status(400).json({ error: 'Reward already claimed' });
    }
    
    // Update reward as claimed
    await rewardRef.update({ 
      claimed: true, 
      claimedAt: new Date()
    });
    
    // Create notification for claimed reward
    await db.collection('notifications').add({
      uid: uid,
      type: 'reward_claimed',
      title: 'Reward Claimed!',
      message: `You've successfully claimed your reward: ${rewardData.title}`,
      data: {
        rewardId,
        points: rewardData.points,
        rewardType: rewardData.type
      },
      read: false,
      createdAt: new Date()
    });
    
    res.json({ 
      success: true, 
      message: 'Reward claimed successfully',
      points: rewardData.points
    });
  } catch (err) {
    console.error('Error claiming reward:', err);
    res.status(500).json({ error: 'Failed to claim reward' });
  }
});

// GET /user/leaderboard - Get leaderboard data
router.get('/leaderboard', async (req, res) => {
  try {
    const { type = 'points', limit = 10 } = req.query;
    
    let orderByField = 'totalPoints';
    if (type === 'transactions') orderByField = 'completedTransactions';
    if (type === 'lending') orderByField = 'itemsLent';
    if (type === 'borrowing') orderByField = 'itemsBorrowed';
    
    const snapshot = await db.collection('users')
      .orderBy(orderByField, 'desc')
      .limit(Math.min(parseInt(limit), 50))
      .get();
    
    const leaderboard = snapshot.docs.map((doc, index) => {
      const userData = doc.data();
      return {
        rank: index + 1,
        uid: doc.id,
        displayName: userData.displayName || 'Anonymous',
        profilePicture: userData.profilePicture || null,
        value: userData[orderByField] || 0,
        badge: index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : null
      };
    });
    
    res.json({ success: true, leaderboard, type });
  } catch (err) {
    console.error('Error fetching leaderboard:', err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// --- RATING SYSTEM ROUTES ---

// POST /user/submit-rating - Submit a rating for a user
router.post('/submit-rating', async (req, res) => {
  try {
    const { fromUid, toUid, rating, review, transactionId } = trimObjectStrings(req.body);
    
    if (!fromUid || !isValidUid(fromUid)) {
      return res.status(400).json({ error: 'Valid fromUid is required' });
    }
    if (!toUid || !isValidUid(toUid)) {
      return res.status(400).json({ error: 'Valid toUid is required' });
    }
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }
    if (fromUid === toUid) {
      return res.status(400).json({ error: 'Cannot rate yourself' });
    }
    
    // Check if rating already exists for this transaction
    if (transactionId) {
      const existingRating = await db.collection('ratings')
        .where('fromUid', '==', fromUid)
        .where('transactionId', '==', transactionId)
        .limit(1)
        .get();
      
      if (!existingRating.empty) {
        return res.status(400).json({ error: 'Rating already submitted for this transaction' });
      }
    }
    
    // Create rating document
    const ratingData = {
      fromUid,
      toUid,
      rating: parseInt(rating),
      review: sanitizeHtml(review || ''),
      transactionId: transactionId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('ratings').add(ratingData);
    
    // Update user's rating and trust score
    await updateUserRatingAndTrustScore(toUid);
    
    // Create notification for rated user
    const fromUserDoc = await db.collection('users').doc(fromUid).get();
    const fromUserName = fromUserDoc.data()?.name || 'Someone';
    
    await db.collection('notifications').add({
      uid: toUid,
      type: 'rating_received',
      title: 'New Rating Received',
      message: `${fromUserName} rated you ${rating} stars${review ? ': "' + review + '"' : ''}`,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Rating submitted successfully' });
  } catch (err) {
    console.error('Error submitting rating:', err);
    res.status(500).json({ error: 'Failed to submit rating' });
  }
});

// GET /user/ratings - Get ratings for a user
router.get('/ratings', async (req, res) => {
  try {
    const { uid, limit = 20 } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const snapshot = await db.collection('ratings')
      .where('toUid', '==', uid)
      .orderBy('createdAt', 'desc')
      .limit(Math.min(parseInt(limit), 50))
      .get();
    
    const ratings = [];
    const userIds = new Set();
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      ratings.push({
        id: doc.id,
        ...data,
        createdAt: data.createdAt?.toDate?.()?.toISOString() || data.createdAt
      });
      userIds.add(data.fromUid);
    });
    
    // Fetch user names for ratings
    const userMap = await batchGetDocsAsMap('users', Array.from(userIds));
    
    const enrichedRatings = ratings.map(rating => ({
      ...rating,
      fromUserName: userMap[rating.fromUid]?.name || 'Anonymous',
      fromUserAvatar: userMap[rating.fromUid]?.avatar || null
    }));
    
    res.json({ success: true, ratings: enrichedRatings });
  } catch (err) {
    console.error('Error fetching ratings:', err);
    res.status(500).json({ error: 'Failed to fetch ratings' });
  }
});

// Helper function to update user rating and trust score
async function updateUserRatingAndTrustScore(uid) {
  try {
    // Get all ratings for user
    const ratingsSnapshot = await db.collection('ratings')
      .where('toUid', '==', uid)
      .get();
    
    const ratings = ratingsSnapshot.docs.map(doc => doc.data());
    
    // Get user's completed transactions count
    const transactionsSnapshot = await db.collection('transactions')
      .where('borrowerUid', '==', uid)
      .where('status', '==', 'completed')
      .count()
      .get();
    
    const lentTransactionsSnapshot = await db.collection('transactions')
      .where('lenderUid', '==', uid)
      .where('status', '==', 'completed')
      .count()
      .get();
    
    const completedTransactions = transactionsSnapshot.data().count + lentTransactionsSnapshot.data().count;
    
    // Get user's verification status
    const userDoc = await db.collection('users').doc(uid).get();
    const verificationStatus = userDoc.data()?.verificationStatus || 'unknown';
    
    // Calculate new values
    const avgRating = calculateUserRating(ratings);
    
    // Update user document (trust score managed separately by TrustScoreManager)
    await db.collection('users').doc(uid).update({
      rating: avgRating,
      totalRatings: ratings.length,
      lastRatingUpdate: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`Updated user ${uid} - Rating: ${avgRating}`);
  } catch (err) {
    console.error('Error updating user rating and trust score:', err);
  }
}

// Get user verification status
router.get('/:uid/verification-status', async (req, res) => {
  try {
    const { uid } = req.params;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    const verificationData = {
      verificationStatus: userData.verificationStatus || 'unknown',
      verificationSubmittedAt: userData.verificationSubmittedAt?.toDate?.() || userData.verificationSubmittedAt,
      verifiedAt: userData.verifiedAt?.toDate?.() || userData.verifiedAt,
      rejectedAt: userData.rejectedAt?.toDate?.() || userData.rejectedAt,
      rejectionReason: userData.rejectionReason,
      adminNotes: userData.adminNotes,
      verificationFile: userData.verificationFile
    };
    
    res.status(200).json({
      success: true,
      data: verificationData
    });
  } catch (error) {
    console.error('Error getting verification status:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get verification status'
    });
  }
});

// GET /user/items - Get user's items with pagination
router.get('/items', async (req, res) => {
  try {
    const { uid, limit = 10, offset = 0, availableOnly = 'true' } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    let query = db.collection('items').where('ownerId', '==', uid);
    
    if (availableOnly === 'true') {
      query = query.where('available', '==', true);
    }
    
    const itemsSnapshot = await query
      .orderBy('createdAt', 'desc')
      .limit(Math.min(parseInt(limit), 50))
      .offset(parseInt(offset))
      .get();
    
    const items = itemsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate?.()?.toISOString() || doc.data().createdAt
    }));
    
    // Get total count for pagination
    const countSnapshot = await db.collection('items')
      .where('ownerId', '==', uid)
      .where('available', '==', availableOnly === 'true')
      .count()
      .get();
    
    res.json({
      success: true,
      items,
      pagination: {
        total: countSnapshot.data().count,
        limit: parseInt(limit),
        offset: parseInt(offset),
        hasMore: countSnapshot.data().count > (parseInt(offset) + items.length)
      }
    });
  } catch (err) {
    console.error('Error fetching user items:', err);
    res.status(500).json({ error: 'Failed to fetch user items' });
  }
});

// GET /user/stats - Get user statistics
router.get('/stats', async (req, res) => {
  try {
    const { uid } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    // Get user document
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    
    // Fetch all statistics in parallel for better performance
    const [
      borrowedCountSnap,
      lentCountSnap,
      activeItemsSnap,
      completedBorrowsSnap,
      completedLendsSnap,
      ratingsSnap,
      friendsCountSnap
    ] = await Promise.all([
      // Total items borrowed
      db.collection('transactions')
        .where('borrowerUid', '==', uid)
        .count()
        .get(),
      
      // Total items lent out
      db.collection('transactions')
        .where('lenderUid', '==', uid)
        .count()
        .get(),
      
      // Active items listed
      db.collection('items')
        .where('ownerId', '==', uid)
        .where('available', '==', true)
        .count()
        .get(),
      
      // Completed borrows
      db.collection('transactions')
        .where('borrowerUid', '==', uid)
        .where('status', '==', 'completed')
        .count()
        .get(),
      
      // Completed lends
      db.collection('transactions')
        .where('lenderUid', '==', uid)
        .where('status', '==', 'completed')
        .count()
        .get(),
      
      // Total ratings received
      db.collection('ratings')
        .where('toUid', '==', uid)
        .count()
        .get(),
      
      // Friends count
      db.collection('users').doc(uid).collection('friends')
        .count()
        .get()
    ]);
    
    const completedBorrows = completedBorrowsSnap.data().count;
    const completedLends = completedLendsSnap.data().count;
    
    const stats = {
      totalBorrows: borrowedCountSnap.data().count,
      totalLends: lentCountSnap.data().count,
      activeListings: activeItemsSnap.data().count,
      completedTransactions: completedBorrows + completedLends,
      completedBorrows,
      completedLends,
      totalRatings: ratingsSnap.data().count,
      friendsCount: friendsCountSnap.data().count,
      trustScore: userData.trustScore || 0,
      rating: userData.rating || 0,
      verificationStatus: userData.verificationStatus || 'unknown',
      joinedDate: userData.createdAt?.toDate?.()?.toISOString() || userData.createdAt,
      // Calculated metrics
      successRate: completedBorrows + completedLends > 0 ? 
        Math.round(((completedBorrows + completedLends) / (borrowedCountSnap.data().count + lentCountSnap.data().count)) * 100) : 
        0,
      avgResponseTime: userData.avgResponseTime || null,
      lastActiveDate: userData.lastLoginAt?.toDate?.()?.toISOString() || userData.lastLoginAt
    };
    
    res.json({
      success: true,
      stats
    });
  } catch (err) {
    console.error('Error fetching user stats:', err);
    res.status(500).json({ error: 'Failed to fetch user statistics' });
  }
});

// GET /user/:uid/trust-score - Get user trust score details
router.get('/:uid/trust-score', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.params;
    
    if (!isValidUid(uid)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }
    
    // Import managers
    const { TrustScoreManager } = require('../utils/trust-score-manager');
    
    // Get current score and tier
    const scoreData = await TrustScoreManager.getCurrentScore(uid);
    
    // Get history (last 20 events)
    const history = await TrustScoreManager.getHistory(uid, 20);
    
    res.json({
      success: true,
      trustScore: scoreData,
      history
    });
  } catch (err) {
    console.error('Error fetching trust score:', err);
    res.status(500).json({ error: 'Failed to fetch trust score' });
  }
});

// GET /user/:uid/wallet - Get user wallet details
router.get('/:uid/wallet', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.params;
    
    // Only allow users to view their own wallet
    if (req.user.uid !== uid) {
      return res.status(403).json({ error: 'Cannot view another user\'s wallet' });
    }
    
    if (!isValidUid(uid)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }
    
    const { CoinsManager } = require('../utils/coins-manager');
    
    // Get wallet details
    const wallet = await CoinsManager.getWalletDetails(uid);
    
    // Get earning opportunities
    const opportunities = CoinsManager.getEarningOpportunities();
    
    // Get spending options
    const spendingOptions = CoinsManager.getSpendingOptions();
    
    res.json({
      success: true,
      wallet,
      opportunities,
      spendingOptions
    });
  } catch (err) {
    console.error('Error fetching wallet:', err);
    res.status(500).json({ error: 'Failed to fetch wallet details' });
  }
});

// GET /user/:uid/coin-transactions - Get coin transaction history
router.get('/:uid/coin-transactions', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.params;
    const { limit = 50 } = req.query;
    
    // Only allow users to view their own transactions
    if (req.user.uid !== uid) {
      return res.status(403).json({ error: 'Cannot view another user\'s transactions' });
    }
    
    if (!isValidUid(uid)) {
      return res.status(400).json({ error: 'Invalid user ID' });
    }
    
    const { CoinsManager } = require('../utils/coins-manager');
    
    const transactions = await CoinsManager.getTransactionHistory(uid, parseInt(limit));
    
    res.json({
      success: true,
      transactions
    });
  } catch (err) {
    console.error('Error fetching coin transactions:', err);
    res.status(500).json({ error: 'Failed to fetch transaction history' });
  }
});

module.exports = router;

