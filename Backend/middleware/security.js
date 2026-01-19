/**
 * Comprehensive Security Middleware Suite
 * Integrates all security features with centralized configuration
 */

const { SECURITY_HEADERS, SAFE_ERROR_MESSAGES, SECURITY_FEATURES, INPUT_SECURITY } = require('../config/security');

/**
 * Apply security headers to all responses
 */
const securityHeaders = (req, res, next) => {
  if (!SECURITY_FEATURES.ENABLE_SECURITY_HEADERS) {
    return next();
  }

  // Apply all security headers
  Object.entries(SECURITY_HEADERS).forEach(([header, value]) => {
    res.setHeader(header, value);
  });

  // Remove server information
  res.removeHeader('X-Powered-By');
  res.removeHeader('Server');

  next();
};

/**
 * Enhanced input sanitization with suspicious pattern detection
 */
const advancedSanitization = (req, res, next) => {
  if (!SECURITY_FEATURES.ENABLE_INPUT_SANITIZATION) {
    return next();
  }

  const sanitizeValue = (value, path = '') => {
    if (typeof value === 'string') {
      // Check for suspicious patterns
      for (const pattern of INPUT_SECURITY.SUSPICIOUS_PATTERNS) {
        if (pattern.test(value)) {
          console.warn('[SECURITY] Suspicious pattern detected:', {
            path,
            pattern: pattern.toString(),
            value: value.substring(0, 100), // First 100 chars only
            clientIp: req.ip,
            timestamp: new Date().toISOString()
          });
          
          // Could reject the request or sanitize more aggressively
          // For now, we'll continue with standard sanitization
        }
      }

      // Apply HTML escape patterns
      let sanitized = value;
      Object.entries(INPUT_SECURITY.HTML_ESCAPE_PATTERNS).forEach(([char, escaped]) => {
        sanitized = sanitized.replace(new RegExp(char, 'g'), escaped);
      });

      return sanitized;
    }
    
    if (Array.isArray(value)) {
      // Limit array size
      if (value.length > INPUT_SECURITY.MAX_ARRAY_LENGTH) {
        console.warn('[SECURITY] Array too long, truncating:', {
          path,
          originalLength: value.length,
          maxLength: INPUT_SECURITY.MAX_ARRAY_LENGTH,
          clientIp: req.ip
        });
        value = value.slice(0, INPUT_SECURITY.MAX_ARRAY_LENGTH);
      }
      
      return value.map((item, index) => sanitizeValue(item, `${path}[${index}]`));
    }
    
    if (value && typeof value === 'object') {
      // Limit object depth and size
      if (path.split('.').length > INPUT_SECURITY.MAX_OBJECT_DEPTH) {
        console.warn('[SECURITY] Object too deep, stopping sanitization:', {
          path,
          maxDepth: INPUT_SECURITY.MAX_OBJECT_DEPTH,
          clientIp: req.ip
        });
        return value;
      }

      const sanitized = {};
      Object.keys(value).forEach(key => {
        // Sanitize key names too
        const sanitizedKey = sanitizeValue(key, `${path}.key`);
        sanitized[sanitizedKey] = sanitizeValue(value[key], `${path}.${key}`);
      });
      return sanitized;
    }
    
    return value;
  };

  // Sanitize request body
  if (req.body && typeof req.body === 'object') {
    req.body = sanitizeValue(req.body, 'body');
  }

  // Sanitize query parameters
  if (req.query && typeof req.query === 'object') {
    req.query = sanitizeValue(req.query, 'query');
  }

  next();
};

/**
 * Request size limiter to prevent large payload attacks
 */
const requestSizeLimiter = (req, res, next) => {
  const contentLength = parseInt(req.get('content-length') || '0');
  const maxSize = 15 * 1024 * 1024; // 15MB max (including file uploads)

  if (contentLength > maxSize) {
    console.warn('[SECURITY] Request too large:', {
      contentLength,
      maxSize,
      clientIp: req.ip,
      path: req.path,
      method: req.method
    });

    return res.status(413).json({
      error: SAFE_ERROR_MESSAGES.FILE_TOO_LARGE,
      code: 'REQUEST_TOO_LARGE'
    });
  }

  next();
};

/**
 * Suspicious activity detector
 */
const suspiciousActivityDetector = (req, res, next) => {
  if (!SECURITY_FEATURES.ENABLE_SUSPICIOUS_ACTIVITY_DETECTION) {
    return next();
  }

  const clientIp = req.ip || req.connection.remoteAddress;
  const userAgent = req.headers['user-agent'];
  const path = req.path;
  const method = req.method;

  // Detect suspicious patterns
  const suspiciousIndicators = [];

  // Check for automated tools
  if (userAgent && /bot|crawler|spider|scraper|curl|wget|python|postman|insomnia/i.test(userAgent)) {
    suspiciousIndicators.push('automated_tool');
  }

  // Check for no user agent
  if (!userAgent) {
    suspiciousIndicators.push('no_user_agent');
  }

  // Check for unusual paths
  if (/\.(php|asp|jsp|cgi|pl)$/i.test(path)) {
    suspiciousIndicators.push('unusual_extension');
  }

  // Check for common attack paths
  if (/\/\.\.|%2e%2e|%252e|%c0%ae|%c1%9c/i.test(path)) {
    suspiciousIndicators.push('path_traversal');
  }

  // Check for SQL injection patterns in query
  if (req.query && Object.values(req.query).some(value => 
    /('|(\\r)|(\\n)|(\\t)|(%0a)|(%0d)|(%08)|(%09))/i.test(String(value)) ||
    /(union|select|insert|delete|update|drop|create|alter|exec|script)/i.test(String(value))
  )) {
    suspiciousIndicators.push('sql_injection_pattern');
  }

  // Log suspicious activity
  if (suspiciousIndicators.length > 0) {
    console.warn('[SECURITY] Suspicious activity detected:', {
      clientIp,
      userAgent,
      path,
      method,
      indicators: suspiciousIndicators,
      timestamp: new Date().toISOString()
    });

    // Could implement automated blocking here
    // For now, we'll just log and continue
  }

  next();
};

/**
 * Content type validator
 */
const contentTypeValidator = (req, res, next) => {
  const contentType = req.get('content-type');
  
  if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
    if (!contentType) {
      return res.status(400).json({
        error: SAFE_ERROR_MESSAGES.INVALID_INPUT,
        code: 'MISSING_CONTENT_TYPE'
      });
    }

    // Only allow specific content types
    const allowedTypes = [
      'application/json',
      'multipart/form-data',
      'application/x-www-form-urlencoded'
    ];

    const baseContentType = contentType.split(';')[0].trim();
    if (!allowedTypes.includes(baseContentType)) {
      console.warn('[SECURITY] Invalid content type:', {
        contentType,
        allowedTypes,
        clientIp: req.ip,
        path: req.path
      });

      return res.status(400).json({
        error: SAFE_ERROR_MESSAGES.INVALID_INPUT,
        code: 'INVALID_CONTENT_TYPE'
      });
    }
  }

  next();
};

/**
 * Request method validator
 */
const methodValidator = (allowedMethods) => {
  return (req, res, next) => {
    if (!allowedMethods.includes(req.method)) {
      return res.status(405).json({
        error: 'Method not allowed',
        code: 'METHOD_NOT_ALLOWED',
        allowed: allowedMethods
      });
    }
    next();
  };
};

/**
 * Safe error handler that doesn't leak internal details
 */
const safeErrorHandler = (err, req, res, next) => {
  // Log the actual error internally
  console.error('[ERROR] Internal error:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
    clientIp: req.ip,
    uid: req.uid || 'anonymous',
    timestamp: new Date().toISOString()
  });

  // Determine safe error message to send to client
  let statusCode = err.statusCode || err.status || 500;
  let errorMessage = SAFE_ERROR_MESSAGES.SERVER_ERROR;
  let errorCode = 'INTERNAL_ERROR';

  // Map specific error types to safe messages
  if (err.code) {
    if (err.code.startsWith('auth/')) {
      statusCode = 401;
      errorMessage = SAFE_ERROR_MESSAGES.AUTHENTICATION_FAILED;
      errorCode = 'AUTH_ERROR';
    } else if (err.code.startsWith('firestore/')) {
      statusCode = 500;
      errorMessage = SAFE_ERROR_MESSAGES.SERVER_ERROR;
      errorCode = 'DATABASE_ERROR';
    }
  }

  // Handle specific error types
  if (err.name === 'ValidationError') {
    statusCode = 400;
    errorMessage = SAFE_ERROR_MESSAGES.VALIDATION_FAILED;
    errorCode = 'VALIDATION_ERROR';
  } else if (err.name === 'MulterError') {
    statusCode = 400;
    if (err.code === 'LIMIT_FILE_SIZE') {
      errorMessage = SAFE_ERROR_MESSAGES.FILE_TOO_LARGE;
      errorCode = 'FILE_TOO_LARGE';
    } else if (err.code === 'LIMIT_FILE_COUNT') {
      errorMessage = 'Too many files';
      errorCode = 'TOO_MANY_FILES';
    } else {
      errorMessage = SAFE_ERROR_MESSAGES.INVALID_INPUT;
      errorCode = 'FILE_UPLOAD_ERROR';
    }
  }

  // Send safe error response
  res.status(statusCode).json({
    success: false,
    error: errorMessage,
    code: errorCode,
    timestamp: new Date().toISOString(),
    // Only include details in development
    ...(process.env.NODE_ENV === 'development' && { details: err.message })
  });
};

module.exports = {
  securityHeaders,
  advancedSanitization,
  requestSizeLimiter,
  suspiciousActivityDetector,
  contentTypeValidator,
  methodValidator,
  safeErrorHandler
};
