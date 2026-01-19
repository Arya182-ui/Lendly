const express = require('express');
const admin = require('firebase-admin');
const multer = require('multer');
const { sanitizeHtml, trimObjectStrings } = require('../utils/validators');
const { validateBody, validateQuery, validateParams } = require('../middleware/validation');
const itemSchemas = require('../validation/items.schemas');
const { CoinsManager } = require('../utils/coins-manager');
const { batchGetDocsAsMap } = require('../utils/firestore-helpers');

const router = express.Router();
const db = admin.firestore();

// Configure multer with file size and type limits
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB max
    files: 1
  },
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only JPEG, PNG, GIF, and WebP are allowed.'), false);
    }
  }
});

const ALLOWED_TYPES = ['lend', 'sell', 'borrow'];
const ALLOWED_CATEGORIES = ['electronics', 'books', 'clothing', 'furniture', 'sports', 'tools', 'other'];

// POST /items - Add new item with image upload
router.post('/', upload.single('image'), async (req, res) => {
  try {
    const { name, description, category, price, type, ownerId, latitude, longitude } = trimObjectStrings(req.body);
    
    // Validation
    const errors = [];
    if (!name || !isValidLength(name, 2, 100)) errors.push('Name is required (2-100 characters)');
    if (!category) errors.push('Category is required');
    if (category && !ALLOWED_CATEGORIES.includes(category.toLowerCase())) {
      errors.push(`Category must be one of: ${ALLOWED_CATEGORIES.join(', ')}`);
    }
    if (!type || !ALLOWED_TYPES.includes(type)) {
      errors.push(`Type must be one of: ${ALLOWED_TYPES.join(', ')}`);
    }
    if (!ownerId || !isValidUid(ownerId)) errors.push('Valid ownerId is required');
    if (price !== undefined && price !== '' && isNaN(Number(price))) {
      errors.push('Price must be a valid number');
    }
    if (description && !isValidLength(description, 0, 1000)) {
      errors.push('Description must be under 1000 characters');
    }
    if (latitude && !isValidLatitude(latitude)) errors.push('Invalid latitude');
    if (longitude && !isValidLongitude(longitude)) errors.push('Invalid longitude');
    
    if (errors.length > 0) {
      return res.status(400).json({ error: 'Validation failed', details: errors });
    }
    
    // Verify owner exists
    const ownerDoc = await db.collection('users').doc(ownerId).get();
    if (!ownerDoc.exists) {
      return res.status(400).json({ error: 'Owner user not found' });
    }
    
    let imageUrl = '';
    if (req.file) {
      const bucket = admin.storage().bucket();
      // Sanitize filename
      const safeName = req.file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_');
      const fileName = `items/${Date.now()}_${safeName}`;
      const file = bucket.file(fileName);
      
      await file.save(req.file.buffer, {
        metadata: { 
          contentType: req.file.mimetype,
          cacheControl: 'public, max-age=31536000'
        },
        public: true,
      });
      imageUrl = file.publicUrl();
    }
    
    const item = {
      name: sanitizeHtml(name),
      description: sanitizeHtml(description || ''),
      category: category.toLowerCase(),
      price: price ? Math.max(0, Number(price)) : 0,
      image: imageUrl,
      type,
      ownerId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      available: true,
      ...(latitude && longitude && {
        location: { 
          latitude: parseFloatSafe(latitude), 
          longitude: parseFloatSafe(longitude) 
        }
      })
    };
    
    const ref = await db.collection('items').add(item);
    
    // Charge coins for listing an item
    try {
      await CoinsManager.chargeForListing(ownerId, ref.id, item.name);
      console.log(`[ITEMS] Charged 10 coins for listing item ${ref.id}`);
    } catch (coinsError) {
      console.error('[ITEMS] Failed to charge coins for item listing:', coinsError);
      // If insufficient balance, delete the item and return error
      if (coinsError.message && coinsError.message.includes('Insufficient balance')) {
        await db.collection('items').doc(ref.id).delete();
        return res.status(402).json({ error: 'Insufficient coins to list item. You need 10 coins.' });
      }
      // For other errors, still create the item
    }
    
    res.status(201).json({ id: ref.id, ...item });
  } catch (err) {
    console.error('Error adding item:', err);
    if (err.message?.includes('Invalid file type')) {
      return res.status(400).json({ error: err.message });
    }
    res.status(500).json({ error: 'Failed to add item' });
  }
});

// PUT /items/:id - Update item (only by owner)
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { ownerId, ...updateFields } = trimObjectStrings(req.body);
    
    if (!ownerId || !isValidUid(ownerId)) {
      return res.status(400).json({ error: 'Valid ownerId required' });
    }
    if (!id || !isValidLength(id, 1, 128)) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    // Validate update fields
    const allowedFields = ['name', 'description', 'category', 'price', 'type', 'available', 'latitude', 'longitude'];
    const sanitizedFields = {};
    
    for (const [key, value] of Object.entries(updateFields)) {
      if (!allowedFields.includes(key)) continue;
      
      if (key === 'name') {
        if (!isValidLength(value, 2, 100)) {
          return res.status(400).json({ error: 'Name must be 2-100 characters' });
        }
        sanitizedFields.name = sanitizeHtml(value);
      } else if (key === 'description') {
        if (!isValidLength(value, 0, 1000)) {
          return res.status(400).json({ error: 'Description must be under 1000 characters' });
        }
        sanitizedFields.description = sanitizeHtml(value);
      } else if (key === 'category') {
        if (!ALLOWED_CATEGORIES.includes(value?.toLowerCase())) {
          return res.status(400).json({ error: `Category must be one of: ${ALLOWED_CATEGORIES.join(', ')}` });
        }
        sanitizedFields.category = value.toLowerCase();
      } else if (key === 'type') {
        if (!ALLOWED_TYPES.includes(value)) {
          return res.status(400).json({ error: `Type must be one of: ${ALLOWED_TYPES.join(', ')}` });
        }
        sanitizedFields.type = value;
      } else if (key === 'price') {
        const numPrice = Number(value);
        if (isNaN(numPrice) || numPrice < 0) {
          return res.status(400).json({ error: 'Price must be a non-negative number' });
        }
        sanitizedFields.price = numPrice;
      } else if (key === 'available') {
        sanitizedFields.available = value === true || value === 'true';
      }
    }
    
    // Handle location update
    if (updateFields.latitude && updateFields.longitude) {
      if (!isValidLatitude(updateFields.latitude) || !isValidLongitude(updateFields.longitude)) {
        return res.status(400).json({ error: 'Invalid location coordinates' });
      }
      sanitizedFields.location = {
        latitude: parseFloatSafe(updateFields.latitude),
        longitude: parseFloatSafe(updateFields.longitude)
      };
    }
    
    if (Object.keys(sanitizedFields).length === 0) {
      return res.status(400).json({ error: 'No valid fields to update' });
    }
    
    const itemRef = db.collection('items').doc(id);
    const itemDoc = await itemRef.get();
    
    if (!itemDoc.exists) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    const itemData = itemDoc.data();
    if (itemData.ownerId !== ownerId) {
      return res.status(403).json({ error: 'Only the owner can update this item' });
    }
    
    sanitizedFields.updatedAt = admin.firestore.FieldValue.serverTimestamp();
    await itemRef.update(sanitizedFields);
    
    const updatedDoc = await itemRef.get();
    const updatedData = updatedDoc.data();
    
    // Fetch owner info
    const userDoc = await db.collection('users').doc(ownerId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    
    res.json({
      id,
      ...updatedData,
      owner: userData.name || '',
      userAvatar: userData.avatar || ''
    });
  } catch (err) {
    console.error('Error updating item:', err);
    res.status(500).json({ error: 'Failed to update item' });
  }
});

// DELETE /items/:id - Delete item (only by owner)
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const ownerId = req.query.ownerId || req.body.ownerId;
    
    if (!ownerId || !isValidUid(ownerId)) {
      return res.status(400).json({ error: 'Valid ownerId required' });
    }
    if (!id || !isValidLength(id, 1, 128)) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    const itemRef = db.collection('items').doc(id);
    const itemDoc = await itemRef.get();
    
    if (!itemDoc.exists) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    const itemData = itemDoc.data();
    if (itemData.ownerId !== ownerId) {
      return res.status(403).json({ error: 'Only the owner can delete this item' });
    }
    
    // Delete associated image from storage if exists
    if (itemData.image) {
      try {
        const bucket = admin.storage().bucket();
        const imagePath = itemData.image.split('/o/')[1]?.split('?')[0];
        if (imagePath) {
          await bucket.file(decodeURIComponent(imagePath)).delete();
        }
      } catch (imgErr) {
        console.error('Failed to delete image:', imgErr);
        // Continue with item deletion even if image delete fails
      }
    }
    
    await itemRef.delete();
    res.json({ success: true });
  } catch (err) {
    console.error('Error deleting item:', err);
    res.status(500).json({ error: 'Failed to delete item' });
  }
});

// GET /items/search - Advanced search with multiple filters
router.get('/search', async (req, res) => {
  try {
    const {
      q,                    // search query
      category,             // category filter
      type,                 // type filter (lend, sell, borrow)
      condition,            // condition filter
      minPrice,             // minimum price
      maxPrice,             // maximum price
      available,            // availability filter
      sortBy = 'newest',    // sorting (newest, oldest, price_low, price_high)
      limit = 50,           // results limit
      excludeUid            // exclude items from specific user
    } = req.query;

    let query = db.collection('items');
    
    // Apply filters
    if (category && ALLOWED_CATEGORIES.includes(category.toLowerCase())) {
      query = query.where('category', '==', category.toLowerCase());
    }
    if (type && ALLOWED_TYPES.includes(type)) {
      query = query.where('type', '==', type);
    }
    if (available !== undefined) {
      query = query.where('available', '==', available === 'true');
    }

    // Get results
    const snapshot = await query.limit(Number(limit) || 50).get();
    
    // First pass: filter items and collect owner IDs
    const filteredItems = [];
    const ownerIds = new Set();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Skip items from excluded user
      if (excludeUid && data.ownerId === excludeUid) continue;
      
      // Text search filter (applied after Firestore query)
      if (q && q.trim()) {
        const searchText = q.toLowerCase().trim();
        const name = (data.name || '').toLowerCase();
        const description = (data.description || '').toLowerCase();
        
        if (!name.includes(searchText) && !description.includes(searchText)) {
          continue;
        }
      }

      // Condition filter (if provided)
      if (condition && data.condition !== condition) continue;

      // Price range filter
      const price = Number(data.price) || 0;
      if (minPrice !== undefined && price < Number(minPrice)) continue;
      if (maxPrice !== undefined && price > Number(maxPrice)) continue;

      // Collect owner ID for batch fetch
      if (data.ownerId) {
        ownerIds.add(data.ownerId);
      }

      filteredItems.push({ doc, data, price });
    }

    // Batch fetch all owner profiles at once (prevents N+1 queries)
    const ownerMap = ownerIds.size > 0 ? await batchGetDocsAsMap('users', Array.from(ownerIds)) : {};

    // Second pass: build final items array with owner info
    const items = filteredItems.map(({ doc, data, price }) => ({
      id: doc.id,
      name: data.name || '',
      description: data.description || '',
      category: data.category || '',
      type: data.type || '',
      condition: data.condition || '',
      price: price,
      image: data.image || '',
      available: data.available !== false,
      createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
      owner: ownerMap[data.ownerId]?.name || data.ownerName || 'Unknown',
      ownerId: data.ownerId || '',
    }));

    // Sort results
    switch (sortBy) {
      case 'oldest':
        items.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        break;
      case 'price_low':
        items.sort((a, b) => a.price - b.price);
        break;
      case 'price_high':
        items.sort((a, b) => b.price - a.price);
        break;
      case 'newest':
      default:
        items.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        break;
    }

    res.json({
      items,
      total: items.length,
      query: {
        q,
        category,
        type,
        condition,
        minPrice,
        maxPrice,
        available,
        sortBy,
      }
    });

  } catch (err) {
    console.error('Error searching items:', err);
    res.status(500).json({ error: 'Failed to search items' });
  }
});

// GET /items/categories - Get items grouped by categories
router.get('/categories', async (req, res) => {
  try {
    const { limit = 5 } = req.query;
    const categories = {};

    for (const category of ALLOWED_CATEGORIES) {
      const snapshot = await db.collection('items')
        .where('category', '==', category)
        .where('available', '==', true)
        .orderBy('createdAt', 'desc')
        .limit(Number(limit))
        .get();

      const items = [];
      for (const doc of snapshot.docs) {
        const data = doc.data();
        
        // Get owner info
        let ownerName = 'Unknown';
        if (data.ownerId) {
          try {
            const ownerDoc = await admin.firestore().collection('users').doc(data.ownerId).get();
            if (ownerDoc.exists) {
              ownerName = ownerDoc.data().name || 'Unknown';
            }
          } catch (err) {
            ownerName = data.ownerName || 'Unknown';
          }
        }

        items.push({
          id: doc.id,
          name: data.name || '',
          description: data.description || '',
          category: data.category || '',
          type: data.type || '',
          price: Number(data.price) || 0,
          image: data.image || '',
          available: data.available !== false,
          createdAt: data.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
          owner: ownerName,
          ownerId: data.ownerId || '',
        });
      }

      categories[category] = {
        name: category.charAt(0).toUpperCase() + category.slice(1),
        count: items.length,
        items
      };
    }

    res.json(categories);

  } catch (err) {
    console.error('Error fetching categories:', err);
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// GET /items - List items with filters
router.get('/', async (req, res) => {
  try {
    const { limit, category, type, ownerId, available } = req.query;
    
    // Validation
    let parsedLimit = 20;
    if (limit !== undefined) {
      parsedLimit = Number(limit);
      if (isNaN(parsedLimit) || parsedLimit < 1 || parsedLimit > 100) {
        return res.status(400).json({ error: 'Limit must be between 1 and 100' });
      }
    }
    if (type && !ALLOWED_TYPES.includes(type)) {
      return res.status(400).json({ error: `Type must be one of: ${ALLOWED_TYPES.join(', ')}` });
    }
    if (category && !ALLOWED_CATEGORIES.includes(category.toLowerCase())) {
      return res.status(400).json({ error: `Category must be one of: ${ALLOWED_CATEGORIES.join(', ')}` });
    }
    if (ownerId && !isValidUid(ownerId)) {
      return res.status(400).json({ error: 'Invalid ownerId' });
    }
    
    let query = db.collection('items');
    
    // Apply filters
    if (ownerId) {
      query = query.where('ownerId', '==', ownerId);
    }
    if (category) {
      query = query.where('category', '==', category.toLowerCase());
    }
    if (type) {
      query = query.where('type', '==', type);
    }
    if (available !== undefined) {
      query = query.where('available', '==', available === 'true');
    }
    
    query = query.orderBy('createdAt', 'desc').limit(parsedLimit);
    
    const snap = await query.get();
    const items = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    res.json(items);
  } catch (err) {
    console.error('Error fetching items:', err);
    res.status(500).json({ error: 'Failed to fetch items' });
  }
});

// GET /items/:id - Get single item by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    if (!id || !isValidLength(id, 1, 128)) {
      return res.status(400).json({ error: 'Invalid item ID' });
    }
    
    const itemDoc = await db.collection('items').doc(id).get();
    
    if (!itemDoc.exists) {
      return res.status(404).json({ error: 'Item not found' });
    }
    
    const itemData = itemDoc.data();
    
    // Fetch owner info
    let ownerData = {};
    if (itemData.ownerId) {
      const ownerDoc = await db.collection('users').doc(itemData.ownerId).get();
      if (ownerDoc.exists) {
        const owner = ownerDoc.data();
        ownerData = {
          owner: owner.name || '',
          userAvatar: owner.avatar || '',
          ownerCollege: owner.college || ''
        };
      }
    }
    
    res.json({
      id: itemDoc.id,
      ...itemData,
      ...ownerData
    });
  } catch (err) {
    console.error('Error fetching item:', err);
    res.status(500).json({ error: 'Failed to fetch item' });
  }
});

module.exports = router;

