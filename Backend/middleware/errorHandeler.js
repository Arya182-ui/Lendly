/**
 * Centralized error handler middleware
 * Standardizes all error responses across the application
 */

class AppError extends Error {
  constructor(message, statusCode, details = null) {
    super(message);
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

// Error response formatter
const formatErrorResponse = (err) => {
  const response = {
    success: false,
    error: err.message || 'An error occurred'
  };

  if (err.details) {
    response.details = err.details;
  }

  // Don't expose stack traces in production
  if (process.env.NODE_ENV !== 'production' && err.stack) {
    response.stack = err.stack;
  }

  return response;
};

// Global error handler middleware
const errorHandler = (err, req, res, next) => {
  // Set default status code
  err.statusCode = err.statusCode || 500;
  err.message = err.message || 'Internal Server Error';

  // Log error for debugging
  console.error('Error:', {
    message: err.message,
    statusCode: err.statusCode,
    path: req.path,
    method: req.method,
    stack: err.stack
  });

  // Handle specific error types
  if (err.name === 'ValidationError') {
    err.statusCode = 400;
    err.message = 'Validation failed';
  }

  if (err.name === 'UnauthorizedError') {
    err.statusCode = 401;
    err.message = 'Unauthorized access';
  }

  if (err.code === 'LIMIT_FILE_SIZE') {
    err.statusCode = 413;
    err.message = 'File size too large';
  }

  if (err.code === 'LIMIT_UNEXPECTED_FILE') {
    err.statusCode = 400;
    err.message = 'Unexpected file upload';
  }

  // Firebase errors
  if (err.code && err.code.startsWith('auth/')) {
    err.statusCode = 401;
    const firebaseErrorMessages = {
      'auth/invalid-email': 'Invalid email address',
      'auth/user-not-found': 'User not found',
      'auth/wrong-password': 'Incorrect password',
      'auth/email-already-in-use': 'Email already in use',
      'auth/weak-password': 'Password is too weak',
      'auth/id-token-expired': 'Session expired, please login again'
    };
    err.message = firebaseErrorMessages[err.code] || 'Authentication error';
  }

  // Firestore errors
  if (err.code && typeof err.code === 'number') {
    if (err.code === 9) { // FAILED_PRECONDITION
      err.statusCode = 500;
      err.message = 'Database index required. Please contact support.';
    }
    if (err.code === 5) { // NOT_FOUND
      err.statusCode = 404;
      err.message = 'Resource not found';
    }
    if (err.code === 7) { // PERMISSION_DENIED
      err.statusCode = 403;
      err.message = 'Permission denied';
    }
  }

  // Send error response
  res.status(err.statusCode).json(formatErrorResponse(err));
};

// 404 handler for undefined routes
const notFoundHandler = (req, res, next) => {
  const error = new AppError(
    `Route ${req.originalUrl} not found`,
    404
  );
  next(error);
};

// Async error wrapper to catch async errors
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

module.exports = {
  AppError,
  errorHandler,
  notFoundHandler,
  asyncHandler,
  formatErrorResponse
};

