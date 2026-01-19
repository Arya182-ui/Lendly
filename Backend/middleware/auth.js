/**
 * Authentication and Security Middleware
 */
const admin = require('firebase-admin');

/**
 * Request timeout middleware to prevent hanging requests
 */
const requestTimeout = (timeout = 30000) => {
  return (req, res, next) => {
    // Set timeout for the request
    req.setTimeout(timeout, () => {
      if (!res.headersSent) {
        res.status(408).json({ 
          error: 'Request timeout',
          message: 'Request took too long to process'
        });
      }
    });
    
    // Set timeout for the response
    res.setTimeout(timeout, () => {
      if (!res.headersSent) {
        res.status(408).json({ 
          error: 'Response timeout',
          message: 'Response took too long to send'
        });
      }
    });
    
    next();
  };
};

/**
 * Enhanced Rate Limiter with endpoint-specific limits and memory management
 * Includes protection against file upload abuse and API endpoints
 */
const rateLimitStore = new Map();
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute
const RATE_LIMIT_MAX = 100; // 100 requests per minute
const MAX_STORE_SIZE = 10000; // Prevent memory exhaustion

// Endpoint-specific rate limits
const ENDPOINT_LIMITS = {
  '/auth/verify-student': { max: 3, windowMs: 60 * 60 * 1000 }, // 3 per hour
  '/auth/report-issue': { max: 5, windowMs: 60 * 60 * 1000 }, // 5 per hour
  '/user/upload': { max: 10, windowMs: 60 * 60 * 1000 }, // 10 per hour
  '/chat': { max: 200, windowMs: 60 * 1000 }, // 200 per minute for chat
  '/items': { max: 50, windowMs: 60 * 1000 }, // 50 per minute for browsing
  'default': { max: RATE_LIMIT_MAX, windowMs: RATE_LIMIT_WINDOW }
};

const rateLimit = (options = {}) => {
  return (req, res, next) => {
    const clientId = req.ip || req.connection.remoteAddress || 'unknown';
    const endpoint = req.route?.path || req.path;
    const now = Date.now();
    
    // Get endpoint-specific limits
    const limits = ENDPOINT_LIMITS[endpoint] || options || ENDPOINT_LIMITS.default;
    const maxRequests = limits.max;
    const windowMs = limits.windowMs;
    
    // Create unique key for client + endpoint combination
    const key = `${clientId}:${endpoint}`;
    
    // Prevent memory exhaustion
    if (rateLimitStore.size > MAX_STORE_SIZE) {
      // Remove oldest 25% of entries
      const entries = Array.from(rateLimitStore.entries())
        .sort(([,a], [,b]) => a.startTime - b.startTime)
        .slice(0, Math.floor(MAX_STORE_SIZE * 0.25));
      
      entries.forEach(([key]) => rateLimitStore.delete(key));
    }
    
    if (!rateLimitStore.has(key)) {
      rateLimitStore.set(key, { count: 1, startTime: now, endpoint });
      return next();
    }
    
    const record = rateLimitStore.get(key);
    
    // Reset if window has passed
    if (now - record.startTime > windowMs) {
      rateLimitStore.set(key, { count: 1, startTime: now, endpoint });
      return next();
    }
    
    // Increment and check
    record.count++;
    if (record.count > maxRequests) {
      console.warn(`[SECURITY] Rate limit exceeded for ${clientId} on ${endpoint}:`, {
        count: record.count,
        maxRequests,
        endpoint,
        ip: req.ip
      });
      
      return res.status(429).json({ 
        error: 'Too many requests. Please try again later.',
        retryAfter: Math.ceil((record.startTime + windowMs - now) / 1000),
        endpoint: endpoint
      });
    }
    
    next();
  };
};

// Enhanced cleanup with better memory management
setInterval(() => {
  const now = Date.now();
  let cleaned = 0;
  
  for (const [key, record] of rateLimitStore.entries()) {
    // Use endpoint-specific window or default
    const endpoint = record.endpoint || 'default';
    const windowMs = ENDPOINT_LIMITS[endpoint]?.windowMs || RATE_LIMIT_WINDOW;
    
    if (now - record.startTime > windowMs * 2) {
      rateLimitStore.delete(key);
      cleaned++;
    }
  }
  
  if (cleaned > 0) {
    console.log(`[RATE_LIMIT] Cleaned ${cleaned} expired entries, current size: ${rateLimitStore.size}`);
  }
}, RATE_LIMIT_WINDOW);

/**
 * Enhanced authentication middleware with security logging and token refresh detection
 * Includes protection against token replay attacks and suspicious activity detection
 */
const authenticateUser = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  const clientIp = req.ip || req.connection.remoteAddress;
  const userAgent = req.headers['user-agent'];
  
  // Enhanced security logging
  console.log('[AUTH] Request received:', {
    path: req.path,
    method: req.method,
    hasAuthHeader: !!authHeader,
    clientIp,
    userAgent: userAgent?.substring(0, 100), // Truncate for logs
    timestamp: new Date().toISOString()
  });
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    console.warn('[AUTH] Missing or invalid authorization header:', { clientIp, path: req.path });
    return res.status(401).json({ 
      error: 'No authentication token provided',
      code: 'AUTH_TOKEN_MISSING'
    });
  }
  
  const token = authHeader.split('Bearer ')[1];
  
  // Basic token validation
  if (!token || token.length < 100 || token.length > 4096) {
    console.warn('[AUTH] Invalid token format:', { 
      tokenLength: token?.length || 0,
      clientIp,
      path: req.path
    });
    return res.status(401).json({ 
      error: 'Invalid token format',
      code: 'AUTH_TOKEN_INVALID_FORMAT'
    });
  }
  
  try {
    // Verify Firebase ID token with enhanced options
    const decoded = await admin.auth().verifyIdToken(token, true); // checkRevoked = true
    
    // Check token freshness (tokens older than 1 hour should be refreshed)
    const tokenAge = Date.now() / 1000 - decoded.iat;
    const TOKEN_REFRESH_THRESHOLD = 3600; // 1 hour
    
    if (tokenAge > TOKEN_REFRESH_THRESHOLD) {
      console.info('[AUTH] Token is stale, should be refreshed:', { 
        uid: decoded.uid,
        tokenAge: Math.floor(tokenAge),
        threshold: TOKEN_REFRESH_THRESHOLD
      });
      
      // Add header to suggest token refresh but don't block request
      res.set('X-Token-Refresh-Suggested', 'true');
    }
    
    // Enhanced user object with security context
    req.user = {
      ...decoded,
      clientIp,
      userAgent,
      tokenAge,
      isTokenFresh: tokenAge <= TOKEN_REFRESH_THRESHOLD
    };
    req.uid = decoded.uid;
    
    console.log('[AUTH] Token verified successfully:', { 
      uid: decoded.uid,
      tokenAge: Math.floor(tokenAge),
      email: decoded.email?.substring(0, 20) + '...' // Partially masked email
    });
    
    next();
  } catch (err) {
    // Enhanced error logging with security context
    console.error('[AUTH] Token verification failed:', {
      error: err.message,
      code: err.code,
      clientIp,
      path: req.path,
      userAgent: userAgent?.substring(0, 100),
      timestamp: new Date().toISOString()
    });
    
    // Classify error types for better client handling
    let errorCode = 'AUTH_TOKEN_INVALID';
    let statusCode = 401;
    
    if (err.code === 'auth/id-token-expired') {
      errorCode = 'AUTH_TOKEN_EXPIRED';
    } else if (err.code === 'auth/id-token-revoked') {
      errorCode = 'AUTH_TOKEN_REVOKED';
      statusCode = 403; // Forbidden for revoked tokens
    } else if (err.code === 'auth/invalid-id-token') {
      errorCode = 'AUTH_TOKEN_MALFORMED';
    }
    
    return res.status(statusCode).json({ 
      error: 'Authentication failed',
      code: errorCode,
      details: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
  }
};

/**
 * Optional authentication - doesn't fail if no token
 * Useful for endpoints that work differently for logged in vs anonymous users
 */
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }
  
  const token = authHeader.split('Bearer ')[1];
  
  try {
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded;
    req.uid = decoded.uid;
  } catch (err) {
    // Token invalid, but continue anyway
  }
  
  next();
};

/**
 * Validate required body fields
 */
const validateBody = (requiredFields) => {
  return (req, res, next) => {
    const missing = [];
    const invalid = [];
    
    for (const field of requiredFields) {
      if (req.body[field] === undefined || req.body[field] === null) {
        missing.push(field);
      } else if (typeof req.body[field] === 'string' && req.body[field].trim() === '') {
        invalid.push(`${field} cannot be empty`);
      }
    }
    
    if (missing.length > 0) {
      return res.status(400).json({ 
        error: `Missing required fields: ${missing.join(', ')}` 
      });
    }
    
    if (invalid.length > 0) {
      return res.status(400).json({ 
        error: invalid.join(', ') 
      });
    }
    
    next();
  };
};

/**
 * Validate required query parameters
 */
const validateQuery = (requiredParams) => {
  return (req, res, next) => {
    const missing = [];
    
    for (const param of requiredParams) {
      if (!req.query[param]) {
        missing.push(param);
      }
    }
    
    if (missing.length > 0) {
      return res.status(400).json({ 
        error: `Missing required parameters: ${missing.join(', ')}` 
      });
    }
    
    next();
  };
};

/**
 * Sanitize string input to prevent XSS
 */
const sanitizeInput = (str) => {
  if (typeof str !== 'string') return str;
  return str
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');
};

/**
 * Sanitize all string fields in request body
 */
const sanitizeBody = (req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    for (const key of Object.keys(req.body)) {
      if (typeof req.body[key] === 'string') {
        req.body[key] = sanitizeInput(req.body[key]);
      }
    }
  }
  next();
};

/**
 * Error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  console.error('Error:', err);
  
  // Firebase auth errors
  if (err.code && err.code.startsWith('auth/')) {
    return res.status(401).json({ error: 'Authentication failed' });
  }
  
  // Firestore errors
  if (err.code && err.code.startsWith('firestore/')) {
    return res.status(500).json({ error: 'Database error' });
  }
  
  // Request timeout errors
  if (err.code === 'ETIMEDOUT' || err.code === 'ECONNABORTED') {
    return res.status(408).json({ error: 'Request timeout' });
  }
  
  // Connection errors
  if (err.code === 'ECONNREFUSED' || err.code === 'ENOTFOUND') {
    return res.status(503).json({ error: 'Service unavailable' });
  }
  
  // Default error
  res.status(err.status || 500).json({ 
    error: err.message || 'Internal server error' 
  });
};

/**
 * Token refresh helper - validates refresh token and provides new ID token
 */
const refreshToken = async (refreshToken) => {
  try {
    // Note: This would typically integrate with Firebase Auth REST API
    // For now, we'll validate the concept and log the need for refresh
    console.log('[AUTH] Token refresh requested');
    
    // In production, implement Firebase Auth REST API call:
    // POST https://securetoken.googleapis.com/v1/token?key=<API_KEY>
    // with refresh_token in body
    
    return {
      success: false,
      error: 'Token refresh not fully implemented - use Firebase SDK on client'
    };
  } catch (err) {
    console.error('[AUTH] Token refresh failed:', err);
    throw new Error('Token refresh failed');
  }
};

/**
 * Enhanced request logging middleware with security context
 */
const requestLogger = (req, res, next) => {
  const start = Date.now();
  const clientIp = req.ip || req.connection.remoteAddress;
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    const logLevel = res.statusCode >= 400 ? 'WARN' : 'INFO';
    const uid = req.uid || 'anonymous';
    
    console.log(`[${logLevel}] ${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms [${uid}] [${clientIp}]`);
    
    // Log suspicious patterns
    if (res.statusCode === 429 || duration > 10000) {
      console.warn('[SECURITY] Suspicious request pattern:', {
        method: req.method,
        path: req.originalUrl,
        statusCode: res.statusCode,
        duration,
        clientIp,
        uid
      });
    }
  });
  
  next();
};

module.exports = {
  rateLimit,
  authenticateUser,
  optionalAuth,
  validateBody,
  validateQuery,
  sanitizeInput,
  sanitizeBody,
  errorHandler,
  requestLogger,
  requestTimeout,
  refreshToken,
  ENDPOINT_LIMITS
};

