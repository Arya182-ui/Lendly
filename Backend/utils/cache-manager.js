/**
 * Cache Management System
 * Supports both in-memory and Redis caching
 */
const { memoryCache } = require('./db-performance');

// Redis client (optional - falls back to memory cache if not available)
let redisClient = null;

try {
  const redis = require('redis');
  if (process.env.REDIS_URL) {
    redisClient = redis.createClient({ url: process.env.REDIS_URL });
    redisClient.on('error', (err) => {
      console.warn('Redis error:', err.message);
      redisClient = null; // Fall back to memory cache
    });
    redisClient.connect();
  }
} catch (err) {
  console.warn('Redis not available, using memory cache');
}

class CacheManager {
  static async get(key, fallbackFunction = null) {
    try {
      // Try Redis first if available
      if (redisClient && redisClient.isReady) {
        const cached = await redisClient.get(key);
        if (cached) {
          return JSON.parse(cached);
        }
      }
      
      // Fall back to memory cache
      const memoryCached = memoryCache.get(key);
      if (memoryCached) {
        return memoryCached;
      }
      
      // If no cache hit and fallback function provided
      if (fallbackFunction) {
        const result = await fallbackFunction();
        await this.set(key, result);
        return result;
      }
      
      return null;
    } catch (err) {
      console.error('Cache get error:', err);
      if (fallbackFunction) {
        return await fallbackFunction();
      }
      return null;
    }
  }

  static async set(key, value, ttlSeconds = 300) {
    try {
      const data = JSON.stringify(value);
      
      // Set in Redis if available
      if (redisClient && redisClient.isReady) {
        await redisClient.setEx(key, ttlSeconds, data);
      }
      
      // Always set in memory cache as backup
      memoryCache.set(key, value, ttlSeconds * 1000);
    } catch (err) {
      console.error('Cache set error:', err);
    }
  }

  static async delete(key) {
    try {
      if (redisClient && redisClient.isReady) {
        await redisClient.del(key);
      }
      memoryCache.delete(key);
    } catch (err) {
      console.error('Cache delete error:', err);
    }
  }

  static async clear(pattern = null) {
    try {
      if (redisClient && redisClient.isReady) {
        if (pattern) {
          const keys = await redisClient.keys(pattern);
          if (keys.length > 0) {
            await redisClient.del(keys);
          }
        } else {
          await redisClient.flushDb();
        }
      }
      
      if (!pattern) {
        memoryCache.clear();
      }
    } catch (err) {
      console.error('Cache clear error:', err);
    }
  }

  static async mget(keys) {
    try {
      const results = {};
      
      if (redisClient && redisClient.isReady) {
        const values = await redisClient.mGet(keys);
        keys.forEach((key, index) => {
          if (values[index]) {
            results[key] = JSON.parse(values[index]);
          }
        });
        return results;
      }
      
      // Fall back to memory cache
      keys.forEach(key => {
        const value = memoryCache.get(key);
        if (value) {
          results[key] = value;
        }
      });
      
      return results;
    } catch (err) {
      console.error('Cache mget error:', err);
      return {};
    }
  }

  static async mset(keyValuePairs, ttlSeconds = 300) {
    try {
      if (redisClient && redisClient.isReady) {
        const pipeline = redisClient.multi();
        Object.entries(keyValuePairs).forEach(([key, value]) => {
          pipeline.setEx(key, ttlSeconds, JSON.stringify(value));
        });
        await pipeline.exec();
      }
      
      // Set in memory cache
      Object.entries(keyValuePairs).forEach(([key, value]) => {
        memoryCache.set(key, value, ttlSeconds * 1000);
      });
    } catch (err) {
      console.error('Cache mset error:', err);
    }
  }

  // Cache key generators for consistency
  static generateKey(prefix, ...parts) {
    return `lendly:${prefix}:${parts.join(':')}`;
  }

  static userProfileKey(uid) {
    return this.generateKey('user:profile', uid);
  }

  static userItemsKey(uid, page = 1) {
    return this.generateKey('user:items', uid, page);
  }

  static userStatsKey(uid) {
    return this.generateKey('user:stats', uid);
  }

  static itemsKey(filters = {}) {
    const filterStr = Object.keys(filters)
      .sort()
      .map(key => `${key}:${filters[key]}`)
      .join('-');
    return this.generateKey('items', filterStr || 'all');
  }

  static homeDataKey(uid) {
    return this.generateKey('home', uid);
  }

  static groupKey(groupId) {
    return this.generateKey('group', groupId);
  }

  static chatMessagesKey(chatId, page = 1) {
    return this.generateKey('chat:messages', chatId, page);
  }
}

// Cache warming functions
class CacheWarmer {
  static async warmUserCache(uid) {
    const keys = [
      CacheManager.userProfileKey(uid),
      CacheManager.userStatsKey(uid),
      CacheManager.userItemsKey(uid)
    ];
    
    // This would typically fetch and cache the data
    // Implementation depends on your specific data fetching logic
  }

  static async warmPopularItems() {
    // Cache popular/trending items
    const key = CacheManager.itemsKey({ popular: true });
    // Implementation would fetch and cache popular items
  }
}

module.exports = {
  CacheManager,
  CacheWarmer,
  redisClient
};
