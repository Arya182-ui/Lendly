const express = require('express');
const admin = require('firebase-admin');
const { isValidUid, parseIntSafe } = require('../utils/validators');

const router = express.Router();
const db = admin.firestore();

// Badge definitions with thresholds
const BADGE_DEFINITIONS = [
  { id: 'eco_starter', icon: 'eco', label: 'Eco Starter', description: 'Reuse your first item', threshold: 1, field: 'itemsReused' },
  { id: 'top_sharer', icon: 'star', label: 'Top Sharer', description: 'Reuse 10 items', threshold: 10, field: 'itemsReused' },
  { id: 'campus_hero', icon: 'public', label: 'Campus Hero', description: 'Reuse 50 items', threshold: 50, field: 'itemsReused' },
  { id: 'money_saver', icon: 'savings', label: 'Money Saver', description: 'Save ₹1000', threshold: 1000, field: 'moneySaved' },
  { id: 'eco_warrior', icon: 'forest', label: 'Eco Warrior', description: 'Save 10kg CO2', threshold: 10, field: 'co2SavedKg' },
  { id: 'community_star', icon: 'groups', label: 'Community Star', description: 'Help 5 people', threshold: 5, field: 'peopleHelped' }
];

// GET /impact/all/:userId - Combined endpoint for all impact data (reduces API calls)
router.get('/all/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    // Fetch user and leaderboard in parallel
    const [userDoc, leaderboardSnap] = await Promise.all([
      db.collection('users').doc(userId).get(),
      db.collection('users').orderBy('itemsReused', 'desc').limit(10).get()
    ]);
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = userDoc.data();
    
    // Calculate user stats
    const userStats = {
      itemsReused: data.itemsReused || 0,
      moneySaved: data.moneySaved || 0,
      co2SavedKg: Math.round((data.itemsReused || 0) * 2.3 * 10) / 10, // Estimate 2.3kg CO2 per reused item
      peopleHelped: data.peopleHelped || Math.floor((data.itemsReused || 0) / 2)
    };
    
    // Build response
    const response = {
      personal: {
        itemsReused: userStats.itemsReused,
        moneySaved: userStats.moneySaved,
        totalTransactions: data.totalTransactions || 0,
        trustScore: data.trustScore || 50
      },
      environmental: {
        co2SavedKg: userStats.co2SavedKg,
        treesEquivalent: Math.round(userStats.co2SavedKg / 21.77 * 10) / 10,
        wasteReduced: userStats.itemsReused * 0.5 // kg
      },
      community: {
        peopleHelped: userStats.peopleHelped,
        campusRank: Math.min(100, Math.max(1, 101 - userStats.itemsReused)),
        shareCount: data.shareCount || 0
      },
      badges,
      leaderboard: leaderboard.map((user, index) => ({
        rank: index + 1,
        name: user.name || 'Anonymous',
        avatar: user.avatar || 'default',
        itemsReused: user.itemsReused || 0,
        isCurrentUser: user.uid === userId
      }))
    };
    
    res.json(response);
    
    // Build leaderboard
    const leaderboard = leaderboardSnap.docs.map((doc, index) => {
      const d = doc.data();
      return {
        rank: index + 1,
        userId: doc.id,
        name: d.name || 'Anonymous',
        avatar: d.avatar || '',
        score: d.itemsReused || 0,
        isCurrentUser: doc.id === userId
      };
    });
    
    // Find user's rank if not in top 10
    let userRank = leaderboard.findIndex(l => l.isCurrentUser) + 1;
    if (userRank === 0) {
      // User not in top 10, calculate approximate rank
      const higherScoreCount = await db.collection('users')
        .where('itemsReused', '>', data.itemsReused || 0)
        .count()
        .get();
      userRank = (higherScoreCount.data().count || 0) + 1;
    }
    
    res.json({
      personal: {
        moneySaved: data.moneySaved || 0,
        itemsReused: data.itemsReused || 0,
        borrowVsBuy: data.borrowVsBuy || 0,
        itemsLent: data.itemsLent || 0,
        itemsBorrowed: data.itemsBorrowed || 0
      },
      environmental: {
        co2SavedKg: data.co2SavedKg || 0,
        resourceReuse: data.itemsReused || 0,
        treesEquivalent: Math.round((data.co2SavedKg || 0) / 21) // ~21kg CO2 per tree per year
      },
      community: {
        hostel: data.hostel || '',
        college: data.college || '',
        userContribution: data.itemsReused || 0,
        peopleHelped: data.peopleHelped || 0
      },
      badges,
      leaderboard,
      userRank,
      totalBadgesEarned: badges.filter(b => b.earned).length,
      totalBadges: badges.length
    });
  } catch (err) {
    console.error('Error fetching impact data:', err);
    res.status(500).json({ error: 'Failed to fetch impact data' });
  }
});

// GET /impact/personal/:userId
router.get('/personal/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = doc.data();
    res.json({
      moneySaved: data.moneySaved || 0,
      itemsReused: data.itemsReused || 0,
      borrowVsBuy: data.borrowVsBuy || 0,
      itemsLent: data.itemsLent || 0,
      itemsBorrowed: data.itemsBorrowed || 0,
      trustScore: data.trustScore || 0
    });
  } catch (err) {
    console.error('Error fetching personal impact:', err);
    res.status(500).json({ error: 'Failed to fetch personal impact' });
  }
});

// GET /impact/environmental/:userId
router.get('/environmental/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = doc.data();
    res.json({
      co2SavedKg: data.co2SavedKg || 0,
      resourceReuse: data.itemsReused || 0,
      treesEquivalent: Math.round((data.co2SavedKg || 0) / 21)
    });
  } catch (err) {
    console.error('Error fetching environmental impact:', err);
    res.status(500).json({ error: 'Failed to fetch environmental impact' });
  }
});

// GET /impact/community/:userId
router.get('/community/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = doc.data();
    res.json({
      hostel: data.hostel || '',
      college: data.college || '',
      userContribution: data.itemsReused || 0,
      peopleHelped: data.peopleHelped || 0
    });
  } catch (err) {
    console.error('Error fetching community impact:', err);
    res.status(500).json({ error: 'Failed to fetch community impact' });
  }
});

// GET /impact/leaderboard
router.get('/leaderboard', async (req, res) => {
  try {
    const { limit = 10, college } = req.query;
    const parsedLimit = Math.min(parseIntSafe(limit, 10), 50);
    
    let query = db.collection('users').orderBy('itemsReused', 'desc');
    
    // Filter by college if provided
    if (college && typeof college === 'string') {
      query = db.collection('users')
        .where('college', '==', college)
        .orderBy('itemsReused', 'desc');
    }
    
    const snap = await query.limit(parsedLimit).get();
    
    const leaderboard = snap.docs.map((doc, index) => {
      const d = doc.data();
      return {
        rank: index + 1,
        userId: doc.id,
        name: d.name || 'Anonymous',
        avatar: d.avatar || '',
        college: d.college || '',
        score: d.itemsReused || 0
      };
    });
    
    res.json(leaderboard);
  } catch (err) {
    console.error('Error fetching leaderboard:', err);
    res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

// GET /impact/badges/:userId
router.get('/badges/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const doc = await db.collection('users').doc(userId).get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const data = doc.data();
    
    const badges = BADGE_DEFINITIONS.map(badge => ({
      id: badge.id,
      icon: badge.icon,
      label: badge.label,
      description: badge.description,
      earned: (data[badge.field] || 0) >= badge.threshold,
      progress: Math.min(1, (data[badge.field] || 0) / badge.threshold),
      current: data[badge.field] || 0,
      target: badge.threshold
    }));
    
    res.json({
      badges,
      totalEarned: badges.filter(b => b.earned).length,
      total: badges.length
    });
  } catch (err) {
    console.error('Error fetching badges:', err);
    res.status(500).json({ error: 'Failed to fetch badges' });
  }
});

// POST /impact/log - Log an impact action (for internal use)
router.post('/log', async (req, res) => {
  try {
    const { userId, action, value = 1 } = req.body;
    
    if (!userId || !isValidUid(userId)) {
      return res.status(400).json({ error: 'Valid userId is required' });
    }
    
    const allowedActions = ['itemsReused', 'moneySaved', 'co2SavedKg', 'peopleHelped', 'itemsLent', 'itemsBorrowed'];
    if (!action || !allowedActions.includes(action)) {
      return res.status(400).json({ error: `Action must be one of: ${allowedActions.join(', ')}` });
    }
    
    const numValue = parseIntSafe(value, 1);
    if (numValue <= 0) {
      return res.status(400).json({ error: 'Value must be positive' });
    }
    
    await db.collection('users').doc(userId).update({
      [action]: admin.firestore.FieldValue.increment(numValue),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: `${action} incremented by ${numValue}` });
  } catch (err) {
    console.error('Error logging impact:', err);
    res.status(500).json({ error: 'Failed to log impact' });
  }
});

module.exports = router;

