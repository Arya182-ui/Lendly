const express = require('express');
const admin = require('firebase-admin');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { isValidUid } = require('../utils/validators');

const router = express.Router();
const db = admin.firestore();

// Constants for friendship system
const FRIENDSHIP_CONSTANTS = {
  MAX_FRIENDS: 500,
  MAX_PENDING_REQUESTS: 50,
  REQUEST_COOLDOWN_HOURS: 24
};

// Helper function to create notification
async function createNotification(uid, type, title, message, data = {}) {
  try {
    await db.collection('notifications').add({
      uid,
      type,
      title,
      message,
      data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } catch (err) {
    console.error('Failed to create notification:', err);
  }
}

// Helper function to check for recent duplicate requests
async function checkRequestCooldown(fromUid, toUid) {
  const cooldownTime = new Date(Date.now() - (FRIENDSHIP_CONSTANTS.REQUEST_COOLDOWN_HOURS * 60 * 60 * 1000));
  
  const recentRequestsSnap = await db.collection('friendRequestHistory')
    .where('fromUid', '==', fromUid)
    .where('toUid', '==', toUid)
    .where('createdAt', '>', admin.firestore.Timestamp.fromDate(cooldownTime))
    .limit(1)
    .get();
    
  return !recentRequestsSnap.empty;
}

// --- Get User's Friends List (Optimized - No N+1 queries) ---
router.get('/friends', async (req, res) => {
  const { uid } = req.query;
  
  if (!uid || !isValidUid(uid)) {
    return res.status(400).json({ error: 'Valid UID required' });
  }
  
  try {
    // Fetch friends, friend requests, and blocked users in parallel
    const [friendsSnap, requestsSnap, blockedSnap] = await Promise.all([
      db.collection('users').doc(uid).collection('friends').get(),
      db.collection('users').doc(uid).collection('friendRequests').get(),
      db.collection('users').doc(uid).collection('blockedUsers').get()
    ]);
    
    // Collect all UIDs we need to fetch
    const friendUids = friendsSnap.docs.map(doc => doc.id);
    const requestUids = requestsSnap.docs.map(doc => doc.id);
    const blockedUids = blockedSnap.docs.map(doc => doc.id);
    const allUids = [...new Set([...friendUids, ...requestUids])];
    
    // Batch fetch all user profiles at once (prevents N+1)
    const userMap = await batchGetDocsAsMap('users', allUids);
    
    // Fetch friends of each friend/requester in parallel to compute mutual friends
    const friendsOfOthersPromises = allUids.map(async (otherUid) => {
      const otherFriendsSnap = await db.collection('users').doc(otherUid).collection('friends').get();
      return { uid: otherUid, friendIds: otherFriendsSnap.docs.map(d => d.id) };
    });
    const friendsOfOthers = await Promise.all(friendsOfOthersPromises);
    const friendsOfOthersMap = Object.fromEntries(friendsOfOthers.map(f => [f.uid, new Set(f.friendIds)]));
    
    // Helper to count mutual friends
    const countMutualFriends = (otherUid) => {
      const otherFriends = friendsOfOthersMap[otherUid];
      if (!otherFriends) return 0;
      return friendUids.filter(fid => fid !== otherUid && otherFriends.has(fid)).length;
    };
    
    // Build friends list with additional metadata
    const friends = friendUids
      .filter(fid => userMap[fid])
      .map(fid => {
        const friendDoc = friendsSnap.docs.find(doc => doc.id === fid);
        const friendData = friendDoc?.data() || {};
        return {
          uid: fid,
          name: userMap[fid].name || '',
          avatar: userMap[fid].avatar || '',
          college: userMap[fid].college || '',
          isOnline: userMap[fid].isOnline || false,
          lastSeen: userMap[fid].lastSeen || null,
          friendsSince: friendData.since || null,
          mutualFriends: countMutualFriends(fid),
        };
      });
    
    // Build friend requests list with timestamps
    const friendRequests = requestUids
      .filter(rid => userMap[rid])
      .map(rid => {
        const requestDoc = requestsSnap.docs.find(doc => doc.id === rid);
        const requestData = requestDoc?.data() || {};
        return {
          uid: rid,
          name: userMap[rid].name || '',
          avatar: userMap[rid].avatar || '',
          college: userMap[rid].college || '',
          requestedAt: requestData.sentAt || null,
          mutualFriends: countMutualFriends(rid),
        };
      });

    res.json({ 
      success: true,
      friends, 
      friendRequests,
      stats: {
        friendsCount: friends.length,
        pendingRequestsCount: friendRequests.length,
        blockedUsersCount: blockedUids.length
      }
    });
  } catch (err) {
    console.error('Error fetching friends:', err);
    res.status(500).json({ error: 'Failed to fetch friends' });
  }
});

// --- Send Friend Request with Enhanced Validation ---
router.post('/send-friend-request', async (req, res) => {
  const { fromUid, toUid, message } = req.body;
  
  // Enhanced validation
  if (!fromUid || !isValidUid(fromUid)) {
    return res.status(400).json({ error: 'Valid fromUid required' });
  }
  if (!toUid || !isValidUid(toUid)) {
    return res.status(400).json({ error: 'Valid toUid required' });
  }
  if (fromUid === toUid) {
    return res.status(400).json({ error: 'Cannot send friend request to yourself' });
  }
  if (message && message.length > 200) {
    return res.status(400).json({ error: 'Message too long (max 200 characters)' });
  }
  
  try {
    // Check if both users exist
    const [fromUserDoc, toUserDoc] = await Promise.all([
      db.collection('users').doc(fromUid).get(),
      db.collection('users').doc(toUid).get()
    ]);
    
    if (!fromUserDoc.exists) {
      return res.status(404).json({ error: 'Sender user not found' });
    }
    if (!toUserDoc.exists) {
      return res.status(404).json({ error: 'Recipient user not found' });
    }
    
    // Check if recipient has blocked the sender
    const blockedDoc = await db.collection('users').doc(toUid).collection('blockedUsers').doc(fromUid).get();
    if (blockedDoc.exists) {
      return res.status(403).json({ error: 'Unable to send friend request' });
    }
    
    // Check for request cooldown
    const hasCooldown = await checkRequestCooldown(fromUid, toUid);
    if (hasCooldown) {
      return res.status(429).json({ 
        error: `Please wait ${FRIENDSHIP_CONSTANTS.REQUEST_COOLDOWN_HOURS} hours before sending another request` 
      });
    }
    
    // Check if already friends
    const existingFriend = await db.collection('users').doc(fromUid).collection('friends').doc(toUid).get();
    if (existingFriend.exists) {
      return res.status(400).json({ error: 'Already friends with this user' });
    }
    
    // Check if request already exists
    const existingRequest = await db.collection('users').doc(toUid).collection('friendRequests').doc(fromUid).get();
    if (existingRequest.exists) {
      return res.status(400).json({ error: 'Friend request already sent' });
    }
    
    // Check friendship limits
    const [senderFriendsCount, recipientRequestsCount] = await Promise.all([
      db.collection('users').doc(fromUid).collection('friends').count().get(),
      db.collection('users').doc(toUid).collection('friendRequests').count().get()
    ]);
    
    if (senderFriendsCount.data().count >= FRIENDSHIP_CONSTANTS.MAX_FRIENDS) {
      return res.status(400).json({ error: 'Friend limit reached' });
    }
    
    if (recipientRequestsCount.data().count >= FRIENDSHIP_CONSTANTS.MAX_PENDING_REQUESTS) {
      return res.status(400).json({ error: 'Recipient has too many pending requests' });
    }
    
    // Create friend request with transaction
    await db.runTransaction(async (transaction) => {
      const requestData = {
        fromUid,
        status: 'pending',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(message && { message })
      };
      
      // Add request to recipient's collection
      transaction.set(
        db.collection('users').doc(toUid).collection('friendRequests').doc(fromUid),
        requestData
      );
      
      // Log request history for cooldown tracking
      transaction.set(
        db.collection('friendRequestHistory').doc(),
        {
          fromUid,
          toUid,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        }
      );
    });
    
    // Create notification for recipient
    const senderData = fromUserDoc.data();
    await createNotification(
      toUid,
      'friend_request',
      'New Friend Request',
      `${senderData?.name || 'Someone'} sent you a friend request`,
      { fromUid, senderName: senderData?.name || 'Unknown' }
    );
    
    res.status(201).json({ success: true, message: 'Friend request sent successfully' });
  } catch (err) {
    console.error('Error sending friend request:', err);
    res.status(500).json({ error: 'Failed to send friend request' });
  }
});

// --- Accept Friend Request with Enhanced Features ---
router.post('/accept-friend-request', async (req, res) => {
  const { fromUid, toUid } = req.body;
  
  if (!fromUid || !isValidUid(fromUid)) {
    return res.status(400).json({ error: 'Valid fromUid required' });
  }
  if (!toUid || !isValidUid(toUid)) {
    return res.status(400).json({ error: 'Valid toUid required' });
  }
  
  try {
    // Use a transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      const requestRef = db.collection('users').doc(toUid).collection('friendRequests').doc(fromUid);
      const requestDoc = await transaction.get(requestRef);
      
      if (!requestDoc.exists) {
        throw new Error('Friend request not found');
      }
      
      const now = admin.firestore.FieldValue.serverTimestamp();
      
      // Delete request and add both as friends atomically
      transaction.delete(requestRef);
      transaction.set(
        db.collection('users').doc(toUid).collection('friends').doc(fromUid),
        { 
          uid: fromUid, 
          since: now,
          status: 'active'
        }
      );
      transaction.set(
        db.collection('users').doc(fromUid).collection('friends').doc(toUid),
        { 
          uid: toUid, 
          since: now,
          status: 'active'
        }
      );
      
      // Update friend counts
      transaction.update(
        db.collection('users').doc(toUid),
        { friendsCount: admin.firestore.FieldValue.increment(1) }
      );
      transaction.update(
        db.collection('users').doc(fromUid),
        { friendsCount: admin.firestore.FieldValue.increment(1) }
      );
    });
    
    // Get user data for notifications
    const [fromUserDoc, toUserDoc] = await Promise.all([
      db.collection('users').doc(fromUid).get(),
      db.collection('users').doc(toUid).get()
    ]);
    
    // Create notifications for both users
    const fromUserData = fromUserDoc.data();
    const toUserData = toUserDoc.data();
    
    await Promise.all([
      createNotification(
        fromUid,
        'friend_accepted',
        'Friend Request Accepted',
        `${toUserData?.name || 'Someone'} accepted your friend request`,
        { friendUid: toUid, friendName: toUserData?.name || 'Unknown' }
      ),
      createNotification(
        toUid,
        'friendship_confirmed',
        'New Friendship',
        `You and ${fromUserData?.name || 'someone'} are now friends`,
        { friendUid: fromUid, friendName: fromUserData?.name || 'Unknown' }
      )
    ]);
    
    res.json({ 
      success: true, 
      message: 'Friend request accepted successfully',
      friendship: {
        friendUid: fromUid,
        friendName: fromUserData?.name || 'Unknown',
        since: new Date().toISOString()
      }
    });
  } catch (err) {
    console.error('Error accepting friend request:', err);
    if (err.message === 'Friend request not found') {
      return res.status(404).json({ error: err.message });
    }
    res.status(500).json({ error: 'Failed to accept friend request' });
  }
});

// --- Reject Friend Request with Notification ---
router.post('/reject-friend-request', async (req, res) => {
  const { fromUid, toUid } = req.body;
  
  if (!fromUid || !isValidUid(fromUid)) {
    return res.status(400).json({ error: 'Valid fromUid required' });
  }
  if (!toUid || !isValidUid(toUid)) {
    return res.status(400).json({ error: 'Valid toUid required' });
  }
  
  try {
    const requestRef = db.collection('users').doc(toUid).collection('friendRequests').doc(fromUid);
    const requestDoc = await requestRef.get();
    
    if (!requestDoc.exists) {
      return res.status(404).json({ error: 'Friend request not found' });
    }
    
    await requestRef.delete();
    
    res.json({ success: true, message: 'Friend request rejected' });
  } catch (err) {
    console.error('Error rejecting friend request:', err);
    res.status(500).json({ error: 'Failed to reject friend request' });
  }
});

// --- Enhanced Friendship Status with Detailed Information ---
router.get('/friendship-status', async (req, res) => {
  const { uid1, uid2 } = req.query;
  
  if (!uid1 || !isValidUid(uid1) || !uid2 || !isValidUid(uid2)) {
    return res.status(400).json({ error: 'Valid uid1 and uid2 required' });
  }
  
  if (uid1 === uid2) {
    return res.json({ status: 'self' });
  }
  
  try {
    // Check all possible relationships in parallel
    const [friendDoc, reqDoc1, reqDoc2, blockedDoc1, blockedDoc2] = await Promise.all([
      db.collection('users').doc(uid1).collection('friends').doc(uid2).get(),
      db.collection('users').doc(uid2).collection('friendRequests').doc(uid1).get(),
      db.collection('users').doc(uid1).collection('friendRequests').doc(uid2).get(),
      db.collection('users').doc(uid1).collection('blockedUsers').doc(uid2).get(),
      db.collection('users').doc(uid2).collection('blockedUsers').doc(uid1).get()
    ]);
    
    // Check if blocked
    if (blockedDoc1.exists || blockedDoc2.exists) {
      return res.json({ 
        status: 'blocked',
        blockedBy: blockedDoc1.exists ? uid1 : uid2
      });
    }
    
    // Check if friends
    if (friendDoc.exists) {
      const friendshipData = friendDoc.data();
      return res.json({ 
        status: 'friends',
        since: friendshipData.since,
        friendshipStatus: friendshipData.status || 'active'
      });
    }
    
    // Check for pending requests
    if (reqDoc1.exists) {
      const requestData = reqDoc1.data();
      return res.json({ 
        status: 'pending_sent',
        sentAt: requestData.sentAt,
        message: requestData.message || null
      });
    }
    
    if (reqDoc2.exists) {
      const requestData = reqDoc2.data();
      return res.json({ 
        status: 'pending_received',
        sentAt: requestData.sentAt,
        message: requestData.message || null
      });
    }
    
    res.json({ status: 'none' });
  } catch (err) {
    console.error('Error checking friendship status:', err);
    res.status(500).json({ error: 'Failed to check friendship status' });
  }
});

// --- Remove Friend ---
router.post('/remove-friend', async (req, res) => {
  const { uid1, uid2 } = req.body;
  
  if (!uid1 || !isValidUid(uid1) || !uid2 || !isValidUid(uid2)) {
    return res.status(400).json({ error: 'Valid uid1 and uid2 required' });
  }
  
  try {
    await db.runTransaction(async (transaction) => {
      // Remove friendship from both sides
      transaction.delete(db.collection('users').doc(uid1).collection('friends').doc(uid2));
      transaction.delete(db.collection('users').doc(uid2).collection('friends').doc(uid1));
      
      // Update friend counts
      transaction.update(
        db.collection('users').doc(uid1),
        { friendsCount: admin.firestore.FieldValue.increment(-1) }
      );
      transaction.update(
        db.collection('users').doc(uid2),
        { friendsCount: admin.firestore.FieldValue.increment(-1) }
      );
    });
    
    res.json({ success: true, message: 'Friend removed successfully' });
  } catch (err) {
    console.error('Error removing friend:', err);
    res.status(500).json({ error: 'Failed to remove friend' });
  }
});

// --- Block User ---
router.post('/block-user', async (req, res) => {
  const { blockerUid, blockedUid } = req.body;
  
  if (!blockerUid || !isValidUid(blockerUid) || !blockedUid || !isValidUid(blockedUid)) {
    return res.status(400).json({ error: 'Valid blockerUid and blockedUid required' });
  }
  
  if (blockerUid === blockedUid) {
    return res.status(400).json({ error: 'Cannot block yourself' });
  }
  
  try {
    await db.runTransaction(async (transaction) => {
      // Add to blocked users list
      transaction.set(
        db.collection('users').doc(blockerUid).collection('blockedUsers').doc(blockedUid),
        {
          uid: blockedUid,
          blockedAt: admin.firestore.FieldValue.serverTimestamp()
        }
      );
      
      // Remove friendship if exists
      transaction.delete(db.collection('users').doc(blockerUid).collection('friends').doc(blockedUid));
      transaction.delete(db.collection('users').doc(blockedUid).collection('friends').doc(blockerUid));
      
      // Remove any pending friend requests
      transaction.delete(db.collection('users').doc(blockerUid).collection('friendRequests').doc(blockedUid));
      transaction.delete(db.collection('users').doc(blockedUid).collection('friendRequests').doc(blockerUid));
    });
    
    res.json({ success: true, message: 'User blocked successfully' });
  } catch (err) {
    console.error('Error blocking user:', err);
    res.status(500).json({ error: 'Failed to block user' });
  }
});

// --- Unblock User ---
router.post('/unblock-user', async (req, res) => {
  const { blockerUid, blockedUid } = req.body;
  
  if (!blockerUid || !isValidUid(blockerUid) || !blockedUid || !isValidUid(blockedUid)) {
    return res.status(400).json({ error: 'Valid blockerUid and blockedUid required' });
  }
  
  try {
    await db.collection('users').doc(blockerUid).collection('blockedUsers').doc(blockedUid).delete();
    
    res.json({ success: true, message: 'User unblocked successfully' });
  } catch (err) {
    console.error('Error unblocking user:', err);
    res.status(500).json({ error: 'Failed to unblock user' });
  }
});

// --- Get Blocked Users List ---
router.get('/blocked-users', async (req, res) => {
  const { uid } = req.query;
  
  if (!uid || !isValidUid(uid)) {
    return res.status(400).json({ error: 'Valid UID required' });
  }
  
  try {
    const blockedSnap = await db.collection('users').doc(uid).collection('blockedUsers').get();
    const blockedUids = blockedSnap.docs.map(doc => doc.id);
    
    if (blockedUids.length === 0) {
      return res.json({ success: true, blockedUsers: [] });
    }
    
    // Fetch user profiles for blocked users
    const userMap = await batchGetDocsAsMap('users', blockedUids);
    
    const blockedUsers = blockedUids
      .filter(buid => userMap[buid])
      .map(buid => {
        const blockedDoc = blockedSnap.docs.find(doc => doc.id === buid);
        const blockedData = blockedDoc?.data() || {};
        return {
          uid: buid,
          name: userMap[buid].name || 'Unknown',
          avatar: userMap[buid].avatar || '',
          college: userMap[buid].college || '',
          blockedAt: blockedData.blockedAt || null,
        };
      });
    
    res.json({ success: true, blockedUsers });
  } catch (err) {
    console.error('Error fetching blocked users:', err);
    res.status(500).json({ error: 'Failed to fetch blocked users' });
  }
});

module.exports = router;

