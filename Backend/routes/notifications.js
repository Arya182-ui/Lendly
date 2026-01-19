const express = require('express');
const admin = require('firebase-admin');
const { isValidUid, sanitizeHtml } = require('../utils/validators');
const { authenticateUser } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Enhanced notification system
const NOTIFICATION_TYPES = {
  TRANSACTION_REQUEST: 'transaction_request',
  TRANSACTION_ACCEPTED: 'transaction_accepted',
  TRANSACTION_COMPLETED: 'transaction_completed',
  FRIEND_REQUEST: 'friend_request',
  FRIEND_ACCEPTED: 'friend_accepted',
  CHALLENGE_COMPLETED: 'challenge_completed',
  VERIFICATION_APPROVED: 'verification_approved',
  VERIFICATION_REJECTED: 'verification_rejected',
  COINS_EARNED: 'coins_earned',
  DAILY_STREAK: 'daily_streak',
  WELCOME_BONUS: 'welcome_bonus'
};

// Get notifications for user
router.get('/', authenticateUser, async (req, res) => {
  try {
    const uid = req.user.uid; // Use authenticated user
    const { limit = 20, offset = 0 } = req.query;
    
    const notificationsRef = db.collection('users').doc(uid)
      .collection('notifications')
      .orderBy('createdAt', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset));
    
    const snapshot = await notificationsRef.get();
    const notifications = [];
    
    snapshot.forEach(doc => {
      notifications.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    res.json({ notifications });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: 'Failed to fetch notifications' });
  }
});

// Get unread count
router.get('/unread-count', authenticateUser, async (req, res) => {
  try {
    const uid = req.user.uid;
    
    const snapshot = await db.collection('users').doc(uid)
      .collection('notifications')
      .where('read', '==', false)
      .get();
    
    res.json({ count: snapshot.size });
  } catch (error) {
    console.error('Error getting unread count:', error);
    res.status(500).json({ error: 'Failed to get unread count' });
  }
});

// Mark notification as read
router.patch('/:notificationId/read', authenticateUser, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const uid = req.user.uid;
    
    if (!notificationId) {
      return res.status(400).json({ error: 'Invalid notification ID' });
    }
    
    await db.collection('users').doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .update({
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: 'Failed to mark notification as read' });
  }
});

// Mark all notifications as read
router.patch('/mark-all-read', authenticateUser, async (req, res) => {
  try {
    const uid = req.user.uid;
    
    const unreadSnapshot = await db.collection('users').doc(uid)
      .collection('notifications')
      .where('read', '==', false)
      .get();
    
    const batch = db.batch();
    
    unreadSnapshot.forEach(doc => {
      batch.update(doc.ref, {
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
    
    res.json({ 
      success: true, 
      message: `${unreadSnapshot.size} notifications marked as read` 
    });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({ error: 'Failed to mark notifications as read' });
  }
});

// Delete notification
router.delete('/:notificationId', authenticateUser, async (req, res) => {
  try {
    const { notificationId } = req.params;
    const uid = req.user.uid;
    
    if (!notificationId) {
      return res.status(400).json({ error: 'Invalid notification ID' });
    }
    
    await db.collection('users').doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .delete();
    
    res.json({ success: true, message: 'Notification deleted' });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ error: 'Failed to delete notification' });
  }
});
router.post('/create', async (req, res) => {
  try {
    const { 
      recipientUid, 
      type, 
      title, 
      message, 
      data = {},
      senderUid = null,
      actionUrl = null 
    } = req.body;
    
    if (!isValidUid(recipientUid) || !type || !title || !message) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    if (!Object.values(NOTIFICATION_TYPES).includes(type)) {
      return res.status(400).json({ error: 'Invalid notification type' });
    }
    
    const notification = {
      recipientUid: sanitizeHtml(recipientUid),
      type: sanitizeHtml(type),
      title: sanitizeHtml(title),
      message: sanitizeHtml(message),
      data: data,
      senderUid: senderUid ? sanitizeHtml(senderUid) : null,
      actionUrl: actionUrl ? sanitizeHtml(actionUrl) : null,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null
    };
    
    const notificationRef = db.collection('users').doc(recipientUid)
      .collection('notifications').doc();
    
    await notificationRef.set(notification);
    
    res.json({ 
      success: true, 
      notificationId: notificationRef.id,
      message: 'Notification created successfully'
    });
  } catch (error) {
    console.error('Error creating notification:', error);
    res.status(500).json({ error: 'Failed to create notification' });
  }
});

// Bulk create notifications (for broadcasts)
router.post('/create-bulk', async (req, res) => {
  try {
    const { recipientUids, type, title, message, data = {} } = req.body;
    
    if (!Array.isArray(recipientUids) || recipientUids.length === 0) {
      return res.status(400).json({ error: 'recipientUids must be a non-empty array' });
    }
    
    if (!type || !title || !message) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const batch = db.batch();
    const notificationIds = [];
    
    for (const recipientUid of recipientUids) {
      if (!isValidUid(recipientUid)) continue;
      
      const notification = {
        recipientUid: sanitizeHtml(recipientUid),
        type: sanitizeHtml(type),
        title: sanitizeHtml(title),
        message: sanitizeHtml(message),
        data: data,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readAt: null
      };
      
      const notificationRef = db.collection('users').doc(recipientUid)
        .collection('notifications').doc();
      
      batch.set(notificationRef, notification);
      notificationIds.push(notificationRef.id);
    }
    
    await batch.commit();
    
    res.json({ 
      success: true, 
      count: notificationIds.length,
      message: `${notificationIds.length} notifications created successfully`
    });
  } catch (error) {
    console.error('Error creating bulk notifications:', error);
    res.status(500).json({ error: 'Failed to create notifications' });
  }
});

// Helper functions for common notification scenarios
async function notifyTransactionRequest(borrowerUid, lenderUid, itemName, transactionId) {
  return await createNotification({
    recipientUid: lenderUid,
    type: NOTIFICATION_TYPES.TRANSACTION_REQUEST,
    title: 'New Request',
    message: `Someone wants to borrow your ${itemName}`,
    senderUid: borrowerUid,
    data: { transactionId, itemName },
    actionUrl: `/transactions/${transactionId}`
  });
}

async function notifyTransactionAccepted(borrowerUid, lenderUid, itemName, transactionId) {
  return await createNotification({
    recipientUid: borrowerUid,
    type: NOTIFICATION_TYPES.TRANSACTION_ACCEPTED,
    title: 'Request Accepted!',
    message: `Your request for ${itemName} has been accepted`,
    senderUid: lenderUid,
    data: { transactionId, itemName },
    actionUrl: `/transactions/${transactionId}`
  });
}

async function notifyCoinsEarned(recipientUid, amount, reason) {
  return await createNotification({
    recipientUid,
    type: NOTIFICATION_TYPES.COINS_EARNED,
    title: 'Coins Earned!',
    message: `You earned ${amount} coins for ${reason}`,
    data: { amount, reason }
  });
}

async function notifyDailyStreak(recipientUid, streak, coinsEarned) {
  return await createNotification({
    recipientUid,
    type: NOTIFICATION_TYPES.DAILY_STREAK,
    title: `🔥 ${streak} Day Streak!`,
    message: `Keep it up! You earned ${coinsEarned} coins today`,
    data: { streak, coinsEarned }
  });
}

async function createNotification(notificationData) {
  try {
    const notificationRef = db.collection('users').doc(notificationData.recipientUid)
      .collection('notifications').doc();
    
    const notification = {
      ...notificationData,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null
    };
    
    await notificationRef.set(notification);
    return notificationRef.id;
  } catch (error) {
    console.error('Error creating notification:', error);
    return null;
  }
}

// Export helper functions for use in other routes
module.exports = {
  router,
  NOTIFICATION_TYPES,
  notifyTransactionRequest,
  notifyTransactionAccepted,
  notifyCoinsEarned,
  notifyDailyStreak,
  createNotification
};
