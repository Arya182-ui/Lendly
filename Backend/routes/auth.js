const express = require('express');
const admin = require('firebase-admin');
const multer = require('multer');
const { submitIssueReport } = require('../issueReports.js');
const { sanitizeHtml, isValidUid, isValidLength } = require('../utils/validators');
const { validateBody } = require('../middleware/validation');
const authSchemas = require('../validation/auth.schemas');
const { TrustScoreManager } = require('../utils/trust-score-manager');
const { CoinsManager } = require('../utils/coins-manager');
const { rateLimit } = require('../middleware/auth');

const router = express.Router();
const db = admin.firestore();

// Helper function for email validation
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email) && email.length <= 254;
};

// --- Enhanced Multer setup with better security ---
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB max for ID verification
    files: 1,
    fieldSize: 1024 * 1024, // 1MB field size limit
    fieldNameSize: 100, // Limit field name size
    fields: 10 // Limit number of fields
  },
  fileFilter: (req, file, cb) => {
    console.log('[UPLOAD] File upload attempt:', {
      filename: file.originalname,
      mimetype: file.mimetype,
      fieldname: file.fieldname,
      clientIp: req.ip
    });
    
    // Strict MIME type validation
    const allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'application/pdf'];
    
    if (!allowedMimes.includes(file.mimetype)) {
      console.warn('[UPLOAD] Rejected file with invalid MIME type:', {
        mimetype: file.mimetype,
        filename: file.originalname,
        clientIp: req.ip
      });
      return cb(new Error('Invalid file type. Only JPEG, PNG, GIF, and PDF are allowed.'), false);
    }
    
    // Validate file extension matches MIME type
    const ext = file.originalname.toLowerCase().split('.').pop();
    const validExtensions = {
      'image/jpeg': ['jpg', 'jpeg'],
      'image/png': ['png'],
      'image/gif': ['gif'],
      'application/pdf': ['pdf']
    };
    
    if (!validExtensions[file.mimetype]?.includes(ext)) {
      console.warn('[UPLOAD] MIME type and extension mismatch:', {
        mimetype: file.mimetype,
        extension: ext,
        filename: file.originalname,
        clientIp: req.ip
      });
      return cb(new Error('File extension does not match MIME type'), false);
    }
    
    // Additional filename validation
    if (file.originalname.length > 255 || /[<>:"|?*\x00-\x1f]/.test(file.originalname)) {
      console.warn('[UPLOAD] Invalid filename:', {
        filename: file.originalname,
        clientIp: req.ip
      });
      return cb(new Error('Invalid filename format'), false);
    }
    
    cb(null, true);
  }
});

// --- ISSUE REPORTING ---
router.post('/report-issue', 
  rateLimit({ max: 5, windowMs: 60 * 60 * 1000 }), // 5 per hour
  async (req, res) => {
    const { email, name, issueDescription } = req.body;

    if (!isValidEmail(email) || !isValidLength(name, 2, 50) || !isValidLength(issueDescription, 10, 1000)) {
      return res.status(400).json({ 
        error: 'Invalid input', 
        details: 'Email, name (2-50 chars), and description (10-1000 chars) required' 
      });
    }

    try {
      await submitIssueReport(email, name, issueDescription);
      res.status(200).json({ message: 'Issue report submitted successfully' });
    } catch (error) {
      console.error('Issue report failed:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  }
);

// --- STUDENT VERIFICATION ---
router.post('/verify-student', 
  rateLimit({ max: 3, windowMs: 60 * 60 * 1000 }), // 3 per hour
  upload.single('file'), 
  async (req, res) => {
  try {
    const { uid, email } = req.body;
    
    if (!isValidUid(uid) || !isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid UID or email' });
    }

    const file = req.file;
    if (!file) {
      return res.status(400).json({ error: 'File is required for student verification' });
    }

    // Store verification request in Firestore
    const verificationData = {
      uid: sanitizeHtml(uid),
      email: sanitizeHtml(email),
      fileName: file.originalname,
      fileSize: file.size,
      mimeType: file.mimetype,
      uploadedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending',
      reviewedAt: null,
      reviewedBy: null
    };

    // Upload file to Firebase Storage
    const bucket = admin.storage().bucket();
    const fileName = `student-verification/${uid}-${Date.now()}-${file.originalname}`;
    const fileRef = bucket.file(fileName);
    
    await fileRef.save(file.buffer, {
      metadata: {
        contentType: file.mimetype,
        metadata: {
          uploadedBy: uid,
          purpose: 'student-verification'
        }
      }
    });

    verificationData.filePath = fileName;

    // Save to Firestore
    await db.collection('studentVerifications').doc(uid).set(verificationData);

    res.json({ 
      message: 'Student verification submitted successfully',
      status: 'pending'
    });

  } catch (error) {
    console.error('Student verification error:', error);
    res.status(500).json({ error: 'Student verification failed' });
  }
});

// --- COMPLETE USER ONBOARDING ---
router.post('/complete-onboarding', async (req, res) => {
  try {
    const { uid, displayName, email, avatarChoice } = req.body;
    
    if (!isValidUid(uid) || !isValidLength(displayName, 2, 30)) {
      return res.status(400).json({ error: 'Valid UID and display name (2-30 chars) required' });
    }

    const userData = {
      uid: sanitizeHtml(uid),
      name: sanitizeHtml(displayName),
      email: email ? sanitizeHtml(email) : '',
      displayName: sanitizeHtml(displayName),
      avatarChoice: sanitizeHtml(avatarChoice) || 'default',
      avatar: sanitizeHtml(avatarChoice) || 'default',
      photo: sanitizeHtml(avatarChoice) || 'default',
      college: '',
      hostel: '',
      bio: '',
      interests: [],
      trustScore: 50, // Starting trust score
      borrowed: 0,
      lent: 0,
      rating: 0,
      totalRatings: 0,
      verificationStatus: 'unverified',
      socialProfile: '',
      welcomeBonusCollected: false,
      onboardingCompleted: false, // Mark as incomplete - need full onboarding later
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActive: admin.firestore.FieldValue.serverTimestamp()
    };

    // Save user data to Firestore
    await db.collection('users').doc(uid).set(userData, { merge: true });
    
    // Initialize coins wallet (100 welcome bonus)
    await CoinsManager.initializeWallet(uid, 100);
    
    // Initialize trust score (base 50 for new user)
    await TrustScoreManager.initializeTrustScore(uid);

    console.log('[ONBOARDING] User profile created:', { uid, email: userData.email });

    res.json({ 
      message: 'Onboarding completed successfully',
      user: userData 
    });

  } catch (error) {
    console.error('Onboarding completion error:', error);
    res.status(500).json({ error: 'Failed to complete onboarding' });
  }
});

// Admin endpoint to approve/reject student verification
router.post('/admin/verify-student/:uid', async (req, res) => {
  try {
    const { uid } = req.params;
    const { action, reviewerId } = req.body; // action: 'approve' or 'reject'
    
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action. Must be approve or reject' });
    }
    
    // Update verification status
    const batch = db.batch();
    
    // Update user verification status
    const userRef = db.collection('users').doc(uid);
    batch.update(userRef, {
      verificationStatus: action === 'approve' ? 'verified' : 'rejected',
      verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      verifiedBy: reviewerId
    });
    
    // Update verification request
    const verificationRef = db.collection('studentVerifications').doc(uid);
    batch.update(verificationRef, {
      status: action === 'approve' ? 'approved' : 'rejected',
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: reviewerId
    });
    
    await batch.commit();
    
    // Award verification bonus if approved
    if (action === 'approve') {
      await CoinsManager.addCoins(uid, {
        amount: 25,
        type: 'bonus_verification',
        description: 'Student ID verified successfully',
        metadata: { verifiedBy: reviewerId }
      });
      
      // Update trust score
      await TrustScoreManager.onIDVerification(uid);
    }
    
    res.json({ success: true, message: `Student verification ${action}d successfully` });
  } catch (error) {
    console.error('Student verification approval error:', error);
    res.status(500).json({ error: 'Failed to process verification' });
  }
});

// Get pending verifications (admin only)
router.get('/admin/pending-verifications', async (req, res) => {
  try {
    const snapshot = await db.collection('studentVerifications')
      .where('status', '==', 'pending')
      .orderBy('uploadedAt', 'desc')
      .limit(50)
      .get();
    
    const verifications = await Promise.all(
      snapshot.docs.map(async (doc) => {
        const data = doc.data();
        const userDoc = await db.collection('users').doc(doc.id).get();
        const userData = userDoc.data();
        
        return {
          uid: doc.id,
          ...data,
          userName: userData?.name || 'Unknown',
          userEmail: userData?.email || 'Unknown'
        };
      })
    );
    
    res.json({ success: true, verifications });
  } catch (error) {
    console.error('Error fetching pending verifications:', error);
    res.status(500).json({ error: 'Failed to fetch verifications' });
  }
});

// --- TOKEN REFRESH ENDPOINT ---
router.post('/refresh-token', 
  rateLimit({ max: 10, windowMs: 60 * 1000 }), // 10 per minute
  async (req, res) => {
    try {
      const { refreshToken } = req.body;
      
      if (!refreshToken) {
        return res.status(400).json({ 
          error: 'Refresh token required',
          code: 'REFRESH_TOKEN_MISSING'
        });
      }
      
      console.log('[AUTH] Token refresh request from:', req.ip);
      
      // TODO: Implement Firebase Auth REST API integration
      // For now, return guidance to use Firebase SDK on client
      res.status(501).json({
        error: 'Token refresh should be handled by Firebase SDK on client',
        code: 'REFRESH_NOT_IMPLEMENTED',
        message: 'Use Firebase Auth SDK refreshToken method on client side'
      });
      
    } catch (error) {
      console.error('[AUTH] Token refresh error:', error);
      res.status(500).json({ 
        error: 'Token refresh failed',
        code: 'REFRESH_ERROR'
      });
    }
  }
);

// --- LOGOUT ENDPOINT ---
router.post('/logout', 
  rateLimit({ max: 20, windowMs: 60 * 1000 }), // 20 per minute
  async (req, res) => {
    try {
      const authHeader = req.headers.authorization;
      
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(400).json({ 
          error: 'Authentication token required for logout',
          code: 'AUTH_TOKEN_MISSING'
        });
      }
      
      const token = authHeader.split('Bearer ')[1];
      
      try {
        // Verify token and get user info
        const decoded = await admin.auth().verifyIdToken(token);
        
        console.log('[AUTH] User logout:', { 
          uid: decoded.uid, 
          clientIp: req.ip,
          timestamp: new Date().toISOString()
        });
        
        // TODO: In production, consider revoking refresh tokens
        // await admin.auth().revokeRefreshTokens(decoded.uid);
        
        res.json({ 
          success: true, 
          message: 'Logged out successfully',
          code: 'LOGOUT_SUCCESS'
        });
        
      } catch (tokenError) {
        // Even if token is invalid, logout should succeed
        console.log('[AUTH] Logout with invalid token:', { 
          clientIp: req.ip, 
          error: tokenError.message 
        });
        
        res.json({ 
          success: true, 
          message: 'Logged out successfully',
          code: 'LOGOUT_SUCCESS_INVALID_TOKEN'
        });
      }
      
    } catch (error) {
      console.error('[AUTH] Logout error:', error);
      res.status(500).json({ 
        error: 'Logout failed',
        code: 'LOGOUT_ERROR'
      });
    }
  }
);

module.exports = router;
