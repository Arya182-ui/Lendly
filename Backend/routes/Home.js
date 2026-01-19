const express = require('express');
const admin = require('firebase-admin');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');
const { isValidUid, isValidLatitude, isValidLongitude, parseFloatSafe } = require('../utils/validators');
const { cache, CacheKeys, TTL, cacheMiddleware } = require('../utils/cache');
const { authenticateUser } = require('../middleware/auth');

const router = express.Router();

// Haversine formula for distance calculation
function getDistanceKm(lat1, lon1, lat2, lon2) {
  const toRad = (x) => x * Math.PI / 180;
  const R = 6371; // Earth radius in km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) + 
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * 
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// GET /home/summary?uid=... - Optimized with caching
router.get('/summary', authenticateUser, cacheMiddleware(TTL.SHORT), async (req, res) => {
  const { uid } = req.query;
  
  if (!uid || !isValidUid(uid)) {
    return res.status(400).json({ error: 'Valid UID required' });
  }
  
  try {
    // Use parallel queries to minimize response time
    const [userDoc, notificationsCount, walletDoc] = await Promise.all([
      admin.firestore().collection('users').doc(uid).get(),
      admin.firestore().collection('users').doc(uid).collection('notifications')
        .where('read', '==', false).count().get(),
      admin.firestore().collection('wallets').doc(uid).get().catch(() => null),
    ]);
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    const walletData = walletDoc?.data();
    
    // Return optimized response with additional data for UI
    res.json({
      name: userData.name || '',
      college: userData.college || '',
      avatar: userData.avatar || userData.avatarChoice || 'default',
      avatarChoice: userData.avatarChoice || 'default',
      notifications: notificationsCount.data().count || 0,
      trustScore: userData.trustScore || 0,
      coinBalance: walletData?.balance || 0,
      verificationStatus: userData.verificationStatus || 'unknown',
      itemsShared: userData.itemsShared || 0,
      // Cache timestamp for client-side staleness detection
      cachedAt: Date.now(),
    });
  } catch (err) {
    console.error('Error fetching summary:', err);
    res.status(500).json({ error: 'Failed to fetch summary' });
  }
});

// GET /home/new-arrivals (Optimized - No N+1 queries)
router.get('/new-arrivals', authenticateUser, async (req, res) => {
  try {
    const snap = await admin.firestore()
      .collection('items')
      .where('available', '!=', false)
      .orderBy('available')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    // Collect all owner IDs
    const ownerIds = [...new Set(snap.docs.map(doc => doc.data().ownerId).filter(Boolean))];
    
    // Batch fetch all owners at once
    const ownerMap = await batchGetDocsAsMap('users', ownerIds);
    
    const items = snap.docs.map(doc => {
      const d = doc.data();
      const owner = ownerMap[d.ownerId] || {};
      return {
        id: doc.id,
        image: d.image || '',
        name: d.name || '',
        userAvatar: owner.avatar || '',
        owner: owner.name || '',
        ownerId: d.ownerId || '',
        description: d.description || '',
        price: typeof d.price !== 'undefined' ? d.price : 0,
        type: d.type || '',
      };
    });
    
    res.json(items);
  } catch (err) {
    console.error('Error fetching new arrivals:', err);
    res.status(500).json({ error: 'Failed to fetch new arrivals' });
  }
});

// GET /home/items-near-you?uid=...&latitude=...&longitude=... (Optimized)
router.get('/items-near-you', authenticateUser, async (req, res) => {
  const { uid, latitude, longitude } = req.query;
  
  if (!uid || !isValidUid(uid)) {
    return res.status(400).json({ error: 'Valid UID required' });
  }
  if (!isValidLatitude(latitude) || !isValidLongitude(longitude)) {
    return res.status(400).json({ error: 'Valid location required. Please enable location services.' });
  }
  
  const userLat = parseFloatSafe(latitude);
  const userLon = parseFloatSafe(longitude);
  
  try {
    // Get items with location data - limit to recent items to avoid full scan
    const snap = await admin.firestore()
      .collection('items')
      .where('available', '!=', false)
      .orderBy('available')
      .orderBy('createdAt', 'desc')
      .limit(100) // Limit to prevent full collection scan
      .get();
    
    // Filter by distance first
    const nearbyItems = [];
    for (const doc of snap.docs) {
      const d = doc.data();
      if (!d.location?.latitude || !d.location?.longitude) continue;
      if (d.ownerId === uid) continue; // Exclude own items
      
      const dist = getDistanceKm(userLat, userLon, d.location.latitude, d.location.longitude);
      if (dist <= 5) { // 5km radius
        nearbyItems.push({ doc, data: d, distance: dist });
      }
      if (nearbyItems.length >= 10) break;
    }
    
    // Sort by distance
    nearbyItems.sort((a, b) => a.distance - b.distance);
    
    // Batch fetch all owners
    const ownerIds = [...new Set(nearbyItems.map(item => item.data.ownerId).filter(Boolean))];
    const ownerMap = await batchGetDocsAsMap('users', ownerIds);
    
    const items = nearbyItems.map(({ doc, data: d, distance }) => {
      const owner = ownerMap[d.ownerId] || {};
      return {
        id: doc.id,
        image: d.image || '',
        name: d.name || '',
        owner: owner.name || '',
        ownerId: d.ownerId || '',
        available: d.available !== false,
        distance: `${distance.toFixed(2)} km`,
        description: d.description || '',
        price: typeof d.price !== 'undefined' ? d.price : 0,
        type: d.type || '',
      };
    });
    
    res.json(items);
  } catch (err) {
    console.error('Error fetching items near you:', err);
    res.status(500).json({ error: 'Failed to fetch items near you' });
  }
});

// GET /home/groups
router.get('/groups', async (req, res) => {
  try {
    const snap = await admin.firestore()
      .collection('groups')
      .where('isPublic', '!=', false)
      .orderBy('isPublic')
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    const groups = snap.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        name: d.name || '',
        icon: d.icon || 'group',
        members: Array.isArray(d.members) ? d.members.length : 0,
        type: d.type || '',
        description: d.description || '',
      };
    });
    
    res.json(groups);
  } catch (err) {
    console.error('Error fetching groups:', err);
    res.status(500).json({ error: 'Failed to fetch groups' });
  }
});

// GET /home/all - CONSOLIDATED endpoint to reduce API calls
// Returns all home screen data in a single optimized request
router.get('/all', authenticateUser, cacheMiddleware(TTL.SHORT), async (req, res) => {
  const { uid, latitude, longitude } = req.query;
  
  if (!uid || !isValidUid(uid)) {
    return res.status(400).json({ error: 'Valid UID required' });
  }
  
  try {
    // Execute ALL queries in parallel for maximum efficiency
    const [
      userDoc,
      notificationsCount,
      walletDoc,
      newArrivalsSnap,
      groupsSnap,
      impactData,
      recentChatsSnap,
      dailyChallengeDoc,
      activitiesSnap
    ] = await Promise.all([
      // User data
      admin.firestore().collection('users').doc(uid).get(),
      // Notifications count
      admin.firestore().collection('users').doc(uid).collection('notifications')
        .where('read', '==', false).count().get(),
      // Wallet
      admin.firestore().collection('wallets').doc(uid).get().catch(() => null),
      // New arrivals - exclude user's own items
      admin.firestore().collection('items')
        .where('available', '!=', false)
        .orderBy('available')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get(),
      // Groups
      admin.firestore().collection('groups')
        .where('isPublic', '!=', false)
        .orderBy('isPublic')
        .orderBy('createdAt', 'desc')
        .limit(5)
        .get(),
      // Impact data
      admin.firestore().collection('impact').doc(uid).get().catch(() => null),
      // Recent chats
      admin.firestore().collection('users').doc(uid).collection('friends')
        .orderBy('lastMessage', 'desc')
        .limit(5)
        .get().catch(() => ({ docs: [] })),
      // Daily challenge
      admin.firestore().collection('challenges').doc('daily').get().catch(() => null),
      // Campus activities
      admin.firestore().collection('activities')
        .orderBy('createdAt', 'desc')
        .limit(10)
        .get().catch(() => ({ docs: [] }))
    ]);
    
    if (!userDoc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = userDoc.data();
    const walletData = walletDoc?.data();
    const impactDoc = impactData?.data() || {};
    
    // Collect all owner IDs for batch fetching
    const ownerIds = [...new Set(newArrivalsSnap.docs.map(doc => doc.data().ownerId).filter(Boolean))];
    const ownerMap = await batchGetDocsAsMap('users', ownerIds);
    
    // Format new arrivals
    const newArrivals = newArrivalsSnap.docs
      .filter(doc => doc.data().ownerId !== uid) // Exclude user's own items
      .slice(0, 10)
      .map(doc => {
        const d = doc.data();
        const owner = ownerMap[d.ownerId] || {};
        return {
          id: doc.id,
          image: d.image || '',
          name: d.name || '',
          userAvatar: owner.avatar || '',
          owner: owner.name || '',
          ownerId: d.ownerId || '',
          description: d.description || '',
          price: typeof d.price !== 'undefined' ? d.price : 0,
          type: d.type || '',
          available: d.available !== false,
          ownerTrustScore: owner.trustScore || 50
        };
      });
    
    // Format groups
    const groups = groupsSnap.docs.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        name: d.name || '',
        icon: d.icon || 'group',
        members_count: Array.isArray(d.members) ? d.members.length : 0,
        type: d.type || '',
        description: d.description || '',
      };
    });
    
    // Format recent chats
    const recentChats = recentChatsSnap.docs?.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        other_user_name: d.name || '',
        other_user_avatar: d.avatar || '',
        last_message: d.lastMessage || '',
        unread_count: d.unreadCount || 0,
        last_message_time: d.lastMessageTime
      };
    }) || [];
    
    // Format daily challenge
    const dailyChallenge = dailyChallengeDoc?.exists ? {
      id: dailyChallengeDoc.id,
      title: dailyChallengeDoc.data().title || 'List 1 item today',
      description: dailyChallengeDoc.data().description || 'Earn 50 bonus coins!',
      reward: dailyChallengeDoc.data().reward || 50,
      type: dailyChallengeDoc.data().type || 'listing',
      expiresAt: dailyChallengeDoc.data().expiresAt
    } : null;
    
    // Format campus activities
    const campusActivities = activitiesSnap.docs?.map(doc => {
      const d = doc.data();
      return {
        id: doc.id,
        type: d.type || 'item_listed',
        title: d.title || '',
        user: {
          name: d.userName || 'Anonymous',
          avatar: d.userAvatar || null
        },
        timestamp: d.createdAt,
        likes: d.likes || 0
      };
    }) || [];
    
    // Handle nearby items if location is provided
    let nearbyItems = [];
    if (latitude && longitude && isValidLatitude(latitude) && isValidLongitude(longitude)) {
      const userLat = parseFloatSafe(latitude);
      const userLon = parseFloatSafe(longitude);
      
      // Filter from already fetched items for efficiency
      const itemsWithLocation = newArrivalsSnap.docs
        .filter(doc => {
          const d = doc.data();
          return d.location?.latitude && d.location?.longitude && d.ownerId !== uid;
        });
      
      for (const doc of itemsWithLocation) {
        const d = doc.data();
        const dist = getDistanceKm(userLat, userLon, d.location.latitude, d.location.longitude);
        if (dist <= 5) {
          const owner = ownerMap[d.ownerId] || {};
          nearbyItems.push({
            id: doc.id,
            image: d.image || '',
            name: d.name || '',
            owner: owner.name || '',
            ownerId: d.ownerId || '',
            available: d.available !== false,
            distance: `${dist.toFixed(2)} km`,
            description: d.description || '',
            price: typeof d.price !== 'undefined' ? d.price : 0,
            type: d.type || '',
          });
        }
        if (nearbyItems.length >= 10) break;
      }
      nearbyItems.sort((a, b) => parseFloat(a.distance) - parseFloat(b.distance));
    }
    
    // Return consolidated response
    res.json({
      // User data
      user: {
        name: userData.name || '',
        first_name: userData.firstName || userData.name?.split(' ')[0] || '',
        college: userData.college || '',
        avatar: userData.avatar || userData.avatarChoice || 'default',
        avatar_url: userData.avatar || userData.avatarChoice || '',
        trustScore: userData.trustScore || 50,
        verification_status: userData.verificationStatus || 'pending',
        notifications: notificationsCount.data().count || 0,
      },
      // Wallet
      wallet: {
        balance: walletData?.balance || 0,
      },
      // Impact summary
      impact: {
        money_saved: impactDoc.moneySaved || 0,
        items_shared: impactDoc.itemsShared || 0,
        co2_saved: impactDoc.co2Saved || 0,
      },
      // Lists
      newArrivals,
      nearbyItems,
      groups,
      recentChats,
      dailyChallenge,
      campusActivities,
      // Cache info
      cachedAt: Date.now(),
    });
  } catch (err) {
    console.error('Error fetching consolidated home data:', err);
    res.status(500).json({ error: 'Failed to fetch home data' });
  }
});

module.exports = router;

