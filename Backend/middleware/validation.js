const Joi = require('joi');

// Standard error response format
const createErrorResponse = (errors) => {
  return {
    success: false,
    error: 'Validation failed',
    details: errors.map(err => ({
      field: err.path.join('.'),
      message: err.message,
      type: err.type
    }))
  };
};

// Validate request body middleware
const validateBody = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.body, {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });

    if (error) {
      return res.status(400).json(createErrorResponse(error.details));
    }

    req.body = value;
    next();
  };
};

// Validate query parameters middleware
const validateQuery = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.query, {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });

    if (error) {
      return res.status(400).json(createErrorResponse(error.details));
    }

    req.query = value;
    next();
  };
};

// Validate route parameters middleware
const validateParams = (schema) => {
  return (req, res, next) => {
    const { error, value } = schema.validate(req.params, {
      abortEarly: false,
      stripUnknown: true,
      convert: true
    });

    if (error) {
      return res.status(400).json(createErrorResponse(error.details));
    }

    req.params = value;
    next();
  };
};

// Common validation schemas
const commonSchemas = {
  uid: Joi.string().min(1).max(128).required(),
  optionalUid: Joi.string().min(1).max(128),
  email: Joi.string().email().required(),
  password: Joi.string().min(6).max(128).required(),
  pagination: Joi.object({
    limit: Joi.number().integer().min(1).max(100).default(20),
    offset: Joi.number().integer().min(0).default(0)
  }),
  id: Joi.string().min(1).max(128).required(),
  timestamp: Joi.date().iso(),
  url: Joi.string().uri(),
  phoneNumber: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/)
};

module.exports = {
  validateBody,
  validateQuery,
  validateParams,
  createErrorResponse,
  commonSchemas
};

