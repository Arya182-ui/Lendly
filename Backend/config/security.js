/**
 * Centralized Security Configuration for Lendly Backend
 * Contains all security-related constants and configurations
 */

// Rate Limiting Configuration
const RATE_LIMITS = {
  // General API rate limits
  DEFAULT: { max: 100, windowMs: 60 * 1000 }, // 100 per minute
  
  // Authentication endpoints
  AUTH_GENERAL: { max: 50, windowMs: 60 * 1000 }, // 50 per minute
  AUTH_LOGIN: { max: 10, windowMs: 60 * 1000 }, // 10 per minute
  AUTH_REGISTER: { max: 5, windowMs: 60 * 1000 }, // 5 per minute
  AUTH_REFRESH: { max: 10, windowMs: 60 * 1000 }, // 10 per minute
  AUTH_LOGOUT: { max: 20, windowMs: 60 * 1000 }, // 20 per minute
  
  // Sensitive operations
  STUDENT_VERIFICATION: { max: 3, windowMs: 60 * 60 * 1000 }, // 3 per hour
  ISSUE_REPORTING: { max: 5, windowMs: 60 * 60 * 1000 }, // 5 per hour
  FILE_UPLOAD: { max: 10, windowMs: 60 * 60 * 1000 }, // 10 per hour
  
  // Resource access
  ITEMS_BROWSE: { max: 50, windowMs: 60 * 1000 }, // 50 per minute
  SEARCH: { max: 30, windowMs: 60 * 1000 }, // 30 per minute
  
  // Real-time features
  CHAT: { max: 200, windowMs: 60 * 1000 }, // 200 per minute
  NOTIFICATIONS: { max: 100, windowMs: 60 * 1000 }, // 100 per minute
  
  // Admin operations
  ADMIN: { max: 200, windowMs: 60 * 1000 } // 200 per minute for admin
};

// Socket.IO Security Configuration
const SOCKET_SECURITY = {
  MAX_CONNECTIONS_PER_IP: 5,
  MAX_EVENTS_PER_MINUTE: 100,
  RATE_WINDOW_MS: 60 * 1000, // 1 minute
  CONNECTION_TIMEOUT: 30 * 1000, // 30 seconds
  MAX_MESSAGE_LENGTH: 5000,
  MAX_ROOM_ID_LENGTH: 100,
  MAX_CONCURRENT_ROOMS: 50
};

// File Upload Security Configuration
const FILE_UPLOAD_SECURITY = {
  MAX_FILE_SIZE: 5 * 1024 * 1024, // 5MB
  MAX_FIELD_SIZE: 1024 * 1024, // 1MB
  MAX_FIELD_NAME_SIZE: 100,
  MAX_FIELDS: 10,
  MAX_FILES: 1,
  
  ALLOWED_MIME_TYPES: [
    'image/jpeg',
    'image/png', 
    'image/gif',
    'application/pdf'
  ],
  
  VALID_EXTENSIONS: {
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/gif': ['gif'],
    'application/pdf': ['pdf']
  },
  
  MAX_FILENAME_LENGTH: 255,
  
  // Forbidden filename patterns
  FORBIDDEN_FILENAME_PATTERNS: /[<>:"|?*\x00-\x1f]/,
  
  // File content validation (magic numbers)
  MAGIC_NUMBERS: {
    'image/jpeg': [0xFF, 0xD8, 0xFF],
    'image/png': [0x89, 0x50, 0x4E, 0x47],
    'image/gif': [0x47, 0x49, 0x46, 0x38],
    'application/pdf': [0x25, 0x50, 0x44, 0x46] // %PDF
  }
};

// Authentication Security Configuration
const AUTH_SECURITY = {
  TOKEN_REFRESH_THRESHOLD: 3600, // 1 hour in seconds
  MAX_TOKEN_AGE: 86400, // 24 hours in seconds
  MIN_TOKEN_LENGTH: 100,
  MAX_TOKEN_LENGTH: 4096,
  
  // Password requirements (for future implementations)
  MIN_PASSWORD_LENGTH: 8,
  REQUIRE_UPPERCASE: true,
  REQUIRE_LOWERCASE: true,
  REQUIRE_NUMBERS: true,
  REQUIRE_SYMBOLS: false,
  
  // Session security
  MAX_CONCURRENT_SESSIONS: 5,
  SESSION_TIMEOUT: 24 * 60 * 60 * 1000 // 24 hours
};

// Input Validation Security
const INPUT_SECURITY = {
  MAX_STRING_LENGTH: 10000,
  MAX_ARRAY_LENGTH: 1000,
  MAX_OBJECT_DEPTH: 10,
  
  // Text content limits
  MAX_MESSAGE_LENGTH: 5000,
  MAX_DESCRIPTION_LENGTH: 2000,
  MAX_NAME_LENGTH: 100,
  MAX_TITLE_LENGTH: 200,
  
  // Sanitization patterns
  HTML_ESCAPE_PATTERNS: {
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
    '`': '&#x60;',
    '=': '&#x3D;'
  },
  
  // Dangerous patterns to detect
  SUSPICIOUS_PATTERNS: [
    /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
    /javascript:/gi,
    /on\w+\s*=/gi,
    /data:text\/html/gi,
    /vbscript:/gi
  ]
};

// Security Headers Configuration
const SECURITY_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY', 
  'X-XSS-Protection': '1; mode=block',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
  'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; media-src 'self'; object-src 'none'; child-src 'none'; worker-src 'self'; frame-ancestors 'none'; form-action 'self'; base-uri 'self';"
};

// Memory Management Configuration
const MEMORY_LIMITS = {
  MAX_RATE_LIMIT_STORE_SIZE: 10000,
  MAX_CACHE_SIZE: 50000,
  MAX_SOCKET_STORE_SIZE: 1000,
  CLEANUP_INTERVAL: 60 * 1000, // 1 minute
  MEMORY_WARNING_THRESHOLD: 512 * 1024 * 1024 // 512MB
};

// Logging and Monitoring Configuration
const MONITORING = {
  LOG_LEVELS: ['ERROR', 'WARN', 'INFO', 'DEBUG'],
  MAX_LOG_MESSAGE_LENGTH: 1000,
  LOG_RETENTION_DAYS: 30,
  
  // Suspicious activity thresholds
  SUSPICIOUS_THRESHOLDS: {
    FAILED_LOGINS: 5,
    RATE_LIMIT_HITS: 10,
    LARGE_FILE_UPLOADS: 3,
    RAPID_REQUESTS: 50,
    INVALID_TOKENS: 10
  },
  
  // Performance thresholds
  PERFORMANCE_THRESHOLDS: {
    SLOW_REQUEST_MS: 5000,
    MEMORY_USAGE_MB: 512,
    CPU_USAGE_PERCENT: 80,
    RESPONSE_TIME_P95_MS: 2000
  }
};

// Error Messages (avoid revealing internal details)
const SAFE_ERROR_MESSAGES = {
  AUTHENTICATION_FAILED: 'Authentication failed',
  AUTHORIZATION_FAILED: 'Access denied',
  RATE_LIMIT_EXCEEDED: 'Too many requests. Please try again later.',
  INVALID_INPUT: 'Invalid input provided',
  FILE_TOO_LARGE: 'File size exceeds limit',
  INVALID_FILE_TYPE: 'Invalid file type',
  SERVER_ERROR: 'Internal server error',
  SERVICE_UNAVAILABLE: 'Service temporarily unavailable',
  VALIDATION_FAILED: 'Input validation failed',
  TOKEN_EXPIRED: 'Authentication token has expired',
  TOKEN_INVALID: 'Invalid authentication token'
};

// Feature Flags for Security Features
const SECURITY_FEATURES = {
  ENABLE_RATE_LIMITING: true,
  ENABLE_REQUEST_LOGGING: true,
  ENABLE_INPUT_SANITIZATION: true,
  ENABLE_FILE_VALIDATION: true,
  ENABLE_TOKEN_REFRESH_CHECK: true,
  ENABLE_SUSPICIOUS_ACTIVITY_DETECTION: true,
  ENABLE_SECURITY_HEADERS: true,
  ENABLE_SOCKET_RATE_LIMITING: true,
  ENABLE_MEMORY_MONITORING: true,
  ENABLE_PERFORMANCE_MONITORING: true
};

module.exports = {
  RATE_LIMITS,
  SOCKET_SECURITY,
  FILE_UPLOAD_SECURITY,
  AUTH_SECURITY,
  INPUT_SECURITY,
  SECURITY_HEADERS,
  MEMORY_LIMITS,
  MONITORING,
  SAFE_ERROR_MESSAGES,
  SECURITY_FEATURES
};
