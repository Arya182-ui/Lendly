const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');

// This endpoint expects a multipart/form-data POST with fields: uid, file (student ID image)
async function verifyStudent(req, res) {
  try {
    const { uid } = req.body;
    if (!uid || !req.file) return res.status(400).json({ error: 'UID and file required' });
    // Save file to /uploads (or use cloud storage in production)
    const uploadDir = path.join(process.cwd(), 'uploads');
    if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir);
    const ext = path.extname(req.file.originalname);
    const filename = `${uid}_${uuidv4()}${ext}`;
    const filepath = path.join(uploadDir, filename);
    fs.writeFileSync(filepath, req.file.buffer);
    // Update user doc with verificationStatus and file path
    await admin.firestore().collection('users').doc(uid).update({
      verificationStatus: 'pending',
      verificationFile: filename,
    });
    res.json({ success: true, message: 'Verification submitted' });
  } catch (err) {
    res.status(500).json({ error: 'Verification failed', details: err.message });
  }
}

module.exports = { verifyStudent };

