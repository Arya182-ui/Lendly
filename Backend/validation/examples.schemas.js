const Joi = require('joi');
const { commonSchemas } = require('../middleware/validation');

/**
 * Example validation schemas
 * These demonstrate proper usage patterns for the validation system
 */

// Example: User registration
const registrationExample = Joi.object({
  email: commonSchemas.email,
  password: commonSchemas.password,
  confirmPassword: Joi.string().valid(Joi.ref('password')).required()
    .messages({
      'any.only': 'Passwords must match'
    }),
  fullName: Joi.string().min(2).max(100).required(),
  age: Joi.number().integer().min(13).max(120).optional()
});

// Example: Complex nested object validation
const addressSchema = Joi.object({
  street: Joi.string().min(5).max(100).required(),
  city: Joi.string().min(2).max(50).required(),
  state: Joi.string().length(2).uppercase().optional(),
  zipCode: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required(),
  country: Joi.string().length(2).uppercase().default('US')
});

// Example: Array validation
const tagsSchema = Joi.object({
  tags: Joi.array()
    .items(Joi.string().max(30))
    .min(1)
    .max(10)
    .unique()
    .required()
});

// Example: Conditional validation
const conditionalSchema = Joi.object({
  type: Joi.string().valid('student', 'teacher', 'admin').required(),
  studentId: Joi.when('type', {
    is: 'student',
    then: Joi.string().required(),
    otherwise: Joi.forbidden()
  }),
  department: Joi.when('type', {
    is: Joi.string().valid('teacher', 'admin'),
    then: Joi.string().required(),
    otherwise: Joi.forbidden()
  })
});

// Example: Custom validation messages
const customMessagesSchema = Joi.object({
  username: Joi.string()
    .alphanum()
    .min(3)
    .max(30)
    .required()
    .messages({
      'string.alphanum': 'Username must only contain letters and numbers',
      'string.min': 'Username must be at least 3 characters long',
      'string.max': 'Username cannot exceed 30 characters',
      'any.required': 'Username is required'
    })
});

// Example: Date range validation
const dateRangeSchema = Joi.object({
  startDate: Joi.date().iso().required(),
  endDate: Joi.date().iso().min(Joi.ref('startDate')).required()
    .messages({
      'date.min': 'End date must be after start date'
    })
});

// Usage examples in routes:
/*
const { validateBody, validateQuery } = require('../middleware/validation');

// Body validation
router.post('/register', validateBody(registrationExample), async (req, res) => {
  // req.body is validated and sanitized
  const { email, password, fullName } = req.body;
  // ... handle registration
});

// Query validation
router.get('/search', validateQuery(tagsSchema), async (req, res) => {
  // req.query is validated and sanitized
  const { tags } = req.query;
  // ... handle search
});

// Multiple validations
router.post('/create/:id', 
  validateParams(Joi.object({ id: commonSchemas.id })),
  validateBody(addressSchema),
  async (req, res) => {
    const { id } = req.params;
    const address = req.body;
    // ... handle creation
  }
);
*/

module.exports = {
  registrationExample,
  addressSchema,
  tagsSchema,
  conditionalSchema,
  customMessagesSchema,
  dateRangeSchema
};

