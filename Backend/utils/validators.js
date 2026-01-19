/**
 * Input validation helpers
 */

/**
 * Validate email format
 */
const isValidEmail = (email) => {
  if (!email || typeof email !== 'string') return false;
  const emailRegex = /^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$/;
  return emailRegex.test(email);
};

/**
 * Validate UID format (Firebase UID or custom)
 */
const isValidUid = (uid) => {
  if (!uid || typeof uid !== 'string') return false;
  // Firebase UIDs are 28 characters, but allow custom IDs up to 128 chars
  if (uid.length > 128 || uid.length < 1) return false;
  // No path traversal
  if (uid.includes('/') || uid.includes('..')) return false;
  return true;
};

/**
 * Validate password strength
 */
const isStrongPassword = (password) => {
  if (!password || typeof password !== 'string') return false;
  // At least 8 characters, with uppercase, lowercase, and number
  return /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}$/.test(password);
};

/**
 * Validate OTP format (6 digits)
 */
const isValidOtp = (otp) => {
  if (!otp || typeof otp !== 'string') return false;
  return /^\d{6}$/.test(otp);
};

/**
 * Validate coordinates
 */
const isValidLatitude = (lat) => {
  const num = parseFloat(lat);
  return !isNaN(num) && num >= -90 && num <= 90;
};

const isValidLongitude = (lng) => {
  const num = parseFloat(lng);
  return !isNaN(num) && num >= -180 && num <= 180;
};

/**
 * Validate string length
 */
const isValidLength = (str, min, max) => {
  if (!str || typeof str !== 'string') return min === 0;
  return str.length >= min && str.length <= max;
};

/**
 * Validate array
 */
const isValidArray = (arr, minLength = 0, maxLength = Infinity) => {
  if (!Array.isArray(arr)) return false;
  return arr.length >= minLength && arr.length <= maxLength;
};

/**
 * Sanitize HTML to prevent XSS
 */
const sanitizeHtml = (str) => {
  if (typeof str !== 'string') return str;
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;');
};

/**
 * Parse and validate integer
 */
const parseIntSafe = (value, defaultValue = 0) => {
  const parsed = parseInt(value, 10);
  return isNaN(parsed) ? defaultValue : parsed;
};

/**
 * Parse and validate float
 */
const parseFloatSafe = (value, defaultValue = 0) => {
  const parsed = parseFloat(value);
  return isNaN(parsed) ? defaultValue : parsed;
};

/**
 * Trim all string fields in an object
 */
const trimObjectStrings = (obj) => {
  if (!obj || typeof obj !== 'object') return obj;
  
  const result = {};
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === 'string') {
      result[key] = value.trim();
    } else {
      result[key] = value;
    }
  }
  return result;
};

/**
 * Whitelist allowed fields from an object
 */
const pickFields = (obj, allowedFields) => {
  if (!obj || typeof obj !== 'object') return {};
  
  const result = {};
  for (const field of allowedFields) {
    if (obj[field] !== undefined) {
      result[field] = obj[field];
    }
  }
  return result;
};

module.exports = {
  isValidEmail,
  isValidUid,
  isStrongPassword,
  isValidOtp,
  isValidLatitude,
  isValidLongitude,
  isValidLength,
  isValidArray,
  sanitizeHtml,
  parseIntSafe,
  parseFloatSafe,
  trimObjectStrings,
  pickFields
};

