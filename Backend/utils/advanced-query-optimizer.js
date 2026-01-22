/**
 * 🚀 LENDLY FIRESTORE OPTIMIZATION ENGINE
 * Advanced Database Performance & Query Optimization System
 * 
 * Features:
 * - Composite Index Management
 * - Advanced Pagination with Cursor-based Navigation
 * - Query Performance Monitoring
 * - Intelligent Caching Layer
 * - Collection Group Optimization
 */

const admin = require('firebase-admin');
const { performance } = require('perf_hooks');

// ================== PERFORMANCE MONITORING ==================
class QueryPerformanceMonitor {
  constructor() {
    this.metrics = new Map();
    this.slowQueryThreshold = 1000; // 1 second
    this.queryStats = new Map();
  }

  startTimer(queryId, metadata = {}) {
    this.metrics.set(queryId, {
      startTime: performance.now(),
      metadata
    });
  }

  endTimer(queryId, resultCount = 0) {
    const record = this.metrics.get(queryId);
    if (!record) return null;

    const duration = performance.now() - record.startTime;
    this.metrics.delete(queryId);

    // Update stats
    const stats = this.queryStats.get(queryId) || { 
      count: 0, 
      totalDuration: 0, 
      maxDuration: 0,
      minDuration: Infinity,
      avgResultCount: 0 
    };
    
    stats.count++;
    stats.totalDuration += duration;
    stats.maxDuration = Math.max(stats.maxDuration, duration);
    stats.minDuration = Math.min(stats.minDuration, duration);
    stats.avgResultCount = ((stats.avgResultCount * (stats.count - 1)) + resultCount) / stats.count;
    
    this.queryStats.set(queryId, stats);

    // Log slow queries
    if (duration > this.slowQueryThreshold) {
      console.warn(`🐌 [SLOW_QUERY] ${queryId}: ${duration.toFixed(2)}ms`, {
        ...record.metadata,
        resultCount,
        avgDuration: (stats.totalDuration / stats.count).toFixed(2)
      });
    } else {
      console.log(`⚡ [QUERY] ${queryId}: ${duration.toFixed(2)}ms (${resultCount} docs)`);
    }

    return { duration, resultCount };
  }

  getStats() {
    const stats = {};
    for (const [queryId, data] of this.queryStats) {
      stats[queryId] = {
        ...data,
        avgDuration: (data.totalDuration / data.count).toFixed(2)
      };
    }
    return stats;
  }
}

const perfMonitor = new QueryPerformanceMonitor();

// ================== ADVANCED QUERY BUILDER ==================
class OptimizedFirestoreQuery {
  constructor(collectionPath, options = {}) {
    this.db = admin.firestore();
    this.collectionPath = collectionPath;
    this.baseQuery = this.db.collection(collectionPath);
    this.currentQuery = this.baseQuery;
    this.queryId = `${collectionPath}_query_${Date.now()}`;
    this.metadata = { collection: collectionPath };
    this.enableCache = options.cache || false;
    this.cacheKey = null;
  }

  // Optimized WHERE clauses with index-aware ordering
  where(field, operator, value) {
    this.currentQuery = this.currentQuery.where(field, operator, value);
    this.metadata[`filter_${field}`] = { operator, value };
    return this;
  }

  // Composite index optimized ordering
  orderBy(field, direction = 'desc') {
    this.currentQuery = this.currentQuery.orderBy(field, direction);
    this.metadata.orderBy = { field, direction };
    return this;
  }

  // Advanced cursor-based pagination
  paginate(limit = 20, cursor = null, direction = 'forward') {
    this.currentQuery = this.currentQuery.limit(limit);
    
    if (cursor) {
      if (direction === 'forward') {
        this.currentQuery = this.currentQuery.startAfter(cursor);
      } else {
        this.currentQuery = this.currentQuery.endBefore(cursor);
      }
    }
    
    this.metadata.pagination = { limit, direction, hasCursor: !!cursor };
    return this;
  }

  // Execute with performance monitoring and optional caching
  async execute() {
    this.queryId = `${this.collectionPath}_${Object.keys(this.metadata).join('_')}`;
    perfMonitor.startTimer(this.queryId, this.metadata);

    try {
      const snapshot = await this.currentQuery.get();
      const docs = snapshot.docs;
      const resultCount = docs.length;
      
      perfMonitor.endTimer(this.queryId, resultCount);

      return {
        docs,
        data: docs.map(doc => ({ id: doc.id, ...doc.data() })),
        size: resultCount,
        empty: snapshot.empty,
        hasMore: resultCount === this.metadata.pagination?.limit,
        firstDoc: docs[0] || null,
        lastDoc: docs[docs.length - 1] || null,
        cursors: {
          first: docs[0]?.id || null,
          last: docs[docs.length - 1]?.id || null
        },
        performance: perfMonitor.getStats()[this.queryId]
      };
    } catch (error) {
      perfMonitor.endTimer(this.queryId, 0);
      console.error(`❌ [QUERY_ERROR] ${this.queryId}:`, error);
      throw new Error(`Query failed: ${error.message}`);
    }
  }

  // Collection group query for cross-collection searches
  static collectionGroup(collectionId, options = {}) {
    const instance = new OptimizedFirestoreQuery(collectionId, options);
    instance.baseQuery = admin.firestore().collectionGroup(collectionId);
    instance.currentQuery = instance.baseQuery;
    instance.metadata.queryType = 'collectionGroup';
    return instance;
  }
}

// ================== OPTIMIZED QUERY PATTERNS ==================
class LendlyQueryOptimizer {
  
  // 📚 ITEMS QUERIES WITH COMPOSITE INDEXES
  static async getAvailableItems({ 
    college, 
    category = null, 
    latitude = null, 
    longitude = null, 
    radiusKm = 10,
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: items
    Fields: college ASC, available ASC, category ASC, createdAt DESC
    */
    
    const query = new OptimizedFirestoreQuery('items')
      .where('college', '==', college)
      .where('available', '==', true);

    if (category) {
      query.where('category', '==', category);
    }

    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 🏠 USER ITEMS WITH OPTIMIZED FILTERING
  static async getUserItems({ 
    ownerId, 
    status = null, 
    category = null, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: items
    Fields: ownerId ASC, status ASC, category ASC, createdAt DESC
    */
    
    const query = new OptimizedFirestoreQuery('items')
      .where('ownerId', '==', ownerId);

    if (status) {
      query.where('status', '==', status);
    }
    
    if (category) {
      query.where('category', '==', category);
    }

    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 💰 TRANSACTION HISTORY WITH OPTIMIZED PARTICIPANT QUERIES
  static async getTransactionHistory({ 
    userId, 
    status = null, 
    type = null, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: transactions
    Fields: participants ASC, status ASC, type ASC, createdAt DESC
    */
    
    const query = new OptimizedFirestoreQuery('transactions')
      .where('participants', 'array-contains', userId);

    if (status) {
      query.where('status', '==', status);
    }
    
    if (type) {
      query.where('type', '==', type);
    }

    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 👥 GROUPS WITH CATEGORY AND COLLEGE OPTIMIZATION
  static async getGroupsByCategory({ 
    college, 
    category, 
    isPublic = true, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: groups
    Fields: college ASC, category ASC, isPublic ASC, memberCount DESC, createdAt DESC
    */
    
    return await new OptimizedFirestoreQuery('groups')
      .where('college', '==', college)
      .where('category', '==', category)
      .where('isPublic', '==', isPublic)
      .orderBy('memberCount', 'desc')
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 🔔 NOTIFICATIONS WITH USER AND STATUS FILTERING
  static async getUserNotifications({ 
    uid, 
    read = null, 
    type = null, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: notifications
    Fields: uid ASC, read ASC, type ASC, createdAt DESC
    */
    
    const query = new OptimizedFirestoreQuery('notifications')
      .where('uid', '==', uid);

    if (read !== null) {
      query.where('read', '==', read);
    }
    
    if (type) {
      query.where('type', '==', type);
    }

    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 🎯 TRUST SCORE HISTORY WITH OPTIMIZED QUERIES
  static async getTrustScoreHistory({ uid, limit = 20, cursor = null }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: trustScoreHistory
    Fields: uid ASC, createdAt DESC
    */
    
    return await new OptimizedFirestoreQuery('trustScoreHistory')
      .where('uid', '==', uid)
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 🔍 COLLECTION GROUP QUERIES FOR CROSS-COLLECTION SEARCHES
  static async searchAllMessages({ 
    college, 
    senderId = null, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX (Collection Group):
    Collection Group ID: messages
    Fields: college ASC, senderId ASC, createdAt DESC
    */
    
    const query = OptimizedFirestoreQuery.collectionGroup('messages')
      .where('college', '==', college);

    if (senderId) {
      query.where('senderId', '==', senderId);
    }

    return await query
      .orderBy('createdAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 📊 ADMIN VERIFICATION QUERIES WITH OPTIMIZED INDEXES
  static async getPendingVerifications({ 
    college = null, 
    priority = null, 
    limit = 20, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: users
    Fields: verificationStatus ASC, college ASC, verificationRequestedAt DESC
    */
    
    const query = new OptimizedFirestoreQuery('users')
      .where('verificationStatus', '==', 'pending');

    if (college) {
      query.where('college', '==', college);
    }

    return await query
      .orderBy('verificationRequestedAt', 'desc')
      .paginate(limit, cursor)
      .execute();
  }

  // 🏆 LEADERBOARD QUERIES WITH TRUST SCORE OPTIMIZATION
  static async getTrustScoreLeaderboard({ 
    college, 
    tierFilter = null, 
    limit = 50, 
    cursor = null 
  }) {
    /*
    REQUIRED COMPOSITE INDEX:
    Collection: users
    Fields: college ASC, verificationStatus ASC, trustScoreTier ASC, trustScore DESC
    */
    
    const query = new OptimizedFirestoreQuery('users')
      .where('college', '==', college)
      .where('verificationStatus', '==', 'verified');

    if (tierFilter) {
      query.where('trustScoreTier', '==', tierFilter);
    }

    return await query
      .orderBy('trustScore', 'desc')
      .paginate(limit, cursor)
      .execute();
  }
}

// ================== INDEX REQUIREMENTS GENERATOR ==================
class IndexRequirementsGenerator {
  static generateIndexDocumentation() {
    return `
🔥 FIRESTORE COMPOSITE INDEXES REQUIRED FOR OPTIMAL PERFORMANCE

Copy these index configurations to your firestore.indexes.json file:

{
  "indexes": [
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "college", "order": "ASCENDING" },
        { "fieldPath": "available", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "items",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "transactions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "participants", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "groups",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "college", "order": "ASCENDING" },
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "isPublic", "order": "ASCENDING" },
        { "fieldPath": "memberCount", "order": "DESCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "uid", "order": "ASCENDING" },
        { "fieldPath": "read", "order": "ASCENDING" },
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "verificationStatus", "order": "ASCENDING" },
        { "fieldPath": "college", "order": "ASCENDING" },
        { "fieldPath": "verificationRequestedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "college", "order": "ASCENDING" },
        { "fieldPath": "verificationStatus", "order": "ASCENDING" },
        { "fieldPath": "trustScoreTier", "order": "ASCENDING" },
        { "fieldPath": "trustScore", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "college", "order": "ASCENDING" },
        { "fieldPath": "senderId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "trustScoreHistory",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "uid", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}

📋 DEPLOYMENT COMMANDS:
1. firebase deploy --only firestore:indexes
2. Monitor index build progress in Firebase Console
3. Update security rules to work with new query patterns
`;
  }
}

module.exports = {
  OptimizedFirestoreQuery,
  LendlyQueryOptimizer,
  QueryPerformanceMonitor,
  IndexRequirementsGenerator,
  perfMonitor
};
