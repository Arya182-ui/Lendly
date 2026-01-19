/**
 * Comprehensive Health Check System
 */
const express = require('express');
const admin = require('firebase-admin');
const { CacheManager, redisClient } = require('../utils/cache-manager');
const { Logger } = require('../utils/logger');

const router = express.Router();

/**
 * Health check data structure
 */
let healthStatus = {
  status: 'healthy',
  timestamp: Date.now(),
  uptime: process.uptime(),
  version: process.env.npm_package_version || '1.0.0',
  environment: process.env.NODE_ENV || 'development',
  services: {
    database: { status: 'unknown', latency: null, error: null },
    cache: { status: 'unknown', latency: null, error: null },
    memory: { usage: process.memoryUsage(), limit: null },
    cpu: { usage: process.cpuUsage(), load: null }
  },
  metrics: {
    requests: {
      total: 0,
      success: 0,
      errors: 0,
      avg_response_time: 0
    },
    connections: {
      active: 0,
      total: 0
    }
  }
};

/**
 * Service health checkers
 */
class HealthCheckers {
  static async checkFirestore() {
    const start = Date.now();
    try {
      const db = admin.firestore();
      // Simple read operation to test connection
      await db.collection('_health').doc('check').get();
      
      return {
        status: 'healthy',
        latency: Date.now() - start,
        error: null
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        latency: Date.now() - start,
        error: error.message
      };
    }
  }

  static async checkCache() {
    const start = Date.now();
    try {
      const testKey = '_health_check';
      const testValue = Date.now().toString();
      
      // Test cache set/get
      await CacheManager.set(testKey, testValue, 10);
      const retrieved = await CacheManager.get(testKey);
      
      if (retrieved !== testValue) {
        throw new Error('Cache validation failed');
      }
      
      await CacheManager.delete(testKey);
      
      return {
        status: 'healthy',
        latency: Date.now() - start,
        error: null
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        latency: Date.now() - start,
        error: error.message
      };
    }
  }

  static checkMemory() {
    const usage = process.memoryUsage();
    const totalMemory = require('os').totalmem();
    const usagePercent = (usage.rss / totalMemory) * 100;
    
    return {
      usage,
      total: totalMemory,
      usagePercent: Math.round(usagePercent * 100) / 100,
      status: usagePercent > 90 ? 'critical' : usagePercent > 70 ? 'warning' : 'healthy'
    };
  }

  static checkCPU() {
    const usage = process.cpuUsage();
    const loadAvg = require('os').loadavg();
    
    return {
      usage,
      loadAvg,
      status: loadAvg[0] > 2 ? 'warning' : 'healthy'
    };
  }
}

/**
 * Metrics collector
 */
class MetricsCollector {
  static requests = {
    total: 0,
    success: 0,
    errors: 0,
    responseTimes: []
  };

  static connections = {
    active: 0,
    total: 0
  };

  static recordRequest(success, responseTime) {
    this.requests.total++;
    if (success) {
      this.requests.success++;
    } else {
      this.requests.errors++;
    }
    
    this.requests.responseTimes.push(responseTime);
    
    // Keep only last 1000 response times
    if (this.requests.responseTimes.length > 1000) {
      this.requests.responseTimes = this.requests.responseTimes.slice(-1000);
    }
  }

  static getMetrics() {
    const responseTimes = this.requests.responseTimes;
    const avgResponseTime = responseTimes.length > 0 
      ? responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length 
      : 0;

    return {
      requests: {
        total: this.requests.total,
        success: this.requests.success,
        errors: this.requests.errors,
        successRate: this.requests.total > 0 
          ? Math.round((this.requests.success / this.requests.total) * 100) 
          : 100,
        avgResponseTime: Math.round(avgResponseTime * 100) / 100
      },
      connections: this.connections
    };
  }
}

/**
 * Update health status periodically
 */
async function updateHealthStatus() {
  try {
    const [dbHealth, cacheHealth] = await Promise.all([
      HealthCheckers.checkFirestore(),
      HealthCheckers.checkCache()
    ]);

    const memoryHealth = HealthCheckers.checkMemory();
    const cpuHealth = HealthCheckers.checkCPU();
    const metrics = MetricsCollector.getMetrics();

    // Determine overall status
    let overallStatus = 'healthy';
    if (dbHealth.status === 'unhealthy' || cacheHealth.status === 'unhealthy') {
      overallStatus = 'unhealthy';
    } else if (memoryHealth.status === 'critical' || cpuHealth.status === 'warning') {
      overallStatus = 'degraded';
    }

    healthStatus = {
      status: overallStatus,
      timestamp: Date.now(),
      uptime: Math.round(process.uptime()),
      version: process.env.npm_package_version || '1.0.0',
      environment: process.env.NODE_ENV || 'development',
      services: {
        database: dbHealth,
        cache: cacheHealth,
        memory: memoryHealth,
        cpu: cpuHealth
      },
      metrics
    };

    // Log unhealthy services
    if (overallStatus !== 'healthy') {
      Logger.warn('Health check detected issues', {
        status: overallStatus,
        database: dbHealth.status,
        cache: cacheHealth.status,
        memory: memoryHealth.status,
        cpu: cpuHealth.status
      });
    }

  } catch (error) {
    Logger.error('Health check failed', { error: error.message });
    healthStatus.status = 'unhealthy';
    healthStatus.timestamp = Date.now();
  }
}

// Update health status every 30 seconds
setInterval(updateHealthStatus, 30000);
updateHealthStatus(); // Initial check

/**
 * Routes
 */

// Basic health check
router.get('/health', (req, res) => {
  const status = healthStatus.status === 'healthy' ? 200 : 503;
  res.status(status).json({
    status: healthStatus.status,
    timestamp: healthStatus.timestamp,
    uptime: healthStatus.uptime
  });
});

// Detailed health check
router.get('/health/detailed', (req, res) => {
  const status = healthStatus.status === 'healthy' ? 200 : 503;
  res.status(status).json(healthStatus);
});

// Readiness probe (for Kubernetes)
router.get('/ready', (req, res) => {
  const isReady = healthStatus.services.database.status === 'healthy';
  res.status(isReady ? 200 : 503).json({
    ready: isReady,
    timestamp: Date.now()
  });
});

// Liveness probe (for Kubernetes)
router.get('/alive', (req, res) => {
  res.status(200).json({
    alive: true,
    timestamp: Date.now(),
    uptime: Math.round(process.uptime())
  });
});

// Metrics endpoint (Prometheus compatible)
router.get('/metrics', (req, res) => {
  const metrics = MetricsCollector.getMetrics();
  res.set('Content-Type', 'text/plain');
  res.send(`
# HELP lendly_requests_total Total number of requests
# TYPE lendly_requests_total counter
lendly_requests_total ${metrics.requests.total}

# HELP lendly_requests_success Total number of successful requests
# TYPE lendly_requests_success counter
lendly_requests_success ${metrics.requests.success}

# HELP lendly_requests_errors Total number of failed requests
# TYPE lendly_requests_errors counter
lendly_requests_errors ${metrics.requests.errors}

# HELP lendly_response_time_avg Average response time in milliseconds
# TYPE lendly_response_time_avg gauge
lendly_response_time_avg ${metrics.requests.avgResponseTime}

# HELP lendly_memory_usage Memory usage in bytes
# TYPE lendly_memory_usage gauge
lendly_memory_usage ${healthStatus.services.memory.usage.rss}

# HELP lendly_uptime_seconds Process uptime in seconds
# TYPE lendly_uptime_seconds counter
lendly_uptime_seconds ${healthStatus.uptime}
  `.trim());
});

// Performance test endpoint
router.get('/health/perf', async (req, res) => {
  const start = Date.now();
  
  try {
    // Test database performance
    const dbStart = Date.now();
    await admin.firestore().collection('_health').doc('perf').get();
    const dbTime = Date.now() - dbStart;
    
    // Test cache performance
    const cacheStart = Date.now();
    await CacheManager.set('_perf_test', Date.now(), 5);
    await CacheManager.get('_perf_test');
    const cacheTime = Date.now() - cacheStart;
    
    const totalTime = Date.now() - start;
    
    res.json({
      status: 'ok',
      performance: {
        total: totalTime,
        database: dbTime,
        cache: cacheTime
      }
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      error: error.message,
      performance: {
        total: Date.now() - start
      }
    });
  }
});

module.exports = {
  router,
  MetricsCollector,
  healthStatus
};
