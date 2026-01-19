/**
 * Health Check and Monitoring System for Lendly Backend
 */
const admin = require('firebase-admin');
const os = require('os');

// Health status
let healthStatus = {
  status: 'starting',
  uptime: 0,
  startTime: Date.now(),
  checks: {}
};

/**
 * Check Firestore connectivity
 */
async function checkFirestore() {
  const start = Date.now();
  try {
    await admin.firestore().collection('_health').doc('ping').get();
    return {
      status: 'healthy',
      latency: Date.now() - start
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message,
      latency: Date.now() - start
    };
  }
}

/**
 * Check Firebase Auth
 */
async function checkAuth() {
  const start = Date.now();
  try {
    // Simple check - verify we can list users (limit 1)
    await admin.auth().listUsers(1);
    return {
      status: 'healthy',
      latency: Date.now() - start
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message,
      latency: Date.now() - start
    };
  }
}

/**
 * Check Firebase Storage
 */
async function checkStorage() {
  const start = Date.now();
  try {
    const bucket = admin.storage().bucket();
    await bucket.exists();
    return {
      status: 'healthy',
      latency: Date.now() - start
    };
  } catch (error) {
    return {
      status: 'unhealthy',
      error: error.message,
      latency: Date.now() - start
    };
  }
}

/**
 * Get system metrics
 */
function getSystemMetrics() {
  const memUsage = process.memoryUsage();
  const cpus = os.cpus();
  
  return {
    memory: {
      heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
      heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
      rss: Math.round(memUsage.rss / 1024 / 1024),
      external: Math.round(memUsage.external / 1024 / 1024),
      unit: 'MB'
    },
    cpu: {
      cores: cpus.length,
      model: cpus[0]?.model,
      loadAvg: os.loadavg()
    },
    os: {
      platform: os.platform(),
      release: os.release(),
      uptime: Math.round(os.uptime()),
      totalMemory: Math.round(os.totalmem() / 1024 / 1024),
      freeMemory: Math.round(os.freemem() / 1024 / 1024)
    }
  };
}

/**
 * Get application metrics
 */
function getAppMetrics() {
  // Ensure startTime is valid, fallback to current time if corrupted
  const validStartTime = (typeof healthStatus.startTime === 'number' && !isNaN(healthStatus.startTime)) 
    ? healthStatus.startTime 
    : Date.now();
  
  // Update healthStatus.startTime if it was corrupted
  if (healthStatus.startTime !== validStartTime) {
    healthStatus.startTime = validStartTime;
  }

  return {
    uptime: Math.round((Date.now() - validStartTime) / 1000),
    startTime: new Date(validStartTime).toISOString(),
    nodeVersion: process.version,
    env: process.env.NODE_ENV || 'development'
  };
}

/**
 * Run all health checks
 */
async function runHealthChecks() {
  const [firestore, auth, storage] = await Promise.all([
    checkFirestore(),
    checkAuth(),
    checkStorage()
  ]);

  const checks = { firestore, auth, storage };
  
  // Determine overall status
  const statuses = Object.values(checks).map(c => c.status);
  let overallStatus = 'healthy';
  
  if (statuses.includes('unhealthy')) {
    overallStatus = 'unhealthy';
  } else if (statuses.some(s => s !== 'healthy')) {
    overallStatus = 'degraded';
  }

  // Update health status object without overwriting startTime
  const validStartTime = (typeof healthStatus.startTime === 'number' && !isNaN(healthStatus.startTime)) 
    ? healthStatus.startTime 
    : Date.now();

  Object.assign(healthStatus, {
    status: overallStatus,
    timestamp: new Date().toISOString(),
    uptime: Math.round((Date.now() - validStartTime) / 1000),
    checks,
    system: getSystemMetrics(),
    app: getAppMetrics()
  });

  return healthStatus;
}

/**
 * Express routes for health checks
 */
function createHealthRoutes(app) {
  // Basic health check - fast response
  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString()
    });
  });

  // Liveness probe - is the server running?
  app.get('/health/live', (req, res) => {
    const validStartTime = (typeof healthStatus.startTime === 'number' && !isNaN(healthStatus.startTime)) 
      ? healthStatus.startTime 
      : Date.now();

    res.json({
      status: 'alive',
      uptime: Math.round((Date.now() - validStartTime) / 1000)
    });
  });

  // Readiness probe - can the server handle requests?
  app.get('/health/ready', async (req, res) => {
    try {
      const firestoreCheck = await checkFirestore();
      
      if (firestoreCheck.status === 'healthy') {
        res.json({
          status: 'ready',
          checks: { firestore: firestoreCheck }
        });
      } else {
        res.status(503).json({
          status: 'not_ready',
          checks: { firestore: firestoreCheck }
        });
      }
    } catch (error) {
      res.status(503).json({
        status: 'not_ready',
        error: error.message
      });
    }
  });

  // Detailed health check
  app.get('/health/detailed', async (req, res) => {
    try {
      const health = await runHealthChecks();
      const statusCode = health.status === 'healthy' ? 200 : 
                         health.status === 'degraded' ? 200 : 503;
      res.status(statusCode).json(health);
    } catch (error) {
      res.status(500).json({
        status: 'error',
        error: error.message
      });
    }
  });

  // Metrics endpoint (for monitoring)
  app.get('/metrics', (req, res) => {
    res.json({
      timestamp: new Date().toISOString(),
      ...getSystemMetrics(),
      ...getAppMetrics()
    });
  });
}

/**
 * Start periodic health checks
 */
function startHealthMonitoring(intervalMs = 60000) {
  // Initial check
  runHealthChecks().catch(console.error);
  
  // Periodic checks
  setInterval(() => {
    runHealthChecks().catch(console.error);
  }, intervalMs);
}

module.exports = {
  runHealthChecks,
  createHealthRoutes,
  startHealthMonitoring,
  getSystemMetrics,
  getAppMetrics,
  checkFirestore,
  checkAuth,
  checkStorage
};

