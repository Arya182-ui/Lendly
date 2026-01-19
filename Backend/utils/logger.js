/**
 * Enhanced Logging and Error Handling System
 */
const fs = require('fs');
const path = require('path');

// Ensure logs directory exists
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

class Logger {
  static levels = {
    ERROR: 0,
    WARN: 1,
    INFO: 2,
    DEBUG: 3
  };

  static colors = {
    ERROR: '\x1b[31m', // Red
    WARN: '\x1b[33m',  // Yellow
    INFO: '\x1b[36m',  // Cyan
    DEBUG: '\x1b[37m', // White
    RESET: '\x1b[0m'
  };

  static currentLevel = process.env.LOG_LEVEL 
    ? this.levels[process.env.LOG_LEVEL.toUpperCase()] 
    : this.levels.INFO;

  static formatMessage(level, message, meta = {}) {
    const timestamp = new Date().toISOString();
    const metaStr = Object.keys(meta).length > 0 ? JSON.stringify(meta) : '';
    return `[${timestamp}] [${level}] ${message} ${metaStr}`.trim();
  }

  static log(level, message, meta = {}) {
    if (this.levels[level] > this.currentLevel) return;

    const formattedMessage = this.formatMessage(level, message, meta);
    
    // Console output with colors
    console.log(
      `${this.colors[level]}${formattedMessage}${this.colors.RESET}`
    );

    // Write to file (async, non-blocking)
    this.writeToFile(level, formattedMessage);
  }

  static writeToFile(level, message) {
    try {
      const date = new Date().toISOString().split('T')[0];
      const filename = path.join(logsDir, `${date}.log`);
      
      fs.appendFile(filename, message + '\n', (err) => {
        if (err) console.error('Failed to write to log file:', err);
      });

      // Write errors to separate error log
      if (level === 'ERROR') {
        const errorFilename = path.join(logsDir, `${date}-error.log`);
        fs.appendFile(errorFilename, message + '\n', (err) => {
          if (err) console.error('Failed to write to error log file:', err);
        });
      }
    } catch (err) {
      console.error('Logging error:', err);
    }
  }

  static error(message, meta = {}) {
    this.log('ERROR', message, meta);
  }

  static warn(message, meta = {}) {
    this.log('WARN', message, meta);
  }

  static info(message, meta = {}) {
    this.log('INFO', message, meta);
  }

  static debug(message, meta = {}) {
    this.log('DEBUG', message, meta);
  }

  // HTTP request logging
  static logRequest(req, res, duration) {
    const meta = {
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      contentLength: req.get('Content-Length') || 0
    };

    if (res.statusCode >= 400) {
      this.warn('HTTP Request Failed', meta);
    } else if (duration > 2000) {
      this.warn('Slow HTTP Request', meta);
    } else {
      this.info('HTTP Request', meta);
    }
  }

  // Database operation logging
  static logDatabaseOperation(operation, collection, duration, error = null) {
    const meta = {
      operation,
      collection,
      duration: `${duration}ms`
    };

    if (error) {
      meta.error = error.message;
      this.error('Database Operation Failed', meta);
    } else if (duration > 1000) {
      this.warn('Slow Database Operation', meta);
    } else {
      this.debug('Database Operation', meta);
    }
  }
}

/**
 * Enhanced Error Classes
 */
class AppError extends Error {
  constructor(message, statusCode = 500, code = null) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    
    Error.captureStackTrace(this, this.constructor);
  }
}

class ValidationError extends AppError {
  constructor(message, field = null) {
    super(message, 400, 'VALIDATION_ERROR');
    this.field = field;
  }
}

class NotFoundError extends AppError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'NOT_FOUND');
  }
}

class AuthenticationError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'AUTHENTICATION_ERROR');
  }
}

class AuthorizationError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403, 'AUTHORIZATION_ERROR');
  }
}

class DatabaseError extends AppError {
  constructor(message = 'Database operation failed', originalError = null) {
    super(message, 500, 'DATABASE_ERROR');
    this.originalError = originalError;
  }
}

class RateLimitError extends AppError {
  constructor(message = 'Rate limit exceeded') {
    super(message, 429, 'RATE_LIMIT_ERROR');
  }
}

/**
 * Global Error Handler
 */
const globalErrorHandler = (err, req, res, next) => {
  // Log the error
  Logger.error('Unhandled Error', {
    message: err.message,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });

  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';

  // Handle known errors
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      code: err.code,
      ...(isDevelopment && { stack: err.stack })
    });
  }

  // Handle specific error types
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      error: 'Validation failed',
      details: err.details
    });
  }

  if (err.code === 'ECONNABORTED' || err.code === 'ETIMEDOUT') {
    return res.status(408).json({
      success: false,
      error: 'Request timeout'
    });
  }

  if (err.code === 'ECONNREFUSED') {
    return res.status(503).json({
      success: false,
      error: 'Service temporarily unavailable'
    });
  }

  // Firebase errors
  if (err.code && err.code.startsWith('auth/')) {
    return res.status(401).json({
      success: false,
      error: 'Authentication failed'
    });
  }

  // Default error response
  res.status(500).json({
    success: false,
    error: isDevelopment ? err.message : 'Internal server error',
    ...(isDevelopment && { stack: err.stack })
  });
};

/**
 * Async error wrapper
 */
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Process-level error handlers
 */
process.on('uncaughtException', (err) => {
  Logger.error('Uncaught Exception', {
    message: err.message,
    stack: err.stack
  });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  Logger.error('Unhandled Rejection', {
    reason: reason?.message || reason,
    promise: promise.toString()
  });
});

// Graceful shutdown handler
process.on('SIGTERM', () => {
  Logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

module.exports = {
  Logger,
  AppError,
  ValidationError,
  NotFoundError,
  AuthenticationError,
  AuthorizationError,
  DatabaseError,
  RateLimitError,
  globalErrorHandler,
  asyncHandler
};
