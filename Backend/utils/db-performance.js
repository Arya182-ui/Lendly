/**
 * Database Performance Optimization Utilities
 */
const admin = require('firebase-admin');

// Connection pool settings for Firebase Admin
const FIRESTORE_SETTINGS = {
  ignoreUndefinedProperties: true,
  preferRest: false, // Use gRPC for better performance
  settings: {
    timestampsInSnapshots: true,
    merge: true,
    retry: {
      initialDelayMs: 1000,
      maxDelayMs: 10000,
      multiplier: 1.5,
      maxAttempts: 3
    }
  }
};

/**
 * Initialize Firestore with performance settings
 */
function initializeFirestore() {
  const db = admin.firestore();
  
  // Apply performance settings
  if (!db._settings) {
    db.settings(FIRESTORE_SETTINGS.settings);
  }
  
  return db;
}

/**
 * Batch operation utility for better performance
 */
class BatchOperationManager {
  constructor(db) {
    this.db = db;
    this.batch = db.batch();
    this.operationCount = 0;
    this.maxOperations = 500; // Firestore limit
  }

  addWrite(docRef, data) {
    if (this.operationCount >= this.maxOperations) {
      throw new Error('Batch operation limit exceeded');
    }
    this.batch.set(docRef, data);
    this.operationCount++;
  }

  addUpdate(docRef, data) {
    if (this.operationCount >= this.maxOperations) {
      throw new Error('Batch operation limit exceeded');
    }
    this.batch.update(docRef, data);
    this.operationCount++;
  }

  addDelete(docRef) {
    if (this.operationCount >= this.maxOperations) {
      throw new Error('Batch operation limit exceeded');
    }
    this.batch.delete(docRef);
    this.operationCount++;
  }

  async commit() {
    if (this.operationCount === 0) {
      return null;
    }
    return await this.batch.commit();
  }
}

/**
 * Query optimization utilities
 */
class QueryOptimizer {
  static addPagination(query, limit = 20, offset = 0) {
    if (offset > 0) {
      return query.limit(limit).offset(offset);
    }
    return query.limit(limit);
  }

  static addCursors(query, limit = 20, startAfterDoc = null, endBeforeDoc = null) {
    if (startAfterDoc) {
      query = query.startAfter(startAfterDoc);
    }
    if (endBeforeDoc) {
      query = query.endBefore(endBeforeDoc);
    }
    return query.limit(limit);
  }

  static optimizeWhere(query, conditions) {
    // Sort conditions for better index utilization
    const sortedConditions = conditions.sort((a, b) => {
      // Equality conditions first
      if (a.operator === '==' && b.operator !== '==') return -1;
      if (b.operator === '==' && a.operator !== '==') return 1;
      
      // Array-contains conditions next
      if (a.operator === 'array-contains' && b.operator !== 'array-contains') return -1;
      if (b.operator === 'array-contains' && a.operator !== 'array-contains') return 1;
      
      return 0;
    });

    sortedConditions.forEach(condition => {
      query = query.where(condition.field, condition.operator, condition.value);
    });

    return query;
  }
}

/**
 * Connection management for real-time listeners
 */
class ConnectionManager {
  constructor() {
    this.listeners = new Map();
  }

  addListener(key, unsubscribe) {
    this.listeners.set(key, unsubscribe);
  }

  removeListener(key) {
    const unsubscribe = this.listeners.get(key);
    if (unsubscribe) {
      unsubscribe();
      this.listeners.delete(key);
    }
  }

  removeAllListeners() {
    this.listeners.forEach(unsubscribe => unsubscribe());
    this.listeners.clear();
  }
}

/**
 * Cache management for frequently accessed data
 */
class MemoryCache {
  constructor(defaultTTL = 300000) { // 5 minutes default
    this.cache = new Map();
    this.defaultTTL = defaultTTL;
  }

  set(key, value, ttl = this.defaultTTL) {
    const expiry = Date.now() + ttl;
    this.cache.set(key, { value, expiry });
  }

  get(key) {
    const item = this.cache.get(key);
    if (!item) return null;
    
    if (Date.now() > item.expiry) {
      this.cache.delete(key);
      return null;
    }
    
    return item.value;
  }

  delete(key) {
    this.cache.delete(key);
  }

  clear() {
    this.cache.clear();
  }

  cleanup() {
    const now = Date.now();
    for (const [key, item] of this.cache.entries()) {
      if (now > item.expiry) {
        this.cache.delete(key);
      }
    }
  }
}

/**
 * Performance monitoring
 */
class PerformanceMonitor {
  static startTimer(operation) {
    return {
      start: process.hrtime.bigint(),
      operation
    };
  }

  static endTimer(timer) {
    const end = process.hrtime.bigint();
    const duration = Number(end - timer.start) / 1000000; // Convert to milliseconds
    
    if (duration > 1000) {
      console.warn(`Slow operation detected: ${timer.operation} took ${duration.toFixed(2)}ms`);
    }
    
    return duration;
  }
}

// Global instances
const memoryCache = new MemoryCache();
const connectionManager = new ConnectionManager();

// Cleanup expired cache entries every 5 minutes
setInterval(() => {
  memoryCache.cleanup();
}, 300000);

module.exports = {
  initializeFirestore,
  BatchOperationManager,
  QueryOptimizer,
  ConnectionManager,
  MemoryCache,
  PerformanceMonitor,
  memoryCache,
  connectionManager,
  FIRESTORE_SETTINGS
};
