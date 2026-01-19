const express = require('express');
const admin = require('firebase-admin');
const router = express.Router();

// Get discoverable groups (not joined by user)
router.get('/discover', async (req, res) => {
  try {
    const { uid, limit = 20 } = req.query;
    if (!uid) {
      return res.status(400).json({ error: 'Missing uid' });
    }
    // Get all groups where user is NOT a member
    const snapshot = await admin.firestore()
      .collection('groups')
      .where('members', 'not-in', [[uid]]) // Firestore limitation workaround
      .orderBy('createdAt', 'desc')
      .limit(Number(limit))
      .get();
    // Fallback: If 'not-in' is not supported, filter in JS
    let groups = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    groups = groups.filter(g => !g.members.includes(uid));
    return res.json(groups);
  } catch (err) {
    console.error('Error fetching discover groups:', err);
    return res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

