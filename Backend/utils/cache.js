/**
 * In-Memory Caching System for Lendly Backend
 * Reduces database queries and improves response times
 */

class CacheEntry {
  constructor(data, ttlMs) {
    this.data = data;
    this.createdAt = Date.now();
    this.expiresAt = Date.now() + ttlMs;
    this.hits = 0;
  }

  isExpired() {
    return Date.now() > this.expiresAt;
  }

  touch() {
    this.hits++;
    return this.data;
  }
}

class LRUCache {
  constructor(options = {}) {
    this.maxSize = options.maxSize || 1000;
    this.defaultTTL = options.defaultTTL || 5 * 60 * 1000; // 5 minutes
    this.cache = new Map();
    this.stats = {
      hits: 0,
      misses: 0,
      evictions: 0
    };
  }

  /**
   * Get value from cache
   */
  get(key) {
    const entry = this.cache.get(key);
    
    if (!entry) {
      this.stats.misses++;
      return null;
    }

    if (entry.isExpired()) {
      this.cache.delete(key);
      this.stats.misses++;
      return null;
    }

    // Move to end (most recently used)
    this.cache.delete(key);
    this.cache.set(key, entry);
    this.stats.hits++;
    
    return entry.touch();
  }

  /**
   * Set value in cache
   */
  set(key, value, ttlMs = this.defaultTTL) {
    // Remove old entry if exists
    if (this.cache.has(key)) {
      this.cache.delete(key);
    }

    // Evict if at max size
    while (this.cache.size >= this.maxSize) {
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      this.stats.evictions++;
    }

    this.cache.set(key, new CacheEntry(value, ttlMs));
  }

  /**
   * Check if key exists and is not expired
   */
  has(key) {
    const entry = this.cache.get(key);
    if (!entry) return false;
    if (entry.isExpired()) {
      this.cache.delete(key);
      return false;
    }
    return true;
  }

  /**
   * Delete key from cache
   */
  delete(key) {
    return this.cache.delete(key);
  }

  /**
   * Delete keys matching a pattern
   */
  deletePattern(pattern) {
    const regex = new RegExp(pattern);
    let deleted = 0;
    
    for (const key of this.cache.keys()) {
      if (regex.test(key)) {
        this.cache.delete(key);
        deleted++;
      }
    }
    
    return deleted;
  }

  /**
   * Clear all cache entries
   */
  clear() {
    this.cache.clear();
    this.stats = { hits: 0, misses: 0, evictions: 0 };
  }

  /**
   * Get cache statistics
   */
  getStats() {
    const total = this.stats.hits + this.stats.misses;
    return {
      ...this.stats,
      size: this.cache.size,
      maxSize: this.maxSize,
      hitRate: total > 0 ? (this.stats.hits / total * 100).toFixed(2) + '%' : '0%'
    };
  }

  /**
   * Cleanup expired entries
   */
  cleanup() {
    const now = Date.now();
    let cleaned = 0;
    
    for (const [key, entry] of this.cache.entries()) {
      if (entry.isExpired()) {
        this.cache.delete(key);
        cleaned++;
      }
    }
    
    return cleaned;
  }
}

// Cache TTL presets (in milliseconds)
const TTL = {
  VERY_SHORT: 30 * 1000,      // 30 seconds
  SHORT: 60 * 1000,           // 1 minute
  MEDIUM: 5 * 60 * 1000,      // 5 minutes
  LONG: 15 * 60 * 1000,       // 15 minutes
  VERY_LONG: 60 * 60 * 1000,  // 1 hour
};

// Global cache instance
const cache = new LRUCache({
  maxSize: 2000,
  defaultTTL: TTL.MEDIUM
});

// Start periodic cleanup
setInterval(() => {
  const cleaned = cache.cleanup();
  if (cleaned > 0) {
    console.log(`Cache cleanup: removed ${cleaned} expired entries`);
  }
}, 5 * 60 * 1000); // Every 5 minutes

/**
 * Cache key generators for consistent key naming
 */
const CacheKeys = {
  user: (uid) => `user:${uid}`,
  userProfile: (uid) => `user:profile:${uid}`,
  userPublicProfile: (uid) => `user:public:${uid}`,
  userItems: (uid) => `user:items:${uid}`,
  userStats: (uid) => `user:stats:${uid}`,
  userFriends: (uid) => `user:friends:${uid}`,
  item: (itemId) => `item:${itemId}`,
  items: (page, limit) => `items:${page}:${limit}`,
  itemsNearby: (lat, lng, radius) => `items:nearby:${lat}:${lng}:${radius}`,
  groups: () => 'groups:all',
  group: (groupId) => `group:${groupId}`,
  groupMembers: (groupId) => `group:members:${groupId}`,
  newArrivals: () => 'home:new-arrivals',
  summary: (uid) => `home:summary:${uid}`,
  leaderboard: () => 'impact:leaderboard',
  personalImpact: (uid) => `impact:personal:${uid}`,
  wallet: (uid) => `wallet:${uid}`,
  notifications: (uid) => `notifications:${uid}`,
};

/**
 * Cache middleware for Express routes
 */
function cacheMiddleware(keyGenerator, ttl = TTL.MEDIUM) {
  return (req, res, next) => {
    const key = typeof keyGenerator === 'function' 
      ? keyGenerator(req) 
      : keyGenerator;
    
    const cached = cache.get(key);
    if (cached) {
      return res.json(cached);
    }

    // Store original json method
    const originalJson = res.json.bind(res);
    
    // Override json method to cache response
    res.json = (data) => {
      if (res.statusCode === 200) {
        cache.set(key, data, ttl);
      }
      return originalJson(data);
    };

    next();
  };
}

/**
 * Invalidate cache for a user's data
 */
function invalidateUserCache(uid) {
  cache.deletePattern(`user:.*:${uid}`);
  cache.delete(CacheKeys.userProfile(uid));
  cache.delete(CacheKeys.userPublicProfile(uid));
  cache.delete(CacheKeys.userItems(uid));
  cache.delete(CacheKeys.userStats(uid));
  cache.delete(CacheKeys.userFriends(uid));
  cache.delete(CacheKeys.summary(uid));
  cache.delete(CacheKeys.wallet(uid));
  cache.delete(CacheKeys.notifications(uid));
}

/**
 * Invalidate cache for an item
 */
function invalidateItemCache(itemId) {
  cache.delete(CacheKeys.item(itemId));
  cache.deletePattern('items:');
  cache.delete(CacheKeys.newArrivals());
}

/**
 * Invalidate cache for a group
 */
function invalidateGroupCache(groupId) {
  cache.delete(CacheKeys.group(groupId));
  cache.delete(CacheKeys.groupMembers(groupId));
  cache.delete(CacheKeys.groups());
}

module.exports = {
  cache,
  LRUCache,
  CacheEntry,
  TTL,
  CacheKeys,
  cacheMiddleware,
  invalidateUserCache,
  invalidateItemCache,
  invalidateGroupCache
};

