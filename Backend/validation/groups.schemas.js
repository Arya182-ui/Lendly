const Joi = require('joi');
const { commonSchemas } = require('../middleware/validation');

// Group schemas
const groupSchemas = {
  createGroup: Joi.object({
    name: Joi.string().min(2).max(100).required(),
    description: Joi.string().max(1000).allow('').optional(),
    type: Joi.string().valid('public', 'private', 'university').default('public'),
    university: Joi.string().min(2).max(200).optional(),
    image: Joi.string().uri().optional(),
    creatorId: commonSchemas.uid,
    rules: Joi.string().max(2000).allow('').optional(),
    tags: Joi.array().items(Joi.string().max(30)).max(10).optional()
  }),

  updateGroup: Joi.object({
    userId: commonSchemas.uid,
    name: Joi.string().min(2).max(100).optional(),
    description: Joi.string().max(1000).allow('').optional(),
    type: Joi.string().valid('public', 'private', 'university').optional(),
    university: Joi.string().min(2).max(200).optional(),
    image: Joi.string().uri().optional(),
    rules: Joi.string().max(2000).allow('').optional(),
    tags: Joi.array().items(Joi.string().max(30)).max(10).optional()
  }),

  joinGroup: Joi.object({
    userId: commonSchemas.uid,
    groupId: commonSchemas.id
  }),

  leaveGroup: Joi.object({
    userId: commonSchemas.uid,
    groupId: commonSchemas.id
  }),

  discoverGroups: Joi.object({
    uid: commonSchemas.uid,
    limit: Joi.number().integer().min(1).max(100).default(20),
    q: Joi.string().max(100).optional().allow(''),
    type: Joi.string().valid('study', 'hobby', 'sports', 'tech', 'social', 'other').optional().allow('')
  }),

  myGroups: Joi.object({
    uid: commonSchemas.uid,
    limit: Joi.number().integer().min(1).max(100).default(20)
  }),

  groupId: Joi.object({
    id: commonSchemas.id
  }),

  manageMember: Joi.object({
    groupId: commonSchemas.id,
    memberId: commonSchemas.uid,
    action: Joi.string().valid('remove', 'promote', 'demote').required(),
    userId: commonSchemas.uid
  }),

  postToGroup: Joi.object({
    userId: commonSchemas.uid,
    content: Joi.string().min(1).max(2000).required(),
    image: Joi.string().uri().optional(),
    itemId: commonSchemas.id.optional()
  })
};

module.exports = groupSchemas;

