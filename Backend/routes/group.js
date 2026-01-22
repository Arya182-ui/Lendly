const express = require('express');
const admin = require('firebase-admin');
const { sanitizeHtml, trimObjectStrings, isValidLength, isValidUid } = require('../utils/validators');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { validateBody, validateQuery, validateParams } = require('../middleware/validation');
const groupSchemas = require('../validation/groups.schemas');
const { authenticateUser } = require('../middleware/auth');
const { LendlyQueryOptimizer } = require('../utils/advanced-query-optimizer');
const { globalPaginationManager, extractPaginationParams, formatPaginatedResponse } = require('../utils/advanced-pagination');

const router = express.Router();
const db = admin.firestore();

// Constants for group management
const GROUP_CONSTANTS = {
  MAX_MEMBERS: 100,
  MAX_GROUPS_PER_USER: 20,
  MAX_NAME_LENGTH: 50,
  MAX_DESCRIPTION_LENGTH: 200,
  ALLOWED_GROUP_TYPES: ['study', 'hobby', 'sports', 'tech', 'social', 'other']
};

const ALLOWED_GROUP_TYPES = GROUP_CONSTANTS.ALLOWED_GROUP_TYPES;

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

// Helper function to check user's group limit
async function checkUserGroupLimit(uid) {
  const userGroupsCount = await db.collection('groups')
    .where('members', 'array-contains', uid)
    .count()
    .get();
  
  return userGroupsCount.data().count >= GROUP_CONSTANTS.MAX_GROUPS_PER_USER;
}

// Create a new group with enhanced validation and features
router.post('/create', async (req, res) => {
  try {
    const { name, type, description, createdBy, isPublic = true, maxMembers = 50 } = trimObjectStrings(req.body);
    
    console.log('Group creation request:', { name, type, description, createdBy, isPublic, maxMembers });
    
    // Enhanced validation
    const errors = [];
    if (!name || !isValidLength(name, 2, GROUP_CONSTANTS.MAX_NAME_LENGTH)) {
      errors.push(`Name is required (2-${GROUP_CONSTANTS.MAX_NAME_LENGTH} characters)`);
    }
    if (!type || !ALLOWED_GROUP_TYPES.includes(type.toLowerCase())) {
      errors.push(`Type must be one of: ${ALLOWED_GROUP_TYPES.join(', ')}`);
    }
    if (!description || !isValidLength(description, 5, GROUP_CONSTANTS.MAX_DESCRIPTION_LENGTH)) {
      errors.push(`Description is required (5-${GROUP_CONSTANTS.MAX_DESCRIPTION_LENGTH} characters)`);
    }
    if (!createdBy || !isValidUid(createdBy)) {
      errors.push('Valid createdBy UID is required');
    }
    if (maxMembers && (maxMembers < 2 || maxMembers > GROUP_CONSTANTS.MAX_MEMBERS)) {
      errors.push(`Max members must be between 2 and ${GROUP_CONSTANTS.MAX_MEMBERS}`);
    }
    
    if (errors.length > 0) {
      console.log('Validation errors:', errors);
      return res.status(400).json({ error: 'Validation failed', details: errors });
    }
    
    // Check if user has reached group creation limit
    const hasReachedLimit = await checkUserGroupLimit(createdBy);
    if (hasReachedLimit) {
      return res.status(400).json({ 
        error: `Cannot create more than ${GROUP_CONSTANTS.MAX_GROUPS_PER_USER} groups` 
      });
    }
    
    // Verify creator exists
    console.log('Checking if creator exists:', createdBy);
    const creatorDoc = await db.collection('users').doc(createdBy).get();
    if (!creatorDoc.exists) {
      console.log('Creator user not found:', createdBy);
      return res.status(400).json({ error: 'Creator user not found' });
    }
    
    // Check for duplicate group names by the same user
    const existingGroupsSnap = await db.collection('groups')
      .where('createdBy', '==', createdBy)
      .where('name', '==', sanitizeHtml(name))
      .limit(1)
      .get();
    
    if (!existingGroupsSnap.empty) {
      return res.status(400).json({ error: 'You already have a group with this name' });
    }
    
    const groupData = {
      name: sanitizeHtml(name),
      type: type.toLowerCase(),
      description: sanitizeHtml(description),
      createdBy,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      members: [createdBy],
      admins: [createdBy], // Creator is automatically an admin
      isPublic: isPublic === true || isPublic === 'true',
      memberCount: 1,
      maxMembers: Math.min(maxMembers || 50, GROUP_CONSTANTS.MAX_MEMBERS),
      status: 'active',
      tags: [], // For future categorization
      rules: '', // Group rules/guidelines
      lastActivity: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const groupRef = await db.collection('groups').add(groupData);
    
    // Create corresponding chat document for group messaging
    const chatRef = db.collection('chats').doc(groupRef.id);
    await chatRef.set({
      participants: [createdBy],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: null,
      lastMessageAt: null,
      isGroupChat: true,
      groupId: groupRef.id,
      groupName: sanitizeHtml(name),
      unreadCount: { [createdBy]: 0 }
    });
    
    // Get the created group with resolved timestamp
    const createdGroup = await groupRef.get();
    const responseData = {
      id: groupRef.id,
      ...createdGroup.data(),
      createdAt: createdGroup.data().createdAt?.toDate?.()?.toISOString() || new Date().toISOString()
    };
    
    console.log('Group created successfully:', responseData);
    return res.status(201).json({
      success: true,
      message: 'Group created successfully',
      group: responseData
    });
  } catch (err) {
    console.error('Error creating group:', err);
    return res.status(500).json({ error: 'Failed to create group' });
  }
});

// Join a group with enhanced validation and notifications
router.post('/join', authenticateUser, validateBody(groupSchemas.joinGroup), async (req, res) => {
  try {
    const { groupId, userId } = req.body;
    
    const groupRef = db.collection('groups').doc(groupId);
    const groupDoc = await groupRef.get();
    
    if (!groupDoc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const groupData = groupDoc.data();
    
    // Enhanced validation checks
    if (groupData.status === 'inactive') {
      return res.status(400).json({ error: 'Group is no longer active' });
    }
    
    if (groupData.members?.includes(userId)) {
      return res.status(400).json({ error: 'Already a member of this group' });
    }
    
    // Check if group is at capacity
    const currentMemberCount = groupData.memberCount || groupData.members?.length || 0;
    const maxMembers = groupData.maxMembers || GROUP_CONSTANTS.MAX_MEMBERS;
    
    if (currentMemberCount >= maxMembers) {
      return res.status(400).json({ error: 'Group is full' });
    }
    
    // Check if user has reached their group limit
    const hasReachedLimit = await checkUserGroupLimit(userId);
    if (hasReachedLimit) {
      return res.status(400).json({ 
        error: `Cannot join more than ${GROUP_CONSTANTS.MAX_GROUPS_PER_USER} groups` 
      });
    }
    
    // Verify user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Use transaction for consistency
    await db.runTransaction(async (transaction) => {
      // Update group
      transaction.update(groupRef, {
        members: admin.firestore.FieldValue.arrayUnion(userId),
        memberCount: admin.firestore.FieldValue.increment(1),
        lastActivity: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Add user to group chat participants
      const chatRef = db.collection('chats').doc(groupId);
      transaction.update(chatRef, {
        participants: admin.firestore.FieldValue.arrayUnion(userId),
        [`unreadCount.${userId}`]: 0
      });
    });
    
    // Create notifications for group admins
    const userData = userDoc.data();
    const adminUids = groupData.admins || [groupData.createdBy];
    
    const notificationPromises = adminUids
      .filter(adminUid => adminUid !== userId) // Don't notify the user themselves
      .map(adminUid => 
        createNotification(
          adminUid,
          'group_member_joined',
          'New Group Member',
          `${userData?.name || 'Someone'} joined your group "${groupData.name}"`,
          { 
            groupId, 
            groupName: groupData.name, 
            newMemberUid: userId, 
            newMemberName: userData?.name || 'Unknown' 
          }
        )
      );
    
    await Promise.all(notificationPromises);
    
    // Welcome notification for the new member
    await createNotification(
      userId,
      'group_joined',
      'Welcome to the Group!',
      `You've successfully joined "${groupData.name}". Start connecting with your group members!`,
      { groupId, groupName: groupData.name }
    );
    
    return res.json({ 
      success: true, 
      message: `Successfully joined "${groupData.name}"`,
      group: {
        id: groupId,
        name: groupData.name,
        memberCount: currentMemberCount + 1
      }
    });
  } catch (err) {
    console.error('Error joining group:', err);
    return res.status(500).json({ error: 'Failed to join group' });
  }
});

// Join a group with groupId as URL parameter (alternative endpoint)
router.post('/:groupId/join', authenticateUser, async (req, res) => {
  try {
    const groupId = req.params.groupId;
    const userId = req.uid;
    
    if (!groupId || !isValidLength(groupId, 1, 128)) {
      return res.status(400).json({ error: 'Valid groupId is required' });
    }
    
    const groupRef = db.collection('groups').doc(groupId);
    const groupDoc = await groupRef.get();
    
    if (!groupDoc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const groupData = groupDoc.data();
    
    // Enhanced validation checks
    if (groupData.status === 'inactive') {
      return res.status(400).json({ error: 'Group is no longer active' });
    }
    
    if (groupData.members?.includes(userId)) {
      return res.status(400).json({ error: 'Already a member of this group' });
    }
    
    // Check if group is at capacity
    const currentMemberCount = groupData.memberCount || groupData.members?.length || 0;
    const maxMembers = groupData.maxMembers || GROUP_CONSTANTS.MAX_MEMBERS;
    
    if (currentMemberCount >= maxMembers) {
      return res.status(400).json({ error: 'Group is full' });
    }
    
    // Check if user has reached their group limit
    const hasReachedLimit = await checkUserGroupLimit(userId);
    if (hasReachedLimit) {
      return res.status(400).json({ 
        error: `Cannot join more than ${GROUP_CONSTANTS.MAX_GROUPS_PER_USER} groups` 
      });
    }
    
    // Get user data for notifications
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    // Add user to group members and update member count
    await groupRef.update({
      members: admin.firestore.FieldValue.arrayUnion(userId),
      memberCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Notify group members about new member
    if (groupData.members?.length > 0) {
      const notifications = groupData.members.map(memberId => 
        createNotification(
          memberId,
          'group_member_joined',
          'New Group Member',
          `${userData?.name || 'Someone'} joined your group "${groupData.name}"`,
          { groupId, groupName: groupData.name }
        )
      );
      await Promise.all(notifications);
    }
    
    // Notify the user who joined
    await createNotification(
      userId,
      'group_joined',
      'Welcome to the Group!',
      `You've successfully joined "${groupData.name}". Start connecting with your group members!`,
      { groupId, groupName: groupData.name }
    );
    
    console.log('User joined group successfully:', { userId, groupId });
    
    return res.status(200).json({
      success: true,
      message: `Successfully joined "${groupData.name}"`,
      group: {
        id: groupId,
        name: groupData.name,
        memberCount: currentMemberCount + 1
      }
    });
  } catch (err) {
    console.error('Error joining group:', err);
    return res.status(500).json({ error: 'Failed to join group' });
  }
});

// Leave a group
router.post('/leave', async (req, res) => {
  try {
    const { groupId, uid } = req.body;
    
    if (!groupId || !isValidLength(groupId, 1, 128)) {
      return res.status(400).json({ error: 'Valid groupId is required' });
    }
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const groupRef = db.collection('groups').doc(groupId);
    const groupDoc = await groupRef.get();
    
    if (!groupDoc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const groupData = groupDoc.data();
    if (!groupData.members?.includes(uid)) {
      return res.status(400).json({ error: 'Not a member of this group' });
    }
    
    // Cannot leave if you're the only member and creator
    if (groupData.createdBy === uid && groupData.members.length === 1) {
      return res.status(400).json({ error: 'Cannot leave group. Delete the group instead.' });
    }
    
    await db.runTransaction(async (transaction) => {
      transaction.update(groupRef, {
        members: admin.firestore.FieldValue.arrayRemove(uid),
        memberCount: admin.firestore.FieldValue.increment(-1)
      });
      
      // Remove user from group chat participants
      const chatRef = db.collection('chats').doc(groupId);
      transaction.update(chatRef, {
        participants: admin.firestore.FieldValue.arrayRemove(uid)
      });
    });
    
    return res.json({ success: true, message: 'Successfully left the group' });
  } catch (err) {
    console.error('Error leaving group:', err);
    return res.status(500).json({ error: 'Failed to leave group' });
  }
});

// Get discoverable groups (public groups not joined by user)
// GET /groups/public - Public groups for home screen (no auth filter, just basic listing)
router.get('/public', authenticateUser, async (req, res) => {
  try {
    const { uid, limit = 10 } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const parsedLimit = Math.min(parseInt(limit) || 10, 20);
    
    // Fetch public groups without type filter
    const snapshot = await db.collection('groups')
      .orderBy('createdAt', 'desc')
      .limit(parsedLimit * 2)
      .get();
    
    let groups = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Sort by member count
    groups.sort((a, b) => (b.memberCount || 0) - (a.memberCount || 0));
    
    // Filter out groups user has already joined
    groups = groups.filter(g => !g.members?.includes(uid));
    
    // Limit final results
    groups = groups.slice(0, parsedLimit);
    
    // Add member preview
    const memberIds = [...new Set(groups.flatMap(g => (g.members || []).slice(0, 3)))];
    const memberMap = await batchGetDocsAsMap('users', memberIds);
    
    const enrichedGroups = groups.map(g => ({
      id: g.id,
      name: g.name,
      type: g.type,
      description: g.description,
      memberCount: g.memberCount || g.members?.length || 0,
      createdAt: g.createdAt,
      memberPreview: (g.members || []).slice(0, 3).map(mid => ({
        id: mid,
        name: memberMap[mid]?.name || '',
        avatar: memberMap[mid]?.avatar || ''
      }))
    }));
    
    res.json(enrichedGroups);
  } catch (err) {
    console.error('Error fetching public groups:', err);
    res.status(500).json({ error: 'Failed to fetch public groups' });
  }
});

router.get('/discover', authenticateUser, validateQuery(groupSchemas.discoverGroups), async (req, res) => {
  try {
    const { uid, limit, q, type } = req.query;
    
    console.log('Discover groups request:', { uid, limit, q, type });
    
    let query = db.collection('groups')
      .orderBy('createdAt', 'desc')
      .limit(limit * 2); // Fetch extra to compensate for filtering
    
    // Filter by type if provided
    if (type) {
      query = db.collection('groups')
        .where('type', '==', type.toLowerCase())
        .orderBy('createdAt', 'desc')
        .limit(limit * 2);
    }
    
    const snapshot = await query.get();
    let groups = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Sort by member count in JavaScript instead of using Firestore composite index
    groups.sort((a, b) => (b.memberCount || 0) - (a.memberCount || 0));
    
    // Filter out groups user has already joined
    groups = groups.filter(g => !g.members?.includes(uid));
    
    // TODO: Add location-based filtering for nearby groups
    // Currently showing all public groups globally
    // Should filter by college/proximity in future versions
    
    // Search filter (case-insensitive contains)
    if (q && typeof q === 'string' && q.trim().length > 0) {
      const searchTerm = q.toLowerCase().trim();
      groups = groups.filter(g => 
        g.name?.toLowerCase().includes(searchTerm) ||
        g.description?.toLowerCase().includes(searchTerm)
      );
    }
    
    // Limit final results
    groups = groups.slice(0, limit);
    
    // Add member preview (batch fetch first 3 members)
    const memberIds = [...new Set(groups.flatMap(g => (g.members || []).slice(0, 3)))];
    const memberMap = await batchGetDocsAsMap('users', memberIds);
    
    const enrichedGroups = groups.map(g => ({
      id: g.id,
      name: g.name,
      type: g.type,
      description: g.description,
      memberCount: g.memberCount || g.members?.length || 0,
      createdAt: g.createdAt,
      memberPreview: (g.members || []).slice(0, 3).map(mid => ({
        id: mid,
        name: memberMap[mid]?.name || '',
        avatar: memberMap[mid]?.avatar || ''
      }))
    }));
    
    return res.json(enrichedGroups);
  } catch (err) {
    console.error('Error fetching discover groups:', err);
    return res.status(500).json({ error: 'Failed to fetch groups' });
  }
});

// Get groups where user is a member (My Groups)
router.get('/my', authenticateUser, validateQuery(groupSchemas.myGroups), async (req, res) => {
  try {
    const { uid } = req.query;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const snapshot = await db.collection('groups')
      .where('members', 'array-contains', uid)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();
    
    const groups = snapshot.docs.map(doc => {
      const d = doc.data();
      const groupData = {
        id: doc.id,
        name: d.name,
        type: d.type,
        description: d.description,
        members: d.members || [],
        memberCount: d.memberCount || d.members?.length || 0,
        isOwner: d.createdBy === uid,
        createdAt: d.createdAt
      };
      console.log('My Groups - Group data:', JSON.stringify({
        id: groupData.id,
        name: groupData.name,
        membersLength: groupData.members.length,
        memberCount: groupData.memberCount
      }));
      return groupData;
    });
    
    return res.json(groups);
  } catch (err) {
    console.error('Error fetching my groups:', err);
    return res.status(500).json({ error: 'Failed to fetch your groups' });
  }
});

// Update group (only by owner)
router.post('/update', async (req, res) => {
  try {
    const { groupId, uid, name, description, isPublic } = trimObjectStrings(req.body);
    
    if (!groupId || !isValidLength(groupId, 1, 128)) {
      return res.status(400).json({ error: 'Valid groupId is required' });
    }
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const groupRef = db.collection('groups').doc(groupId);
    const doc = await groupRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const groupData = doc.data();
    if (groupData.createdBy !== uid) {
      return res.status(403).json({ error: 'Only the group owner can update the group' });
    }
    
    // Build update object
    const updates = { updatedAt: admin.firestore.FieldValue.serverTimestamp() };
    
    if (name !== undefined) {
      if (!isValidLength(name, 2, 30)) {
        return res.status(400).json({ error: 'Name must be 2-30 characters' });
      }
      updates.name = sanitizeHtml(name);
    }
    
    if (description !== undefined) {
      if (!isValidLength(description, 5, 120)) {
        return res.status(400).json({ error: 'Description must be 5-120 characters' });
      }
      updates.description = sanitizeHtml(description);
    }
    
    if (isPublic !== undefined) {
      updates.isPublic = isPublic === true || isPublic === 'true';
    }
    
    await groupRef.update(updates);
    return res.json({ success: true, message: 'Group updated successfully' });
  } catch (err) {
    console.error('Error updating group:', err);
    return res.status(500).json({ error: 'Failed to update group' });
  }
});

// Get group by id with member details
router.get('/:id', authenticateUser, async (req, res) => {
  try {
    const { id } = req.params;
    const { uid } = req.query;
    
    if (!id || !isValidLength(id, 1, 128)) {
      return res.status(400).json({ error: 'Invalid group ID' });
    }
    
    const doc = await db.collection('groups').doc(id).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const groupData = doc.data();
    
    // Fetch member details (batch)
    const memberIds = groupData.members || [];
    const memberMap = await batchGetDocsAsMap('users', memberIds);
    
    const members = memberIds.map(mid => ({
      id: mid,
      name: memberMap[mid]?.name || 'Unknown',
      avatar: memberMap[mid]?.avatar || '',
      college: memberMap[mid]?.college || ''
    }));
    
    return res.json({
      id: doc.id,
      name: groupData.name,
      type: groupData.type,
      description: groupData.description,
      createdBy: groupData.createdBy,
      createdAt: groupData.createdAt,
      isPublic: groupData.isPublic !== false,
      memberCount: memberIds.length,
      members,
      isOwner: uid ? groupData.createdBy === uid : false,
      isMember: uid ? memberIds.includes(uid) : false
    });
  } catch (err) {
    console.error('Error fetching group by id:', err);
    return res.status(500).json({ error: 'Failed to fetch group' });
  }
});

// Delete a group (only by owner)
router.post('/delete', async (req, res) => {
  try {
    const { groupId, uid } = req.body;
    
    if (!groupId || !isValidLength(groupId, 1, 128)) {
      return res.status(400).json({ error: 'Valid groupId is required' });
    }
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const groupRef = db.collection('groups').doc(groupId);
    const doc = await groupRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    if (doc.data().createdBy !== uid) {
      return res.status(403).json({ error: 'Only the group owner can delete the group' });
    }
    
    // Delete associated chat messages (if exists)
    try {
      const messagesSnap = await db.collection('groups').doc(groupId)
        .collection('messages').limit(500).get();
      
      if (!messagesSnap.empty) {
        const batch = db.batch();
        messagesSnap.docs.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
      }
    } catch (msgErr) {
      console.error('Error deleting group messages:', msgErr);
    }
    
    await groupRef.delete();
    return res.json({ success: true, message: 'Group deleted successfully' });
  } catch (err) {
    console.error('Error deleting group:', err);
    return res.status(500).json({ error: 'Failed to delete group' });
  }
});

// Get group members
router.get('/:id/members', async (req, res) => {
  try {
    const { id } = req.params;
    const { limit = 20 } = req.query;
    
    if (!id || !isValidLength(id, 1, 128)) {
      return res.status(400).json({ error: 'Invalid group ID' });
    }
    
    const doc = await db.collection('groups').doc(id).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Group not found' });
    }
    
    const memberIds = (doc.data().members || []).slice(0, parseIntSafe(limit, 20));
    const memberMap = await batchGetDocsAsMap('users', memberIds);
    
    const members = memberIds.map(mid => ({
      id: mid,
      name: memberMap[mid]?.name || 'Unknown',
      avatar: memberMap[mid]?.avatar || '',
      college: memberMap[mid]?.college || '',
      isOwner: mid === doc.data().createdBy
    }));
    
    return res.json(members);
  } catch (err) {
    console.error('Error fetching group members:', err);
    return res.status(500).json({ error: 'Failed to fetch members' });
  }
});

module.exports = router;
