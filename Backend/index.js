// Load environment variables first
require('dotenv').config();

// CRITICAL: Prevent ADC conflicts by unsetting GOOGLE_APPLICATION_CREDENTIALS
// This forces all Google Cloud clients to use the Firebase Admin SDK credentials
if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.log('[FIREBASE] Removing GOOGLE_APPLICATION_CREDENTIALS to prevent credential conflicts');
  delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
}

// NUCLEAR OPTION: Force all Google Cloud services to use our service account
const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
if (serviceAccountJson) {
  try {
    const serviceAccount = JSON.parse(serviceAccountJson);
    
    // Set Google Cloud credentials globally BEFORE any imports
    process.env.GOOGLE_CLOUD_PROJECT_ID = serviceAccount.project_id;
    process.env.GCLOUD_PROJECT = serviceAccount.project_id;
    
    // Create temporary credential file to force consistent auth
    const fs = require('fs');
    const path = require('path');
    const tempCredFile = path.join(__dirname, 'temp-firebase-creds.json');
    fs.writeFileSync(tempCredFile, serviceAccountJson);
    process.env.GOOGLE_APPLICATION_CREDENTIALS = tempCredFile;
    
    console.log('[FIREBASE] Forced credential unification with temp file');
  } catch (error) {
    console.error('[FIREBASE] Failed to set up unified credentials:', error);
  }
}

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const admin = require('firebase-admin');
const { PORT } = require('./config.js');

// --- FIREBASE ADMIN INIT ---
console.log('[FIREBASE] Environment check:', {
  hasServiceAccountJSON: !!process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
  jsonLength: process.env.FIREBASE_SERVICE_ACCOUNT_JSON?.length || 0,
  projectId: process.env.FIREBASE_PROJECT_ID
});

if (!process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  console.error('ERROR: FIREBASE_SERVICE_ACCOUNT_JSON environment variable is missing.');
  process.exit(1);
}

if (!admin.apps.length) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    
    // Explicitly set the project ID to prevent ADC conflicts
    const projectId = serviceAccount.project_id || process.env.FIREBASE_PROJECT_ID;
    
    const app = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId,
      storageBucket: process.env.STORAGE_BUCKET || "bruteforcecamera.appspot.com"
    });
    
    console.log('[FIREBASE] Initialized successfully with project:', projectId);
    
    // Test Firestore connection immediately
    const testDb = app.firestore();
    console.log('[FIREBASE] Testing Firestore connection...');
    
    // Test basic Firestore access
    setTimeout(async () => {
      try {
        const testDoc = await testDb.collection('_test').doc('connection').get();
        console.log('[FIREBASE] Firestore connection test successful');
      } catch (error) {
        console.error('[FIREBASE] Firestore connection test failed:', error.message);
        console.error('[FIREBASE] Error code:', error.code);
      }
    }, 1000);
    
  } catch (error) {
    console.error('[FIREBASE] Initialization failed:', error);
    process.exit(1);
  }
}

// --- Middleware ---
const { 
  rateLimit, 
  sanitizeBody, 
  requestLogger,
  requestTimeout,
  authenticateUser
} = require('./middleware/auth');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const { sanitizeHtml, isValidUid } = require('./utils/validators');
const {
  securityHeaders,
  advancedSanitization, 
  requestSizeLimiter,
  suspiciousActivityDetector,
  contentTypeValidator,
  safeErrorHandler
} = require('./middleware/security');
const { SECURITY_FEATURES } = require('./config/security');

// --- Modular Routes ---

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/user');
const friendsRoutes = require('./routes/friends');
const chatRoutes = require('./routes/chat');
const groupsRoutes = require('./routes/groups');
const impactRoutes = require('./routes/impact');
const homeRoutes = require('./routes/home');
const itemsRoutes = require('./routes/items');
const transactionsRoutes = require('./routes/transactions');
const adminRoutes = require('./routes/admin');
const challengesRoutes = require('./routes/challenges');
const activitiesRoutes = require('./routes/activities');
const rewardsRoutes = require('./routes/rewards');

// Import routes that require initialized Firebase
const { router: walletRoutes } = require('./routes/wallet');
const { router: notificationsRoutes } = require('./routes/notifications');


const app = express();
const server = http.createServer(app);

// --- CORS Configuration ---
const allowedOrigins = process.env.ALLOWED_ORIGINS 
  ? process.env.ALLOWED_ORIGINS.split(',') 
  : ['*'];

const io = new Server(server, {
  cors: {
    origin: allowedOrigins,
    methods: ['GET', 'POST']
  }
});

// --- Enhanced Global Middleware Stack ---
// Order is critical for security middleware
app.use(express.json({ limit: '10mb' }));
app.use(requestTimeout(30000)); // 30 second timeout

// Security middleware (applied first)
app.use(securityHeaders); // Apply security headers
app.use(requestSizeLimiter); // Limit request size
app.use(contentTypeValidator); // Validate content types
app.use(suspiciousActivityDetector); // Detect suspicious patterns
app.use(requestLogger); // Enhanced logging with security context

// Rate limiting (endpoint-specific)
app.use('/auth', rateLimit({ max: 50, windowMs: 60000 })); // More restrictive for auth
app.use('/user/upload', rateLimit({ max: 10, windowMs: 3600000 })); // Very restrictive for uploads
app.use(rateLimit({ max: 100, windowMs: 60000 })); // Default rate limit

// Input sanitization (applied after rate limiting)
if (SECURITY_FEATURES.ENABLE_INPUT_SANITIZATION) {
  app.use(advancedSanitization); // Enhanced sanitization
} else {
  app.use(sanitizeBody); // Fallback basic sanitization
}

// --- Health Check Routes ---
const { createHealthRoutes, startHealthMonitoring } = require('./utils/health-check');

// Attach health endpoints
createHealthRoutes(app);

// Simple ping endpoint for Railway
app.get('/ping', (req, res) => res.json({ message: 'pong', timestamp: new Date().toISOString() }));

// --- Routes ---
app.use('/auth', authRoutes);
app.use('/user', authenticateUser, userRoutes);
app.use('/user', authenticateUser, friendsRoutes); // Mount friends routes under /user
app.use('/chat', authenticateUser, chatRoutes);
app.use('/groups', authenticateUser, groupsRoutes);
app.use('/impact', authenticateUser, impactRoutes);
app.use('/home', homeRoutes); // Keep public for discovery
app.use('/items', authenticateUser, itemsRoutes);
app.use('/transactions', authenticateUser, transactionsRoutes);
app.use('/admin', authenticateUser, adminRoutes);
app.use('/wallet', authenticateUser, walletRoutes);
app.use('/challenges', authenticateUser, challengesRoutes);
app.use('/activities', authenticateUser, activitiesRoutes);
app.use('/rewards', authenticateUser, rewardsRoutes);
app.use('/notifications', authenticateUser, notificationsRoutes);

// Legacy health check (keep for compatibility)
app.get('/api/health', (req, res) => res.json({ status: 'ok', timestamp: Date.now() }));

// --- 404 Handler for undefined routes ---
app.use(notFoundHandler);

// --- Enhanced Error Handler (must be last) ---
app.use(safeErrorHandler);

// --- Enhanced Socket.IO Authentication & Rate Limiting ---
const socketRateLimit = new Map();
const SOCKET_RATE_WINDOW = 60 * 1000; // 1 minute
const MAX_SOCKET_CONNECTIONS_PER_IP = 5;
const MAX_SOCKET_EVENTS_PER_MINUTE = 100;

// Socket connection tracking
const socketConnections = new Map();

io.use(async (socket, next) => {
  const ip = socket.handshake.address;
  const now = Date.now();
  
  console.log('[SOCKET] Connection attempt:', {
    ip,
    userAgent: socket.handshake.headers['user-agent']?.substring(0, 100),
    timestamp: new Date().toISOString()
  });
  
  // Rate limiting for socket connections
  if (socketRateLimit.has(ip)) {
    const record = socketRateLimit.get(ip);
    
    // Reset if window has passed
    if (now - record.startTime > SOCKET_RATE_WINDOW) {
      record.count = 1;
      record.startTime = now;
    } else {
      record.count++;
    }
    
    if (record.count > MAX_SOCKET_CONNECTIONS_PER_IP) {
      console.warn('[SOCKET] Rate limit exceeded for IP:', ip);
      return next(new Error('Too many connection attempts'));
    }
  } else {
    socketRateLimit.set(ip, { count: 1, startTime: now });
  }
  
  // Check concurrent connections per IP
  const currentConnections = socketConnections.get(ip) || 0;
  if (currentConnections >= MAX_SOCKET_CONNECTIONS_PER_IP) {
    console.warn('[SOCKET] Too many concurrent connections from IP:', ip);
    return next(new Error('Too many concurrent connections'));
  }
  
  // Authenticate using Firebase ID token from handshake
  try {
    const token = socket.handshake.auth.token;
    if (!token) {
      console.warn('[SOCKET] No authentication token provided:', { ip });
      return next(new Error('Authentication error: No token provided'));
    }
    
    // Verify Firebase ID token
    const decoded = await admin.auth().verifyIdToken(token, true); // checkRevoked = true
    socket.userId = decoded.uid;
    socket.userEmail = decoded.email;
    
    // Track connection
    socketConnections.set(ip, currentConnections + 1);
    
    console.log('[SOCKET] User authenticated:', { 
      uid: decoded.uid, 
      ip,
      email: decoded.email?.substring(0, 20) + '...'
    });
    
    next();
  } catch (err) {
    console.error('[SOCKET] Authentication failed:', {
      error: err.message,
      ip,
      timestamp: new Date().toISOString()
    });
    return next(new Error('Authentication error: Invalid token'));
  }
});

// --- ENHANCED SOCKET.IO EVENTS ---
const activeUsers = new Map(); // Track online users
const typingUsers = new Map(); // Track typing status
const socketEventCounts = new Map(); // Track event rates per socket

io.on('connection', (socket) => {
  const ip = socket.handshake.address;
  
  console.log('[SOCKET] User connected:', { 
    socketId: socket.id, 
    uid: socket.userId,
    ip,
    timestamp: new Date().toISOString()
  });
  
  // Initialize event rate limiting for this socket
  socketEventCounts.set(socket.id, { count: 0, resetTime: Date.now() + SOCKET_RATE_WINDOW });
  
  // User is already authenticated via middleware
  socket.emit('authenticated', { success: true, uid: socket.userId });
  
  // Add user to active users
  activeUsers.set(socket.userId, {
    socketId: socket.id,
    lastSeen: new Date(),
    isOnline: true,
    ip: ip
  });
  
  // Broadcast user online status to their friends
  socket.broadcast.emit('userOnlineStatus', {
    uid: socket.userId,
    isOnline: true,
    lastSeen: new Date()
  });

  // Enhanced rate limiting for socket events
  const checkEventRateLimit = () => {
    const eventData = socketEventCounts.get(socket.id);
    if (!eventData) return false;
    
    const now = Date.now();
    
    // Reset counter if window has passed
    if (now > eventData.resetTime) {
      eventData.count = 0;
      eventData.resetTime = now + SOCKET_RATE_WINDOW;
    }
    
    eventData.count++;
    
    if (eventData.count > MAX_SOCKET_EVENTS_PER_MINUTE) {
      console.warn('[SOCKET] Event rate limit exceeded:', {
        socketId: socket.id,
        uid: socket.userId,
        ip,
        count: eventData.count
      });
      return true;
    }
    
    return false;
  };

  // Join a chat room (for 1:1 chat, room = sorted uid1_uid2)
  socket.on('joinRoom', (roomId) => {
    if (checkEventRateLimit()) {
      return socket.emit('rateLimitExceeded', { message: 'Too many events per minute' });
    }
    
    if (!roomId || typeof roomId !== 'string' || roomId.length > 100) {
      return socket.emit('error', { message: 'Invalid room ID' });
    }
    
    socket.join(roomId);
    console.log(`[SOCKET] User ${socket.userId} joined room ${roomId}`);
    
    // Mark messages as delivered when user joins room
    socket.emit('messagesDelivered', { roomId });
  });

  // Leave a chat room
  socket.on('leaveRoom', (roomId) => {
    if (!roomId || typeof roomId !== 'string') {
      return socket.emit('error', { message: 'Invalid room ID' });
    }
    socket.leave(roomId);
    console.log(`User ${socket.id} left room ${roomId}`);
  });

  // Typing indicator events
  socket.on('startTyping', (data) => {
    if (!data || !data.roomId || !data.to) {
      return socket.emit('error', { message: 'Invalid typing data' });
    }
    
    const typingKey = `${data.roomId}_${socket.userId}`;
    typingUsers.set(typingKey, Date.now());
    
    // Broadcast typing status to other users in room
    socket.to(data.roomId).emit('userTyping', {
      roomId: data.roomId,
      userId: socket.userId,
      isTyping: true,
      timestamp: Date.now()
    });
  });

  socket.on('stopTyping', (data) => {
    if (!data || !data.roomId) {
      return socket.emit('error', { message: 'Invalid typing data' });
    }
    
    const typingKey = `${data.roomId}_${socket.userId}`;
    typingUsers.delete(typingKey);
    
    // Broadcast typing stop to other users in room
    socket.to(data.roomId).emit('userTyping', {
      roomId: data.roomId,
      userId: socket.userId,
      isTyping: false,
      timestamp: Date.now()
    });
  });

  // Message read status
  socket.on('markMessagesRead', async (data) => {
    if (!data || !data.roomId || !data.messageIds) {
      return socket.emit('error', { message: 'Invalid read status data' });
    }
    
    try {
      // Update message read status in database
      const batch = admin.firestore().batch();
      const chatRef = admin.firestore().collection('chats').doc(data.roomId);
      
      for (const messageId of data.messageIds) {
        const messageRef = chatRef.collection('messages').doc(messageId);
        batch.update(messageRef, {
          read: true,
          readAt: admin.firestore.FieldValue.serverTimestamp(),
          readBy: admin.firestore.FieldValue.arrayUnion(socket.userId)
        });
      }
      
      await batch.commit();
      
      // Broadcast read status to sender
      socket.to(data.roomId).emit('messagesRead', {
        roomId: data.roomId,
        messageIds: data.messageIds,
        readBy: socket.userId,
        readAt: new Date()
      });
    } catch (err) {
      console.error('Error marking messages as read:', err);
    }
  });

  // Send message event with enhanced features
  socket.on('sendMessage', async (data) => {
    // Validate input
    if (!data || !data.roomId || !data.to || !data.message) {
      return socket.emit('error', { message: 'Invalid message data' });
    }
    
    if (typeof data.message !== 'string' || data.message.length > 5000) {
      return socket.emit('error', { message: 'Message too long' });
    }
    
    // Sanitize message data - use authenticated socket.userId
    const messageData = {
      id: data.messageId || `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      messageId: data.messageId || `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      roomId: sanitizeHtml(data.roomId?.trim() || ''),
      senderId: socket.userId, // Use authenticated user ID
      from: socket.userId, // Backwards compatibility
      to: sanitizeHtml(data.to?.trim() || ''),
      text: sanitizeHtml(data.message),
      message: sanitizeHtml(data.message), // Backwards compatibility
      createdAt: data.createdAt || Date.now(), // Use client timestamp or current time
      timestamp: data.createdAt || Date.now(), // Backwards compatibility
      type: data.type || 'text',
      status: 'sent'
    };
    
    // Add file/image data if present
    if (data.type === 'image' && data.imageUrl) {
      messageData.imageUrl = sanitizeHtml(data.imageUrl);
    } else if (data.type === 'file' && data.fileUrl) {
      messageData.fileUrl = sanitizeHtml(data.fileUrl);
      messageData.fileName = sanitizeHtml(data.fileName || 'file');
    }
    
    // Store message in Firestore with enhanced data
    try {
      const chatRef = admin.firestore().collection('chats').doc(data.roomId);
      const messageRef = chatRef.collection('messages').doc(messageData.messageId);
      
      await admin.firestore().runTransaction(async (transaction) => {
        // Add message
        transaction.set(messageRef, {
          senderId: messageData.from,
          text: messageData.message,
          type: messageData.type,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
          readBy: [],
          status: 'sent',
          ...(messageData.imageUrl && { imageUrl: messageData.imageUrl }),
          ...(messageData.fileUrl && { fileUrl: messageData.fileUrl, fileName: messageData.fileName })
        });
        
        // Update chat's last message
        transaction.update(chatRef, {
          lastMessage: messageData.message.substring(0, 100),
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
          [`unreadCount.${messageData.to}`]: admin.firestore.FieldValue.increment(1)
        });
      });
      
      // Update message status to delivered
      messageData.status = 'delivered';
      
      // Emit to room with delivery confirmation
      io.to(data.roomId).emit('receiveMessage', messageData);
      
      // Send acknowledgment to sender
      socket.emit('messageSent', {
        messageId: messageData.messageId,
        status: 'sent',
        timestamp: Date.now()
      });
      
      // Send delivery confirmation to sender
      socket.emit('messageStatus', {
        messageId: messageData.messageId,
        status: 'delivered',
        timestamp: Date.now()
      });
      
    } catch (err) {
      console.error('Error saving message:', err);
      socket.emit('messageStatus', {
        messageId: messageData.messageId,
        status: 'failed',
        error: 'Failed to save message',
        timestamp: Date.now()
      });
    }
  });

  // Delete message event
  socket.on('deleteMessage', async (data) => {
    if (!data || !data.roomId || !data.messageId) {
      return socket.emit('error', { message: 'Invalid delete message data' });
    }
    
    try {
      const messageRef = admin.firestore()
        .collection('chats').doc(data.roomId)
        .collection('messages').doc(data.messageId);
      
      const messageDoc = await messageRef.get();
      if (!messageDoc.exists) {
        return socket.emit('error', { message: 'Message not found' });
      }
      
      const messageData = messageDoc.data();
      if (messageData.senderId !== socket.userId) {
        return socket.emit('error', { message: 'Can only delete your own messages' });
      }
      
      // Mark message as deleted instead of actually deleting
      await messageRef.update({
        deleted: true,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
        deletedBy: socket.userId
      });
      
      // Broadcast delete event to room
      io.to(data.roomId).emit('messageDeleted', {
        roomId: data.roomId,
        messageId: data.messageId,
        deletedBy: socket.userId,
        timestamp: Date.now()
      });
      
    } catch (err) {
      console.error('Error deleting message:', err);
      socket.emit('error', { message: 'Failed to delete message' });
    }
  });

  // Enhanced disconnect handler with proper cleanup
  socket.on('disconnect', (reason) => {
    const ip = socket.handshake.address;
    
    console.log('[SOCKET] User disconnected:', { 
      socketId: socket.id,
      uid: socket.userId,
      ip,
      reason,
      timestamp: new Date().toISOString()
    });
    
    // Clean up connection tracking
    const currentConnections = socketConnections.get(ip) || 0;
    if (currentConnections > 0) {
      socketConnections.set(ip, currentConnections - 1);
    }
    
    // Clean up event rate limiting
    socketEventCounts.delete(socket.id);
    
    // Remove from active users
    if (socket.userId) {
      activeUsers.delete(socket.userId);
      
      // Broadcast user offline status to their friends
      socket.broadcast.emit('userOnlineStatus', {
        uid: socket.userId,
        isOnline: false,
        lastSeen: new Date()
      });
    }
    
    // Clean up typing status
    for (const [key, value] of typingUsers.entries()) {
      if (key.endsWith(`_${socket.userId}`)) {
        typingUsers.delete(key);
        const roomId = key.split('_')[0];
        socket.to(roomId).emit('userTyping', {
          roomId,
          userId: socket.userId,
          isTyping: false,
          timestamp: Date.now()
        });
      }
    }
    
    // Broadcast user offline status
    socket.broadcast.emit('userOnlineStatus', {
      uid: socket.userId,
      isOnline: false,
      lastSeen: new Date()
    });
  });
});

// Cleanup socket rate limit periodically
setInterval(() => {
  const now = Date.now();
  for (const [ip, record] of socketRateLimit.entries()) {
    if (now - record.time > 60000) {
      socketRateLimit.delete(ip);
    }
  }
}, 60000);

// --- Start Health Monitoring ---
startHealthMonitoring(60000); // Check every minute

// --- Start Keep-Alive Service ---
require('./utils/keep-alive');

// --- Graceful Shutdown ---
process.on('SIGTERM', () => {
  console.log('SIGTERM received. Shutting down gracefully...');
  cleanup();
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received. Shutting down gracefully...');
  cleanup();
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// Cleanup function for temp credentials
function cleanup() {
  try {
    const fs = require('fs');
    const path = require('path');
    const tempCredFile = path.join(__dirname, 'temp-firebase-creds.json');
    if (fs.existsSync(tempCredFile)) {
      fs.unlinkSync(tempCredFile);
      console.log('[FIREBASE] Cleaned up temp credential file');
    }
  } catch (error) {
    // Ignore cleanup errors
  }
}

// --- Start Server ---
server.listen(PORT, () => console.log(`Lendly backend running on port ${PORT}`));

