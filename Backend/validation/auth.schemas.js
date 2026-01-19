const Joi = require('joi');
const { commonSchemas } = require('../middleware/validation');
const { INPUT_SECURITY } = require('../config/security');

// Enhanced security validation patterns
const securePatterns = {
  // Prevent common injection patterns
  safeText: Joi.string().pattern(/^[a-zA-Z0-9\s\-_.,!?@#$%&*()\[\]{}+=|\\:;"'<>\/~`]*$/).messages({
    'string.pattern.base': 'Text contains potentially unsafe characters'
  }),
  
  // University name with stricter validation
  universityName: Joi.string()
    .min(2)
    .max(200)
    .pattern(/^[a-zA-Z0-9\s\-_.,()&']*$/)
    .messages({
      'string.pattern.base': 'University name contains invalid characters'
    }),
  
  // Student ID validation
  studentId: Joi.string()
    .min(1)
    .max(50)
    .pattern(/^[a-zA-Z0-9\-_]*$/)
    .messages({
      'string.pattern.base': 'Student ID can only contain letters, numbers, hyphens, and underscores'
    }),
  
  // Safe filename validation
  filename: Joi.string()
    .max(255)
    .pattern(/^[a-zA-Z0-9\-_. ()]*\.(jpg|jpeg|png|gif|pdf)$/i)
    .messages({
      'string.pattern.base': 'Invalid filename format or extension'
    }),
  
  // Bio with content filtering
  bio: Joi.string()
    .max(INPUT_SECURITY.MAX_DESCRIPTION_LENGTH)
    .allow('')
    .custom((value, helpers) => {
      // Check for suspicious patterns
      for (const pattern of INPUT_SECURITY.SUSPICIOUS_PATTERNS) {
        if (pattern.test(value)) {
          return helpers.error('string.unsafe');
        }
      }
      return value;
    })
    .messages({
      'string.unsafe': 'Bio contains potentially unsafe content'
    })
};

// Enhanced auth schemas with security validation
const authSchemas = {
  register: Joi.object({
    email: commonSchemas.email,
    password: commonSchemas.password,
    fullName: securePatterns.safeText.min(2).max(INPUT_SECURITY.MAX_NAME_LENGTH).required(),
    phoneNumber: commonSchemas.phoneNumber.optional(),
    university: securePatterns.universityName.optional(),
    avatar: Joi.string().uri().max(2048).optional()
  }),

  login: Joi.object({
    email: commonSchemas.email,
    password: commonSchemas.password
  }),

  refreshToken: Joi.object({
    refreshToken: Joi.string().min(50).max(2048).required().messages({
      'string.min': 'Invalid refresh token format',
      'string.max': 'Refresh token too long'
    })
  }),

  logout: Joi.object({
    // Logout can have optional fields for analytics
    deviceInfo: Joi.object({
      platform: Joi.string().valid('web', 'ios', 'android').optional(),
      version: Joi.string().max(50).optional()
    }).optional()
  }),

  updateProfile: Joi.object({
    uid: commonSchemas.uid,
    fullName: securePatterns.safeText.min(2).max(INPUT_SECURITY.MAX_NAME_LENGTH).optional(),
    bio: securePatterns.bio.optional(),
    phoneNumber: commonSchemas.phoneNumber.optional(),
    university: securePatterns.universityName.optional(),
    avatar: Joi.string().uri().max(2048).optional(),
    location: Joi.object({
      latitude: Joi.number().min(-90).max(90).precision(8),
      longitude: Joi.number().min(-180).max(180).precision(8)
    }).optional(),
    interests: Joi.array().items(
      Joi.string().min(1).max(50).pattern(/^[a-zA-Z0-9\s\-_]*$/)
    ).max(20).optional()
  }),

  verifyStudent: Joi.object({
    uid: commonSchemas.uid,
    email: commonSchemas.email,
    university: securePatterns.universityName.required(),
    studentId: securePatterns.studentId.required()
    // Note: File validation is handled by multer middleware
  }),

  reportIssue: Joi.object({
    email: commonSchemas.email,
    name: securePatterns.safeText.min(2).max(INPUT_SECURITY.MAX_NAME_LENGTH).required(),
    issueDescription: securePatterns.safeText.min(10).max(INPUT_SECURITY.MAX_MESSAGE_LENGTH).required(),
    category: Joi.string().valid(
      'authentication', 
      'file_upload', 
      'performance', 
      'bug', 
      'feature_request', 
      'other'
    ).optional(),
    severity: Joi.string().valid('low', 'medium', 'high', 'critical').optional()
  }),

  // Admin verification schema
  adminVerifyStudent: Joi.object({
    uid: commonSchemas.uid,
    action: Joi.string().valid('approve', 'reject').required(),
    reviewerId: commonSchemas.uid,
    reason: Joi.string().max(500).optional() // For rejection reason
  })
};

module.exports = authSchemas;

