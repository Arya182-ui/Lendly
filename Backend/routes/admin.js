const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();
const { isValidUid, sanitizeHtml, trimObjectStrings } = require('../utils/validators');
const { TrustScoreManager } = require('../utils/trust-score-manager');
const { CoinsManager } = require('../utils/coins-manager');
const { LendlyQueryOptimizer } = require('../utils/advanced-query-optimizer');
const { globalPaginationManager, extractPaginationParams, formatPaginatedResponse } = require('../utils/advanced-pagination');

const db = admin.firestore();

// --- ADMIN AUTH MIDDLEWARE ---
async function requireAdminAuth(req, res, next) {
  try {
    const { adminUid } = req.body;
    if (!adminUid || !isValidUid(adminUid)) {
      return res.status(401).json({ error: 'Admin authentication required' });
    }
    
    // Check if user is admin
    const adminDoc = await db.collection('admins').doc(adminUid).get();
    if (!adminDoc.exists) {
      return res.status(403).json({ error: 'Admin access denied' });
    }
    
    req.admin = { uid: adminUid, ...adminDoc.data() };
    next();
  } catch (err) {
    console.error('Admin auth error:', err);
    res.status(500).json({ error: 'Admin authentication failed' });
  }
}

// --- GET PENDING VERIFICATIONS WITH ADVANCED OPTIMIZATION ---
router.post('/pending-verifications', requireAdminAuth, async (req, res) => {
  try {
    const { college = null, priority = null } = req.body;
    const paginationParams = extractPaginationParams(req);
    
    // Build optimized filters
    const filters = {};
    if (college) {
      filters.college = college;
    }
    if (priority) {
      filters.priority = priority;
    }

    // Use optimized query with proper indexing
    const result = await LendlyQueryOptimizer.getPendingVerifications({
      college,
      priority,
      limit: paginationParams.pageSize,
      cursor: paginationParams.cursor
    });
    
    // Enrich with user data efficiently
    const enrichedUsers = result.data.map(userData => ({
      uid: userData.id,
      name: userData.name || '',
      email: userData.email || '',
      college: userData.college || '',
      verificationDocument: userData.verificationDocument || '',
      verificationRequestedAt: userData.verificationRequestedAt,
      studentId: userData.studentId || '',
      phone: userData.phone || '',
      priority: userData.priority || 'normal'
    }));

    // Format response with pagination metadata
    const response = formatPaginatedResponse(
      { ...result, items: enrichedUsers },
      '/api/admin/pending-verifications',
      req
    );
    
    res.json(response);
  } catch (err) {
    console.error('Error fetching pending verifications:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch pending verifications',
      details: err.message 
    });
  }
});

// --- APPROVE VERIFICATION ---
router.post('/approve-verification', requireAdminAuth, async (req, res) => {
  try {
    const { uid, adminNotes = '' } = trimObjectStrings(req.body);
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid user UID is required' });
    }
    
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    if (userData.verificationStatus !== 'pending') {
      return res.status(400).json({ error: 'User verification is not pending' });
    }
    
    // Update user verification status
    await userRef.update({
      verificationStatus: 'verified',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: req.admin.uid,
      adminNotes: sanitizeHtml(adminNotes)
    });
    
    // Apply Trust Score update (50 → 70)
    try {
      await TrustScoreManager.onIDVerification(uid);
      console.log(`[ADMIN] Trust score updated to 70 for verified user ${uid}`);
    } catch (trustError) {
      console.error('[ADMIN] Failed to update trust score:', trustError);
      // Don't fail verification if trust score update fails
    }
    
    // Award verification coins
    try {
      await CoinsManager.onIDVerification(uid);
      console.log(`[ADMIN] Awarded 100 coins for verification to user ${uid}`);
    } catch (coinsError) {
      console.error('[ADMIN] Failed to award verification coins:', coinsError);
      // Don't fail verification if coins award fails
    }
    
    // Create notification for user
    await db.collection('notifications').add({
      uid: uid,
      type: 'verification_approved',
      title: '🎉 Verification Approved!',
      message: 'Your student verification has been approved. Your trust score is now 70 and you received 100 Lendly Coins!',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
    
    res.json({ success: true, message: 'User verification approved successfully' });
  } catch (err) {
    console.error('Error approving verification:', err);
    res.status(500).json({ error: 'Failed to approve verification' });
  }
});

// --- REJECT VERIFICATION ---
router.post('/reject-verification', requireAdminAuth, async (req, res) => {
  try {
    const { uid, reason = 'Invalid or insufficient documentation' } = trimObjectStrings(req.body);
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid user UID is required' });
    }
    
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    if (userData.verificationStatus !== 'pending') {
      return res.status(400).json({ error: 'User verification is not pending' });
    }
    
    // Update user verification status
    await userRef.update({
      verificationStatus: 'rejected',
      rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
      rejectedBy: req.admin.uid,
      rejectionReason: sanitizeHtml(reason)
    });
    
    // Create notification for user
    await db.collection('notifications').add({
      uid: uid,
      type: 'verification_rejected',
      title: '❌ Verification Rejected',
      message: `Your verification was rejected: ${reason}. Please re-submit with proper documentation.`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false
    });
    
    res.json({ success: true, message: 'User verification rejected' });
  } catch (err) {
    console.error('Error rejecting verification:', err);
    res.status(500).json({ error: 'Failed to reject verification' });
  }
});

// --- OPTIMIZED ADMIN STATS WITH ADVANCED QUERYING ---
router.post('/stats', requireAdminAuth, async (req, res) => {
  try {
    const { college = null, dateRange = null } = req.body;
    
    console.log('[ADMIN] Advanced stats request:', { adminUid: req.admin.uid, college, dateRange });
    
    // Use Promise.allSettled for better error handling
    const statsPromises = [
      // Total users with college filter
      college 
        ? db.collection('users').where('college', '==', college).count().get()
        : db.collection('users').count().get(),
      
      // Verified users with composite index optimization
      college
        ? db.collection('users')
            .where('college', '==', college)
            .where('verificationStatus', '==', 'verified')
            .count().get()
        : db.collection('users').where('verificationStatus', '==', 'verified').count().get(),
      
      // Pending verifications with optimized query
      college
        ? db.collection('users')
            .where('college', '==', college)
            .where('verificationStatus', '==', 'pending')
            .count().get()
        : db.collection('users').where('verificationStatus', '==', 'pending').count().get(),
      
      // Groups count with college filter
      college
        ? db.collection('groups').where('college', '==', college).count().get()
        : db.collection('groups').count().get(),
      
      // Items count with college filter
      college
        ? db.collection('items').where('college', '==', college).count().get()
        : db.collection('items').count().get()
    ];
    
    const results = await Promise.allSettled(statsPromises);
    
    // Process results with error handling
    const processResult = (result, defaultValue = 0) => {
      if (result.status === 'fulfilled') {
        return result.value.data().count;
      } else {
        console.error('Stats query failed:', result.reason);
        return defaultValue;
      }
    };
    
    const [
      totalUsersResult,
      verifiedUsersResult,
      pendingUsersResult,
      totalGroupsResult,
      totalItemsResult
    ] = results;
    
    const totalUsers = processResult(totalUsersResult);
    const verifiedUsers = processResult(verifiedUsersResult);
    const pendingUsers = processResult(pendingUsersResult);
    const totalGroups = processResult(totalGroupsResult);
    const totalItems = processResult(totalItemsResult);
    
    const stats = {
      totalUsers,
      verifiedUsers,
      pendingUsers,
      totalGroups,
      totalItems,
      verificationRate: totalUsers > 0 ? ((verifiedUsers / totalUsers) * 100).toFixed(1) : 0,
      
      // Additional insights
      insights: {
        college: college || 'all',
        pendingVerificationPercentage: totalUsers > 0 ? ((pendingUsers / totalUsers) * 100).toFixed(1) : 0,
        averageItemsPerUser: totalUsers > 0 ? (totalItems / totalUsers).toFixed(1) : 0,
        averageGroupsPerUser: totalUsers > 0 ? (totalGroups / totalUsers).toFixed(2) : 0
      },
      
      performance: {
        queryTime: Date.now(),
        parallelQueries: statsPromises.length,
        successfulQueries: results.filter(r => r.status === 'fulfilled').length
      }
    };
    
    console.log('[ADMIN] Enhanced stats generated:', stats);
    
    res.json({ 
      success: true, 
      stats,
      generatedAt: new Date().toISOString(),
      filters: { college, dateRange }
    });
    
  } catch (err) {
    console.error('Error fetching enhanced admin stats:', err);
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch statistics',
      details: err.message 
    });
  }
});

// --- CHECK ADMIN STATUS ---
router.post('/check-admin', async (req, res) => {
  try {
    const { uid } = req.body;
    
    if (!uid || !isValidUid(uid)) {
      return res.status(400).json({ error: 'Valid UID is required' });
    }
    
    const adminDoc = await db.collection('admins').doc(uid).get();
    const isAdmin = adminDoc.exists;
    
    res.json({ 
      success: true, 
      isAdmin,
      adminData: isAdmin ? adminDoc.data() : null 
    });
  } catch (err) {
    console.error('Error checking admin status:', err);
    res.status(500).json({ error: 'Failed to check admin status' });
  }
});

module.exports = router;
