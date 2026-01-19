const Joi = require('joi');
const { commonSchemas } = require('../middleware/validation');

// Item schemas
const itemSchemas = {
  createItem: Joi.object({
    ownerId: commonSchemas.uid,
    name: Joi.string().min(2).max(100).required(),
    description: Joi.string().max(1000).allow('').optional(),
    category: Joi.string().min(2).max(50).required(),
    condition: Joi.string().valid('new', 'like-new', 'good', 'fair', 'poor').required(),
    price: Joi.number().min(0).default(0),
    image: Joi.string().uri().optional(),
    images: Joi.array().items(Joi.string().uri()).optional(),
    available: Joi.boolean().default(true),
    location: Joi.object({
      latitude: Joi.number().min(-90).max(90).required(),
      longitude: Joi.number().min(-180).max(180).required(),
      address: Joi.string().max(200).optional()
    }).optional(),
    tags: Joi.array().items(Joi.string().max(30)).max(10).optional()
  }),

  updateItem: Joi.object({
    ownerId: commonSchemas.uid,
    name: Joi.string().min(2).max(100).optional(),
    description: Joi.string().max(1000).allow('').optional(),
    category: Joi.string().min(2).max(50).optional(),
    condition: Joi.string().valid('new', 'like-new', 'good', 'fair', 'poor').optional(),
    price: Joi.number().min(0).optional(),
    image: Joi.string().uri().optional(),
    images: Joi.array().items(Joi.string().uri()).optional(),
    available: Joi.boolean().optional(),
    location: Joi.object({
      latitude: Joi.number().min(-90).max(90).required(),
      longitude: Joi.number().min(-180).max(180).required(),
      address: Joi.string().max(200).optional()
    }).optional(),
    tags: Joi.array().items(Joi.string().max(30)).max(10).optional()
  }),

  getItems: Joi.object({
    category: Joi.string().max(50).optional(),
    available: Joi.boolean().optional(),
    limit: Joi.number().integer().min(1).max(100).default(20),
    offset: Joi.number().integer().min(0).default(0),
    search: Joi.string().max(100).optional()
  }),

  getUserItems: Joi.object({
    uid: commonSchemas.uid,
    available: Joi.boolean().optional(),
    limit: Joi.number().integer().min(1).max(100).default(20)
  }),

  itemId: Joi.object({
    id: commonSchemas.id
  }),

  deleteItem: Joi.object({
    ownerId: commonSchemas.uid
  })
};

module.exports = itemSchemas;

