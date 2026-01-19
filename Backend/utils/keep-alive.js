const https = require('https');

const PING_URL = process.env.RAILWAY_URL || 'https://ary-lendly-production.up.railway.app';
const PING_INTERVAL = parseInt(process.env.PING_INTERVAL) || 25 * 60 * 1000; // 25 minutes

function keepAlive() {
  const pingUrl = `${PING_URL}/ping`;
  
  https.get(pingUrl, (res) => {
    console.log(`[KEEP-ALIVE] Ping successful: ${res.statusCode} at ${new Date().toISOString()}`);
  }).on('error', (err) => {
    console.error(`[KEEP-ALIVE] Ping failed: ${err.message} at ${new Date().toISOString()}`);
  });
}

// Only run keep-alive in production
if (process.env.NODE_ENV === 'production' && process.env.RAILWAY_URL) {
  console.log(`[KEEP-ALIVE] Starting keep-alive service. Pinging every ${PING_INTERVAL/60000} minutes`);
  
  // Initial ping after 5 minutes
  setTimeout(keepAlive, 5 * 60 * 1000);
  
  // Regular pings
  setInterval(keepAlive, PING_INTERVAL);
} else {
  console.log('[KEEP-ALIVE] Keep-alive disabled (not in production or no Railway URL)');
}

module.exports = { keepAlive };
