/**
 * Database Optimization and Performance Enhancement Script
 * Addresses critical performance bottlenecks identified in the Lendly application
 */

const admin = require('firebase-admin');
const { performance } = require('perf_hooks');

// Performance monitoring utilities
class PerformanceMonitor {
  constructor() {
    this.metrics = new Map();
  }

  startTimer(operationName) {
    this.metrics.set(operationName, performance.now());
  }

  endTimer(operationName) {
    const startTime = this.metrics.get(operationName);
    if (startTime) {
      const duration = performance.now() - startTime;
      this.metrics.delete(operationName);
      return duration;
    }
    return null;
  }

  logPerformance(operationName, duration, threshold = 1000) {
    if (duration > threshold) {
      console.warn(`[PERFORMANCE] Slow operation: ${operationName} took ${duration.toFixed(2)}ms`);
    } else {
      console.log(`[PERFORMANCE] ${operationName} completed in ${duration.toFixed(2)}ms`);
    }
  }
}

const perfMonitor = new PerformanceMonitor();

/**
 * Enhanced Firestore Query Builder with optimization
 */
class OptimizedFirestoreQuery {
  constructor(collectionPath) {
    this.db = admin.firestore();
    this.collection = this.db.collection(collectionPath);
    this.query = this.collection;
    this.operationName = `query_${collectionPath}`;
  }

  // Add compound index-friendly ordering
  orderBy(field, direction = 'desc') {
    this.query = this.query.orderBy(field, direction);
    return this;
  }

  // Efficient pagination with cursor-based approach
  paginate(limit = 20, lastDocument = null) {
    this.query = this.query.limit(limit);
    if (lastDocument) {
      this.query = this.query.startAfter(lastDocument);
    }
    return this;
  }

  // Optimized filtering with index consideration
  where(field, operator, value) {
    this.query = this.query.where(field, operator, value);
    return this;
  }

  // Execute query with performance monitoring
  async execute() {
    perfMonitor.startTimer(this.operationName);
    
    try {
      const snapshot = await this.query.get();
      const duration = perfMonitor.endTimer(this.operationName);
      
      perfMonitor.logPerformance(this.operationName, duration);
      
      return {
        docs: snapshot.docs,
        size: snapshot.size,
        empty: snapshot.empty,
        lastDocument: snapshot.docs[snapshot.docs.length - 1] || null,
        performance: { duration, docCount: snapshot.size }
      };
    } catch (error) {
      const duration = perfMonitor.endTimer(this.operationName);
      console.error(`[PERFORMANCE] Query failed after ${duration}ms:`, error);
      throw error;
    }
  }

  // Batch operations for better performance
  static async batchWrite(operations) {
    const db = admin.firestore();
    const batch = db.batch();
    
    perfMonitor.startTimer('batch_write');
    
    operations.forEach(({ type, ref, data }) => {
      switch (type) {
        case 'set':
          batch.set(ref, data);
          break;
        case 'update':
          batch.update(ref, data);
          break;
        case 'delete':
          batch.delete(ref);
          break;
      }
    });

    try {
      await batch.commit();
      const duration = perfMonitor.endTimer('batch_write');
      perfMonitor.logPerformance('batch_write', duration);
      return { success: true, operationCount: operations.length };
    } catch (error) {
      const duration = perfMonitor.endTimer('batch_write');
      console.error(`[PERFORMANCE] Batch write failed after ${duration}ms:`, error);
      throw error;
    }
  }
}

/**
 * Optimized query functions for common operations
 */
const OptimizedQueries = {
  // Items near user with efficient geolocation querying
  async getItemsNearLocation(latitude, longitude, radiusKm = 10, limit = 20, lastDoc = null) {
    // Use geohash for efficient location queries (requires implementation)
    // For now, we'll optimize the basic query structure
    const query = new OptimizedFirestoreQuery('items')
      .where('status', '==', 'available')
      .where('location.latitude', '>=', latitude - radiusKm / 111)
      .where('location.latitude', '<=', latitude + radiusKm / 111)
      .orderBy('location.latitude')
      .orderBy('createdAt', 'desc')
      .paginate(limit, lastDoc);

    return await query.execute();
  },

  // User's items with optimized indexing
  async getUserItems(userId, status = null, limit = 20, lastDoc = null) {
    const query = new OptimizedFirestoreQuery('items')
      .where('ownerId', '==', userId);
    
    if (status) {
      query.where('status', '==', status);
    }
    
    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, lastDoc)
      .execute();
  },

  // Optimized transaction history
  async getTransactionHistory(userId, limit = 20, lastDoc = null) {
    // Query transactions where user is either sender or recipient
    // This requires a composite index on [participants, createdAt]
    const query = new OptimizedFirestoreQuery('transactions')
      .where('participants', 'array-contains', userId)
      .orderBy('createdAt', 'desc')
      .paginate(limit, lastDoc);

    return await query.execute();
  },

  // Efficient group discovery with category filtering
  async getGroupsByCategory(category, college = null, limit = 20, lastDoc = null) {
    const query = new OptimizedFirestoreQuery('groups')
      .where('category', '==', category)
      .where('isActive', '==', true);
    
    if (college) {
      query.where('college', '==', college);
    }
    
    return await query
      .orderBy('memberCount', 'desc')
      .orderBy('createdAt', 'desc')
      .paginate(limit, lastDoc)
      .execute();
  },

  // Optimized user search with text indexing considerations
  async searchUsers(college, searchTerm = null, limit = 20, lastDoc = null) {
    let query = new OptimizedFirestoreQuery('users')
      .where('college', '==', college)
      .where('verificationStatus', '==', 'verified');
    
    // For text search, we'd need to implement client-side filtering
    // or use a search service like Algolia
    
    return await query
      .orderBy('trustScore', 'desc')
      .orderBy('createdAt', 'desc')
      .paginate(limit, lastDoc)
      .execute();
  }
};

/**
 * Cache management for frequently accessed data
 */
class OptimizedCache {
  constructor() {
    this.cache = new Map();
    this.ttl = new Map(); // Time to live
    this.maxSize = 1000;
    this.defaultTTL = 5 * 60 * 1000; // 5 minutes
  }

  set(key, value, ttl = this.defaultTTL) {
    // Implement LRU eviction if cache is full
    if (this.cache.size >= this.maxSize && !this.cache.has(key)) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      this.ttl.delete(firstKey);
    }

    this.cache.set(key, value);
    this.ttl.set(key, Date.now() + ttl);
  }

  get(key) {
    const ttlTime = this.ttl.get(key);
    
    if (!ttlTime || Date.now() > ttlTime) {
      // Expired
      this.cache.delete(key);
      this.ttl.delete(key);
      return null;
    }

    return this.cache.get(key);
  }

  delete(key) {
    this.cache.delete(key);
    this.ttl.delete(key);
  }

  clear() {
    this.cache.clear();
    this.ttl.clear();
  }

  // Get cache statistics
  getStats() {
    const now = Date.now();
    let expiredCount = 0;
    
    for (const [key, expireTime] of this.ttl.entries()) {
      if (now > expireTime) {
        expiredCount++;
      }
    }

    return {
      size: this.cache.size,
      maxSize: this.maxSize,
      expired: expiredCount,
      hitRate: this.hitCount / (this.hitCount + this.missCount) || 0
    };
  }

  // Cleanup expired entries
  cleanup() {
    const now = Date.now();
    const expiredKeys = [];

    for (const [key, expireTime] of this.ttl.entries()) {
      if (now > expireTime) {
        expiredKeys.push(key);
      }
    }

    expiredKeys.forEach(key => {
      this.cache.delete(key);
      this.ttl.delete(key);
    });

    return expiredKeys.length;
  }
}

// Global cache instance
const globalCache = new OptimizedCache();

// Cleanup expired cache entries periodically
setInterval(() => {
  const cleaned = globalCache.cleanup();
  if (cleaned > 0) {
    console.log(`[CACHE] Cleaned ${cleaned} expired entries`);
  }
}, 60 * 1000); // Every minute

/**
 * Database index recommendations for optimal performance
 */
const REQUIRED_INDEXES = {
  items: [
    { fields: ['ownerId', 'createdAt'], order: 'DESC' },
    { fields: ['status', 'location.latitude', 'createdAt'], order: 'DESC' },
    { fields: ['category', 'status', 'createdAt'], order: 'DESC' },
    { fields: ['college', 'category', 'status', 'createdAt'], order: 'DESC' },
    { fields: ['tags', 'status', 'createdAt'], order: 'DESC' }
  ],
  transactions: [
    { fields: ['participants', 'createdAt'], order: 'DESC' },
    { fields: ['senderId', 'status', 'createdAt'], order: 'DESC' },
    { fields: ['receiverId', 'status', 'createdAt'], order: 'DESC' }
  ],
  groups: [
    { fields: ['college', 'category', 'isActive', 'memberCount'], order: 'DESC' },
    { fields: ['category', 'isActive', 'createdAt'], order: 'DESC' },
    { fields: ['members', 'isActive'], order: 'ASC' }
  ],
  users: [
    { fields: ['college', 'verificationStatus', 'trustScore'], order: 'DESC' },
    { fields: ['verificationStatus', 'createdAt'], order: 'DESC' }
  ],
  chats: [
    { fields: ['participants', 'lastMessageAt'], order: 'DESC' }
  ],
  notifications: [
    { fields: ['recipientId', 'read', 'createdAt'], order: 'DESC' },
    { fields: ['recipientId', 'type', 'read', 'createdAt'], order: 'DESC' }
  ]
};

/**
 * Performance optimization utilities
 */
const PerformanceUtils = {
  // Generate index creation commands for Firebase CLI
  generateIndexCommands() {
    console.log('\n=== REQUIRED FIRESTORE INDEXES ===\n');
    
    Object.entries(REQUIRED_INDEXES).forEach(([collection, indexes]) => {
      console.log(`Collection: ${collection}`);
      indexes.forEach((index, i) => {
        const fieldsStr = index.fields.join(', ');
        console.log(`  ${i + 1}. Fields: [${fieldsStr}] Order: ${index.order}`);
      });
      console.log('');
    });

    console.log('Run these Firebase CLI commands to create indexes:\n');
    
    Object.entries(REQUIRED_INDEXES).forEach(([collection, indexes]) => {
      indexes.forEach(index => {
        const fieldsParam = index.fields.map(f => `--field-config=${f},${index.order.toLowerCase()}`).join(' ');
        console.log(`firebase firestore:indexes:create --collection-group=${collection} ${fieldsParam}`);
      });
    });
  },

  // Analyze query performance
  async analyzeQueryPerformance(queries) {
    console.log('\n=== QUERY PERFORMANCE ANALYSIS ===\n');
    
    for (const queryInfo of queries) {
      const { name, query } = queryInfo;
      
      try {
        perfMonitor.startTimer(name);
        const result = await query();
        const duration = perfMonitor.endTimer(name);
        
        console.log(`${name}:`);
        console.log(`  Duration: ${duration.toFixed(2)}ms`);
        console.log(`  Result count: ${result.size || result.docs?.length || 'N/A'}`);
        console.log(`  Performance: ${duration < 1000 ? 'GOOD' : duration < 3000 ? 'MODERATE' : 'SLOW'}`);
        console.log('');
      } catch (error) {
        console.error(`${name}: ERROR - ${error.message}`);
      }
    }
  }
};

module.exports = {
  OptimizedFirestoreQuery,
  OptimizedQueries,
  OptimizedCache,
  PerformanceMonitor,
  PerformanceUtils,
  globalCache,
  REQUIRED_INDEXES
};
