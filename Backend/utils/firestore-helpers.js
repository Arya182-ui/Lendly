/**
 * Firestore helper utilities for batch operations and N+1 query prevention
 */
const admin = require('firebase-admin');

/**
 * Batch get documents by IDs
 * Prevents N+1 queries by fetching multiple documents in batches
 * Firestore getAll() supports up to 100 documents per call
 */
const batchGetDocs = async (collection, ids) => {
  if (!ids || ids.length === 0) return [];
  
  // Remove duplicates
  const uniqueIds = [...new Set(ids)];
  
  // Split into chunks of 100 (Firestore limit)
  const chunks = [];
  for (let i = 0; i < uniqueIds.length; i += 100) {
    chunks.push(uniqueIds.slice(i, i + 100));
  }
  
  const results = [];
  
  for (const chunk of chunks) {
    const refs = chunk.map(id => admin.firestore().collection(collection).doc(id));
    const docs = await admin.firestore().getAll(...refs);
    
    for (const doc of docs) {
      if (doc.exists) {
        results.push({ id: doc.id, ...doc.data() });
      }
    }
  }
  
  return results;
};

/**
 * Get documents as a map (id -> data)
 */
const batchGetDocsAsMap = async (collection, ids) => {
  const docs = await batchGetDocs(collection, ids);
  return Object.fromEntries(docs.map(doc => [doc.id, doc]));
};

/**
 * Batch write documents
 * Firestore batches support up to 500 operations
 */
const batchWrite = async (operations) => {
  if (!operations || operations.length === 0) return;
  
  // Split into chunks of 500
  const chunks = [];
  for (let i = 0; i < operations.length; i += 500) {
    chunks.push(operations.slice(i, i + 500));
  }
  
  for (const chunk of chunks) {
    const batch = admin.firestore().batch();
    
    for (const op of chunk) {
      const ref = admin.firestore().collection(op.collection).doc(op.id);
      
      switch (op.type) {
        case 'set':
          batch.set(ref, op.data, op.options || {});
          break;
        case 'update':
          batch.update(ref, op.data);
          break;
        case 'delete':
          batch.delete(ref);
          break;
      }
    }
    
    await batch.commit();
  }
};

/**
 * Paginated query helper
 */
const paginatedQuery = async (query, { limit = 20, startAfter = null } = {}) => {
  let q = query.limit(limit + 1); // Get one extra to check if there's more
  
  if (startAfter) {
    q = q.startAfter(startAfter);
  }
  
  const snapshot = await q.get();
  const docs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  
  const hasMore = docs.length > limit;
  if (hasMore) {
    docs.pop(); // Remove the extra document
  }
  
  return {
    data: docs,
    hasMore,
    lastDoc: docs.length > 0 ? snapshot.docs[docs.length - 1] : null
  };
};

/**
 * Transaction helper with retry
 */
const runTransaction = async (updateFunction, maxRetries = 3) => {
  let attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      return await admin.firestore().runTransaction(updateFunction);
    } catch (err) {
      attempts++;
      if (attempts >= maxRetries || !err.code || err.code !== 'aborted') {
        throw err;
      }
      // Wait before retry with exponential backoff
      await new Promise(resolve => setTimeout(resolve, 100 * Math.pow(2, attempts)));
    }
  }
};

/**
 * Increment field atomically
 */
const incrementField = (value = 1) => {
  return admin.firestore.FieldValue.increment(value);
};

/**
 * Server timestamp
 */
const serverTimestamp = () => {
  return admin.firestore.FieldValue.serverTimestamp();
};

/**
 * Array union
 */
const arrayUnion = (...elements) => {
  return admin.firestore.FieldValue.arrayUnion(...elements);
};

/**
 * Array remove
 */
const arrayRemove = (...elements) => {
  return admin.firestore.FieldValue.arrayRemove(...elements);
};

module.exports = {
  batchGetDocs,
  batchGetDocsAsMap,
  batchWrite,
  paginatedQuery,
  runTransaction,
  incrementField,
  serverTimestamp,
  arrayUnion,
  arrayRemove
};

