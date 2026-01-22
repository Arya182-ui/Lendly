/**
 * ADVANCED PAGINATION SYSTEM
 * High-Performance Cursor-Based Navigation with Caching
 * 
 * Features:
 * - Cursor-based pagination (eliminates offset issues)
 * - Bi-directional navigation (forward/backward)
 * - Smart prefetching and caching
 * - Real-time count estimation
 * - Memory-efficient large dataset handling
 */

const admin = require('firebase-admin');
const { OptimizedFirestoreQuery, perfMonitor } = require('./advanced-query-optimizer');

class AdvancedPaginationManager {
  constructor() {
    this.cache = new Map();
    this.maxCacheSize = 1000;
    this.defaultPageSize = 20;
    this.prefetchEnabled = true;
  }

  // Generate unique cache key for pagination state
  _generateCacheKey(collection, filters, orderBy, pageSize) {
    const filterString = JSON.stringify(filters || {});
    const orderString = JSON.stringify(orderBy || {});
    return `${collection}_${Buffer.from(filterString + orderString).toString('base64')}_${pageSize}`;
  }

  // Clean cache when it gets too large
  _cleanCache() {
    if (this.cache.size > this.maxCacheSize) {
      const oldestKeys = Array.from(this.cache.keys()).slice(0, Math.floor(this.maxCacheSize * 0.3));
      oldestKeys.forEach(key => this.cache.delete(key));
    }
  }

  /**
   * Get paginated results with advanced features
   * @param {Object} options - Pagination options
   * @param {string} options.collection - Firestore collection name
   * @param {Object} options.filters - Query filters { field: { operator, value } }
   * @param {Object} options.orderBy - Sort order { field, direction }
   * @param {number} options.pageSize - Items per page (default: 20)
   * @param {string} options.cursor - Pagination cursor
   * @param {string} options.direction - 'forward' or 'backward'
   * @param {boolean} options.enableCache - Enable result caching
   * @param {boolean} options.prefetch - Prefetch next page
   * @returns {Promise<Object>} Paginated results with navigation metadata
   */
  async getPaginatedResults(options) {
    const {
      collection,
      filters = {},
      orderBy = { field: 'createdAt', direction: 'desc' },
      pageSize = this.defaultPageSize,
      cursor = null,
      direction = 'forward',
      enableCache = false,
      prefetch = this.prefetchEnabled
    } = options;

    const cacheKey = this._generateCacheKey(collection, filters, orderBy, pageSize);
    const queryId = `paginated_${collection}_${Date.now()}`;

    // Check cache first
    if (enableCache && cursor) {
      const cachedResult = this.cache.get(`${cacheKey}_${cursor}`);
      if (cachedResult) {
        console.log(`🎯 [CACHE_HIT] ${queryId}`);
        return cachedResult;
      }
    }

    try {
      // Build optimized query
      const query = new OptimizedFirestoreQuery(collection);
      
      // Apply filters
      Object.entries(filters).forEach(([field, filterConfig]) => {
        if (typeof filterConfig === 'object' && filterConfig.operator) {
          query.where(field, filterConfig.operator, filterConfig.value);
        } else {
          query.where(field, '==', filterConfig);
        }
      });

      // Apply ordering
      query.orderBy(orderBy.field, orderBy.direction);

      // Apply pagination
      const adjustedPageSize = prefetch ? pageSize + 1 : pageSize;
      
      if (cursor) {
        const cursorDoc = await admin.firestore().doc(cursor).get();
        if (cursorDoc.exists) {
          query.paginate(adjustedPageSize, cursorDoc, direction);
        } else {
          query.paginate(adjustedPageSize, null, direction);
        }
      } else {
        query.paginate(adjustedPageSize, null, direction);
      }

      const result = await query.execute();
      
      // Process results for pagination metadata
      const items = result.data;
      let hasNextPage = false;
      let prefetchedData = null;

      // Handle prefetching logic
      if (prefetch && items.length > pageSize) {
        const prefetchedItem = items.pop();
        prefetchedData = prefetchedItem;
        hasNextPage = true;
      } else {
        hasNextPage = items.length === pageSize;
      }

      // Generate navigation cursors
      const firstCursor = items.length > 0 ? `${collection}/${items[0].id}` : null;
      const lastCursor = items.length > 0 ? `${collection}/${items[items.length - 1].id}` : null;

      // Calculate estimated total (for UI progress indicators)
      const estimatedTotal = await this._estimateTotal(collection, filters);

      // Prepare response
      const response = {
        items,
        pagination: {
          pageSize: items.length,
          requestedPageSize: pageSize,
          hasNextPage,
          hasPreviousPage: !!cursor,
          firstCursor,
          lastCursor,
          estimatedTotal,
          direction
        },
        performance: result.performance,
        queryId,
        cacheKey: enableCache ? cacheKey : null
      };

      // Cache result if enabled
      if (enableCache) {
        this.cache.set(`${cacheKey}_${cursor || 'first'}`, response);
        this._cleanCache();
      }

      // Prefetch next page in background
      if (prefetch && hasNextPage && lastCursor) {
        this._prefetchNextPage(collection, filters, orderBy, pageSize, lastCursor);
      }

      return response;

    } catch (error) {
      console.error(`[PAGINATION_ERROR] ${queryId}:`, error);
      throw new Error(`Pagination failed: ${error.message}`);
    }
  }

  // Background prefetching for smoother navigation
  async _prefetchNextPage(collection, filters, orderBy, pageSize, cursor) {
    try {
      const prefetchOptions = {
        collection,
        filters,
        orderBy,
        pageSize,
        cursor,
        direction: 'forward',
        enableCache: true,
        prefetch: false // Avoid infinite prefetching
      };

      // Run prefetch in background without awaiting
      setTimeout(() => {
        this.getPaginatedResults(prefetchOptions).catch(error => {
          console.warn(`[PREFETCH_FAILED] ${collection}:`, error.message);
        });
      }, 100);

    } catch (error) {
      console.warn(`[PREFETCH_ERROR]:`, error.message);
    }
  }

  // Estimate total count for UI indicators (cached)
  async _estimateTotal(collection, filters) {
    const estimateKey = `count_${collection}_${JSON.stringify(filters)}`;
    
    // Check cache first
    if (this.cache.has(estimateKey)) {
      return this.cache.get(estimateKey);
    }

    try {
      // Use count() query for accurate small datasets
      let query = admin.firestore().collection(collection);
      
      Object.entries(filters).forEach(([field, filterConfig]) => {
        if (typeof filterConfig === 'object' && filterConfig.operator) {
          query = query.where(field, filterConfig.operator, filterConfig.value);
        } else {
          query = query.where(field, '==', filterConfig);
        }
      });

      const countSnapshot = await query.count().get();
      const total = countSnapshot.data().count;

      // Cache for 5 minutes
      this.cache.set(estimateKey, total);
      setTimeout(() => this.cache.delete(estimateKey), 300000);

      return total;
    } catch (error) {
      console.warn(`[COUNT_ESTIMATE_FAILED]:`, error.message);
      return null;
    }
  }

  // Get multiple pages at once for performance
  async getBatchedPages(options, pageCount = 3) {
    const results = [];
    let currentCursor = options.cursor;

    for (let i = 0; i < pageCount; i++) {
      try {
        const pageResult = await this.getPaginatedResults({
          ...options,
          cursor: currentCursor,
          enableCache: true,
          prefetch: false
        });

        results.push(pageResult);
        currentCursor = pageResult.pagination.lastCursor;

        // Stop if no more pages
        if (!pageResult.pagination.hasNextPage) {
          break;
        }
      } catch (error) {
        console.error(`[BATCH_PAGE_ERROR] Page ${i}:`, error);
        break;
      }
    }

    return {
      pages: results,
      totalItems: results.reduce((sum, page) => sum + page.items.length, 0),
      lastCursor: results[results.length - 1]?.pagination.lastCursor || null
    };
  }

  // Search with pagination across multiple fields
  async searchWithPagination(options) {
    const {
      collection,
      searchTerm,
      searchFields = ['name', 'description'],
      filters = {},
      pageSize = this.defaultPageSize,
      cursor = null
    } = options;

    // For now, we'll implement client-side filtering
    // In production, consider using Algolia or similar for full-text search
    
    const allResults = await this.getPaginatedResults({
      collection,
      filters,
      orderBy: { field: 'createdAt', direction: 'desc' },
      pageSize: pageSize * 3, // Get more to account for filtering
      cursor,
      enableCache: false
    });

    // Client-side search filtering
    const searchLower = searchTerm.toLowerCase();
    const filteredItems = allResults.items.filter(item => {
      return searchFields.some(field => {
        const fieldValue = item[field];
        return fieldValue && fieldValue.toLowerCase().includes(searchLower);
      });
    }).slice(0, pageSize);

    return {
      items: filteredItems,
      pagination: {
        ...allResults.pagination,
        pageSize: filteredItems.length,
        searchTerm,
        searchFields
      },
      performance: allResults.performance
    };
  }

  // Clear all cached data
  clearCache() {
    this.cache.clear();
    console.log('🗑️ [CACHE_CLEARED] All pagination cache cleared');
  }

  // Get cache statistics
  getCacheStats() {
    return {
      size: this.cache.size,
      maxSize: this.maxCacheSize,
      hitRate: this._calculateHitRate(),
      memoryUsage: this._estimateMemoryUsage()
    };
  }

  _calculateHitRate() {
    // This would need to be tracked over time in a real implementation
    return 'Not tracked';
  }

  _estimateMemoryUsage() {
    // Rough estimation - in production, use process.memoryUsage()
    return `~${Math.round(this.cache.size * 0.1)}KB`;
  }
}

// ================== PAGINATION HELPERS ==================

/**
 * Extract pagination parameters from HTTP request
 */
function extractPaginationParams(req) {
  const {
    page = 1,
    limit = 20,
    cursor = null,
    direction = 'forward',
    sort_by = 'createdAt',
    sort_order = 'desc'
  } = req.query;

  return {
    pageSize: Math.min(parseInt(limit), 100), // Cap at 100 items
    cursor,
    direction,
    orderBy: {
      field: sort_by,
      direction: sort_order.toLowerCase() === 'asc' ? 'asc' : 'desc'
    }
  };
}

/**
 * Format pagination response for API
 */
function formatPaginatedResponse(data, baseUrl, req) {
  const { items, pagination } = data;
  
  // Generate navigation URLs
  const buildUrl = (cursor, direction) => {
    const params = new URLSearchParams(req.query);
    params.set('cursor', cursor || '');
    params.set('direction', direction);
    return `${baseUrl}?${params.toString()}`;
  };

  return {
    success: true,
    data: items,
    pagination: {
      total_estimated: pagination.estimatedTotal,
      page_size: pagination.pageSize,
      has_next: pagination.hasNextPage,
      has_previous: pagination.hasPreviousPage,
      first_cursor: pagination.firstCursor,
      last_cursor: pagination.lastCursor
    },
    links: {
      self: buildUrl(req.query.cursor, req.query.direction || 'forward'),
      next: pagination.hasNextPage ? buildUrl(pagination.lastCursor, 'forward') : null,
      previous: pagination.hasPreviousPage ? buildUrl(pagination.firstCursor, 'backward') : null
    },
    performance: data.performance
  };
}

// Global pagination manager instance
const globalPaginationManager = new AdvancedPaginationManager();

module.exports = {
  AdvancedPaginationManager,
  extractPaginationParams,
  formatPaginatedResponse,
  globalPaginationManager
};
