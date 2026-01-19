const Joi = require('joi');
const { commonSchemas } = require('../middleware/validation');

// Transaction schemas
const transactionSchemas = {
  createRequest: Joi.object({
    requesterId: commonSchemas.uid,
    itemOwnerId: commonSchemas.uid,
    itemId: commonSchemas.id,
    type: Joi.string().valid('borrow', 'lend', 'exchange', 'donate').required(),
    message: Joi.string().max(500).allow('').optional(),
    duration: Joi.number().integer().min(1).max(365).optional(),
    proposedPrice: Joi.number().min(0).optional()
  }),

  respondToRequest: Joi.object({
    ownerId: commonSchemas.uid,
    action: Joi.string().valid('accept', 'reject').required(),
    message: Joi.string().max(500).allow('').optional()
  }),

  completeTransaction: Joi.object({
    userId: commonSchemas.uid,
    rating: Joi.number().integer().min(1).max(5).optional(),
    review: Joi.string().max(500).allow('').optional()
  }),

  cancelTransaction: Joi.object({
    userId: commonSchemas.uid
  }),

  getMyTransactions: Joi.object({
    uid: commonSchemas.uid,
    type: Joi.string().valid('requested', 'received', 'all').default('all'),
    status: Joi.string().valid('pending', 'accepted', 'rejected', 'completed', 'cancelled').optional(),
    limit: Joi.number().integer().min(1).max(50).default(20)
  }),

  transactionId: Joi.object({
    id: commonSchemas.id
  })
};

module.exports = transactionSchemas;

