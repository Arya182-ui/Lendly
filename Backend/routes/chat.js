const express = require('express');
const admin = require('firebase-admin');
const { isValidUid, isValidLength, sanitizeHtml, parseIntSafe } = require('../utils/validators');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { authenticateUser } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Test route to verify chat router is working
router.get('/test', (req, res) => {
  res.json({ message: 'Chat router is working!', timestamp: new Date().toISOString() });
});

// Generate consistent chat ID from two user IDs
const getChatDocId = (uid1, uid2) => {
  return [uid1, uid2].sort().join('_');
};

// POST /chat/get-or-create-chat - Get existing chat or create new one
router.post('/get-or-create-chat', async (req, res) => {
  try {
    const { uid1, uid2 } = req.body;
    
    // Validation
    if (!uid1 || !isValidUid(uid1)) {
      return res.status(400).json({ error: 'Valid uid1 is required' });
    }
    if (!uid2 || !isValidUid(uid2)) {
      return res.status(400).json({ error: 'Valid uid2 is required' });
    }
    if (uid1 === uid2) {
      return res.status(400).json({ error: 'Cannot create chat with yourself' });
    }
    
    // Use deterministic chat ID to avoid duplicates
    const chatId = getChatDocId(uid1, uid2);
    const chatRef = db.collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    
    if (chatDoc.exists) {
      const chatData = chatDoc.data();
      return res.json({ 
        chatId, 
        isNew: false,
        lastMessage: chatData.lastMessage || null,
        unreadCount: chatData.unreadCount?.[uid1] || 0
      });
    }
    
    // Create new chat
    const newChatData = {
      participants: [uid1, uid2].sort(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: null,
      lastMessageAt: null,
      unreadCount: { [uid1]: 0, [uid2]: 0 }
    };
    
    await chatRef.set(newChatData);
    res.status(201).json({ chatId, isNew: true });
  } catch (err) {
    console.error('Error getting/creating chat:', err);
    res.status(500).json({ error: 'Failed to get or create chat' });
  }
});

// GET /chat/list/:uid - Get all chats for a user
router.get('/list/:uid', authenticateUser, async (req, res) => {
  try {
    const { uid } = req.params;
    const { limit = 20 } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const parsedLimit = Math.min(parseIntSafe(limit, 20), 50);
    
    // Fetch chats without ordering first (to avoid index requirement)
    const chatsSnap = await db.collection('chats')
      .where('participants', 'array-contains', uid)
      .limit(parsedLimit * 2) // Get more to compensate for client-side sorting
      .get();
    
    if (chatsSnap.empty) {
      return res.json([]);
    }
    
    // Collect all participant IDs
    const participantIds = new Set();
    chatsSnap.docs.forEach(doc => {
      const data = doc.data();
      data.participants.forEach(p => {
        if (p !== uid) participantIds.add(p);
      });
    });
    
    // Batch fetch user details
    const userMap = await batchGetDocsAsMap('users', [...participantIds]);
    
    // Map and sort on server side
    let chats = chatsSnap.docs.map(doc => {
      const data = doc.data();
      const otherUserId = data.participants.find(p => p !== uid);
      const otherUser = userMap[otherUserId] || {};
      
      return {
        chatId: doc.id,
        otherUserId,
        otherUserName: otherUser.name || 'Unknown',
        otherUserAvatar: otherUser.avatar || '',
        lastMessage: data.lastMessage || null,
        lastMessageAt: data.lastMessageAt ? data.lastMessageAt.toMillis() : 0,
        unreadCount: data.unreadCount?.[uid] || 0
      };
    });
    
    // Sort by lastMessageAt descending
    chats.sort((a, b) => b.lastMessageAt - a.lastMessageAt);
    
    // Limit results
    chats = chats.slice(0, parsedLimit);
    
    res.json(chats);
  } catch (err) {
    console.error('Error listing chats:', err);
    res.status(500).json({ error: 'Failed to list chats' });
  }
});

// GET /chat/messages/:chatId - Get messages for a chat
router.get('/messages/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { limit = 50, before } = req.query;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    
    const parsedLimit = Math.min(parseIntSafe(limit, 50), 100);
    
    // Check if chat exists
    const chatRef = db.collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      // Check if this is a group chat that exists but doesn't have a chat document
      const groupDoc = await db.collection('groups').doc(chatId).get();
      if (groupDoc.exists) {
        const groupData = groupDoc.data();
        await chatRef.set({
          participants: groupData.members || [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: null,
          lastMessageAt: null,
          isGroupChat: true,
          groupId: chatId,
          unreadCount: groupData.members ? 
            groupData.members.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {}) : {}
        });
      } else {
        return res.status(404).json({ error: 'Chat not found' });
      }
    }
    
    let query = chatRef.collection('messages')
      .orderBy('createdAt', 'desc')
      .limit(parsedLimit);
    
    // Pagination: get messages before a certain timestamp
    if (before) {
      const beforeDate = new Date(before);
      if (!isNaN(beforeDate.getTime())) {
        query = query.where('createdAt', '<', admin.firestore.Timestamp.fromDate(beforeDate));
      }
    }
    
    const messagesSnap = await query.get();
    
    const messages = messagesSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        senderId: data.senderId,
        text: data.text,
        createdAt: data.createdAt,
        type: data.type || 'text',
        imageUrl: data.imageUrl || null,
        read: data.read || false
      };
    }).reverse(); // Reverse to get chronological order
    
    res.json({
      messages,
      hasMore: messages.length === parsedLimit
    });
  } catch (err) {
    console.error('Error fetching messages:', err);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// POST /chat/send - Send a message (REST fallback, prefer Socket.IO)
router.post('/send', async (req, res) => {
  try {
    const { chatId, senderId, text, type = 'text', imageUrl } = req.body;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!senderId || !isValidUid(senderId)) {
      return res.status(400).json({ error: 'Valid senderId is required' });
    }
    if (!text || !isValidLength(text, 1, 2000)) {
      return res.status(400).json({ error: 'Message text is required (max 2000 characters)' });
    }
    
    const chatRef = db.collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      // Check if this is a group chat by checking if the chatId exists as a group
      const groupDoc = await db.collection('groups').doc(chatId).get();
      const isGroupChat = groupDoc.exists;
      
      if (isGroupChat) {
        const groupData = groupDoc.data();
        await chatRef.set({
          participants: groupData.members || [senderId],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: null,
          lastMessageAt: null,
          isGroupChat: true,
          groupId: chatId,
          unreadCount: groupData.members ? 
            groupData.members.reduce((acc, uid) => ({ ...acc, [uid]: 0 }), {}) : 
            { [senderId]: 0 }
        });
      } else {
        // For personal chats
        await chatRef.set({
          participants: [senderId],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastMessage: null,
          lastMessageAt: null,
          isGroupChat: false,
          unreadCount: { [senderId]: 0 }
        });
      }
    }
    
    const updatedChatDoc = await chatRef.get();
    const chatData = updatedChatDoc.data();
    
    if (!chatData.participants.includes(senderId)) {
      // Add sender to participants if not already included
      await chatRef.update({
        participants: admin.firestore.FieldValue.arrayUnion(senderId),
        [`unreadCount.${senderId}`]: 0
      });
    }
    
    const messageData = {
      senderId,
      text: sanitizeHtml(text),
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    };
    
    if (type === 'image' && imageUrl) {
      messageData.imageUrl = imageUrl;
    }
    
    // Add message and update chat in transaction
    const messageRef = await db.runTransaction(async (transaction) => {
      const msgRef = chatRef.collection('messages').doc();
      transaction.set(msgRef, messageData);
      
      // Update last message info
      transaction.update(chatRef, {
        lastMessage: text.substring(0, 100),
        lastMessageAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return msgRef;
    });
    
    res.status(201).json({ 
      success: true, 
      messageId: messageRef.id,
      message: { id: messageRef.id, ...messageData }
    });
  } catch (err) {
    console.error('Error sending message:', err);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// POST /chat/mark-read - Mark messages as read
router.post('/mark-read', async (req, res) => {
  try {
    const { chatId, userId } = req.body;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const chatRef = db.collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    if (!chatDoc.data().participants.includes(userId)) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }
    
    // Reset unread count for user
    await chatRef.update({
      [`unreadCount.${userId}`]: 0
    });
    
    res.json({ success: true });
  } catch (err) {
    console.error('Error marking as read:', err);
    res.status(500).json({ error: 'Failed to mark as read' });
  }
});

// DELETE /chat/:chatId - Delete a chat (soft delete or full delete)
router.delete('/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { userId } = req.body;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const chatRef = db.collection('chats').doc(chatId);
    const chatDoc = await chatRef.get();
    
    if (!chatDoc.exists) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    
    if (!chatDoc.data().participants.includes(userId)) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }
    
    // Delete messages in batches
    const messagesSnap = await chatRef.collection('messages').limit(500).get();
    if (!messagesSnap.empty) {
      const batch = db.batch();
      messagesSnap.docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }
    
    // Delete chat document
    await chatRef.delete();
    
    res.json({ success: true, message: 'Chat deleted' });
  } catch (err) {
    console.error('Error deleting chat:', err);
    res.status(500).json({ error: 'Failed to delete chat' });
  }
});

// DELETE /chat/message/:messageId - Delete a specific message
router.delete('/message/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { chatId, userId } = req.body;
    
    if (!messageId || !isValidLength(messageId, 1, 256)) {
      return res.status(400).json({ error: 'Valid messageId is required' });
    }
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();
    
    if (!messageDoc.exists) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    const messageData = messageDoc.data();
    if (messageData.senderId !== userId) {
      return res.status(403).json({ error: 'Can only delete your own messages' });
    }
    
    // Mark message as deleted instead of hard delete
    await messageRef.update({
      deleted: true,
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedBy: userId,
      originalText: messageData.text, // Keep original for moderation if needed
      text: '[Message deleted]'
    });
    
    res.json({ success: true, message: 'Message deleted successfully' });
  } catch (err) {
    console.error('Error deleting message:', err);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

// PUT /chat/message/:messageId - Edit a message
router.put('/message/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;
    const { chatId, userId, newText } = req.body;
    
    if (!messageId || !isValidLength(messageId, 1, 256)) {
      return res.status(400).json({ error: 'Valid messageId is required' });
    }
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    if (!newText || !isValidLength(newText, 1, 2000)) {
      return res.status(400).json({ error: 'Valid message text is required (max 2000 characters)' });
    }
    
    const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();
    
    if (!messageDoc.exists) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    const messageData = messageDoc.data();
    if (messageData.senderId !== userId) {
      return res.status(403).json({ error: 'Can only edit your own messages' });
    }
    
    if (messageData.deleted) {
      return res.status(400).json({ error: 'Cannot edit deleted messages' });
    }
    
    // Check if message is not too old (e.g., 24 hours)
    const messageAge = Date.now() - (messageData.createdAt?.toDate?.()?.getTime() || 0);
    const maxEditAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    
    if (messageAge > maxEditAge) {
      return res.status(400).json({ error: 'Message is too old to edit' });
    }
    
    // Update message with edit history
    await messageRef.update({
      text: sanitizeHtml(newText),
      edited: true,
      editedAt: admin.firestore.FieldValue.serverTimestamp(),
      editHistory: admin.firestore.FieldValue.arrayUnion({
        previousText: messageData.text,
        editedAt: admin.firestore.FieldValue.serverTimestamp()
      })
    });
    
    res.json({ success: true, message: 'Message updated successfully' });
  } catch (err) {
    console.error('Error editing message:', err);
    res.status(500).json({ error: 'Failed to edit message' });
  }
});

// POST /chat/reaction - Add reaction to message
router.post('/reaction', async (req, res) => {
  try {
    const { chatId, messageId, userId, reaction } = req.body;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    if (!messageId || !isValidLength(messageId, 1, 256)) {
      return res.status(400).json({ error: 'Valid messageId is required' });
    }
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    if (!reaction || !isValidLength(reaction, 1, 10)) {
      return res.status(400).json({ error: 'Valid reaction is required' });
    }
    
    // Validate emoji reaction (simple validation)
    const validReactions = ['👍', '👎', '❤️', '😂', '😢', '😮', '😡', '👏'];
    if (!validReactions.includes(reaction)) {
      return res.status(400).json({ error: 'Invalid reaction emoji' });
    }
    
    const messageRef = db.collection('chats').doc(chatId).collection('messages').doc(messageId);
    const messageDoc = await messageRef.get();
    
    if (!messageDoc.exists) {
      return res.status(404).json({ error: 'Message not found' });
    }
    
    // Check if user is participant of the chat
    const chatDoc = await db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists || !chatDoc.data().participants.includes(userId)) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }
    
    const messageData = messageDoc.data();
    const reactions = messageData.reactions || {};
    const reactionKey = reaction;
    
    if (reactions[reactionKey]) {
      // Toggle reaction if user already reacted with this emoji
      if (reactions[reactionKey].includes(userId)) {
        reactions[reactionKey] = reactions[reactionKey].filter(uid => uid !== userId);
        if (reactions[reactionKey].length === 0) {
          delete reactions[reactionKey];
        }
      } else {
        reactions[reactionKey].push(userId);
      }
    } else {
      reactions[reactionKey] = [userId];
    }
    
    await messageRef.update({ reactions });
    
    res.json({ success: true, reactions });
  } catch (err) {
    console.error('Error adding reaction:', err);
    res.status(500).json({ error: 'Failed to add reaction' });
  }
});

// GET /chat/:chatId/typing - Get typing users in chat
router.get('/:chatId/typing', async (req, res) => {
  try {
    const { chatId } = req.params;
    
    if (!chatId || !isValidLength(chatId, 1, 256)) {
      return res.status(400).json({ error: 'Valid chatId is required' });
    }
    
    // In a real implementation, you'd track typing status in a faster storage like Redis
    // For now, return empty array as typing is handled via Socket.IO
    res.json({ typingUsers: [] });
  } catch (err) {
    console.error('Error getting typing status:', err);
    res.status(500).json({ error: 'Failed to get typing status' });
  }
});

module.exports = router;

