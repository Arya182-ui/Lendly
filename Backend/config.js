const dotenv = require('dotenv');
dotenv.config();

const PORT = process.env.PORT || 4000;
const GMAIL_USER = process.env.GMAIL_USER;
const GMAIL_APP_PASSWORD = process.env.GMAIL_APP_PASSWORD;
const FIREBASE_PROJECT_ID = process.env.FIREBASE_PROJECT_ID;
const STORAGE_BUCKET = process.env.STORAGE_BUCKET;

module.exports = { PORT, GMAIL_USER, GMAIL_APP_PASSWORD, FIREBASE_PROJECT_ID, STORAGE_BUCKET };

