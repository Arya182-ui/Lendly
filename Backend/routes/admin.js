const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();
const { isValidUid, sanitizeHtml, trimObjectStrings } = require('../utils/validators');
const { TrustScoreManager } = require('../utils/trust-score-manager');
const { CoinsManager } = require('../utils/coins-manager');

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

// --- GET PENDING VERIFICATIONS ---
router.post('/pending-verifications', requireAdminAuth, async (req, res) => {
  try {
    const { limit = 20, offset = 0 } = req.body;
    
    const snapshot = await db.collection('users')
      .where('verificationStatus', '==', 'pending')
      .orderBy('verificationRequestedAt', 'desc')
      .limit(Math.min(parseInt(limit), 50))
      .offset(parseInt(offset))
      .get();
    
    const pendingUsers = snapshot.docs.map(doc => {
      const data = doc.data();
      return {
        uid: doc.id,
        name: data.name || '',
        email: data.email || '',
        college: data.college || '',
        verificationDocument: data.verificationDocument || '',
        verificationRequestedAt: data.verificationRequestedAt,
        studentId: data.studentId || '',
        phone: data.phone || ''
      };
    });
    
    res.json({ 
      success: true, 
      users: pendingUsers,
      total: pendingUsers.length 
    });
  } catch (err) {
    console.error('Error fetching pending verifications:', err);
    res.status(500).json({ error: 'Failed to fetch pending verifications' });
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

// --- ADMIN STATS ---
router.post('/stats', requireAdminAuth, async (req, res) => {
  try {
    // Run multiple queries in parallel
    const [
      totalUsersSnapshot,
      verifiedUsersSnapshot,
      pendingUsersSnapshot,
      totalGroupsSnapshot,
      totalItemsSnapshot
    ] = await Promise.all([
      db.collection('users').count().get(),
      db.collection('users').where('verificationStatus', '==', 'verified').count().get(),
      db.collection('users').where('verificationStatus', '==', 'pending').count().get(),
      db.collection('groups').count().get(),
      db.collection('items').count().get()
    ]);
    
    const stats = {
      totalUsers: totalUsersSnapshot.data().count,
      verifiedUsers: verifiedUsersSnapshot.data().count,
      pendingUsers: pendingUsersSnapshot.data().count,
      totalGroups: totalGroupsSnapshot.data().count,
      totalItems: totalItemsSnapshot.data().count,
      verificationRate: totalUsersSnapshot.data().count > 0 ? 
        ((verifiedUsersSnapshot.data().count / totalUsersSnapshot.data().count) * 100).toFixed(1) : 0
    };
    
    res.json({ success: true, stats });
  } catch (err) {
    console.error('Error fetching admin stats:', err);
    res.status(500).json({ error: 'Failed to fetch stats' });
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
