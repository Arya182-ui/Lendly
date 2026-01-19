# 🖥️ Lendly Backend API Server

<div align="center">

**🚀 Node.js • 🔥 Express.js • 💾 Firebase • ⚡ Socket.IO**

*Powering the Lendly peer-to-peer lending platform with robust, scalable backend services*

[![Node.js](https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org/)
[![Express.js](https://img.shields.io/badge/Express.js-404D59?style=for-the-badge)](https://expressjs.com/)
[![Firebase](https://img.shields.io/badge/Firebase-039BE5?style=for-the-badge&logo=Firebase&logoColor=white)](https://firebase.google.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-black?style=for-the-badge&logo=socket.io&badgeColor=010101)](https://socket.io/)

![API Version](https://img.shields.io/badge/API-v1.0.0-blue?style=flat-square)
![Build Status](https://img.shields.io/badge/build-passing-brightgreen?style=flat-square)
![Uptime](https://img.shields.io/badge/uptime-99.9%25-brightgreen?style=flat-square)

</div>

---

## 🌟 Backend Overview

The Lendly Backend is a high-performance, scalable Node.js application built with Express.js that powers the entire Lendly ecosystem. It provides RESTful APIs, real-time WebSocket connections, and comprehensive business logic for college students' peer-to-peer lending platform.

### 🎯 **Core Capabilities**
- 🔐 **Authentication & Authorization** - Secure JWT-based auth with student verification
- 💬 **Real-time Messaging** - Socket.IO powered chat with typing indicators
- 👥 **Social Features** - Friend management, groups, and community building  
- 📚 **Item Management** - Complete CRUD operations for lending/selling items
- 💳 **Digital Transactions** - Secure wallet and payment processing
- 🏆 **Gamification** - Rewards, achievements, and leaderboard systems
- 🛡️ **Trust & Safety** - User verification, reporting, and trust scoring
- 📊 **Analytics** - Comprehensive tracking and insights
- 🔄 **Real-time Updates** - Live notifications and status updates

---

## 🏗️ Architecture & Design Patterns

### **📡 API Architecture**
```
┌─────────────────────────────────────────────────────────────────┐
│                    🌐 Client Applications                        │
│              (Flutter App, Web App, Admin Panel)               │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                   🛡️ API Gateway & Load Balancer               │
│                    (Rate Limiting, CORS, Security)             │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                  🚀 Express.js Application Server              │
│    ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│    │ 🔐 Auth     │ 💬 Chat     │ 👥 Social   │ 📚 Items    │   │
│    │ Routes      │ Routes      │ Routes      │ Routes      │   │
│    └─────────────┴─────────────┴─────────────┴─────────────┘   │
│                              │                                  │
│    ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│    │ 🛡️ Auth     │ ✅ Validate │ 📝 Logger   │ 🔄 Cache    │   │
│    │ Middleware  │ Middleware  │ Middleware  │ Middleware  │   │
│    └─────────────┴─────────────┴─────────────┴─────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                ⚡ Socket.IO Real-time Engine                    │
│           (Chat, Notifications, Live Updates)                  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                  🔥 Firebase Services                           │
│    ┌─────────────┬─────────────┬─────────────┬─────────────┐   │
│    │ 💾 Firestore│ 🔐 Auth     │ 📁 Storage  │ 📊 Analytics│   │
│    │ Database    │ Service     │ Bucket      │ & Insights  │   │
│    └─────────────┴─────────────┴─────────────┴─────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### **🔄 Request Flow Architecture**
1. **Client Request** → API Gateway (Rate Limiting, CORS)
2. **Authentication** → JWT Verification & User Context
3. **Validation** → Joi Schema Validation & Sanitization  
4. **Business Logic** → Route Handlers & Service Layer
5. **Database Operations** → Firebase Admin SDK
6. **Response** → JSON Response with Error Handling
7. **Real-time Events** → Socket.IO Event Emission

---

## 📁 Detailed Project Structure

```
Backend/
├── 🚀 index.js                      # Main server entry point & Socket.IO setup
├── 📋 package.json                  # Dependencies & scripts
├── ⚙️ config.js                     # Environment configuration
├── 🌱 .env                          # Environment variables (not in repo)
├── 🌱 .env.example                  # Environment template
├── 🔧 vercel.json                   # Vercel deployment configuration
├── 
├── 🛣️ routes/                      # API Route Handlers
│   ├── 🔐 auth.js                  # Authentication & student verification
│   ├── 👤 user.js                  # User management & notifications  
│   ├── 👥 friends.js               # Friend requests & management
│   ├── 🏢 groups.js                # Group creation & management
│   ├── 💬 chat.js                  # Enhanced messaging system
│   ├── 📚 items.js                 # Item CRUD & marketplace
│   ├── 💳 transactions.js          # Transaction processing
│   ├── 💰 wallet.js                # Digital wallet operations
│   ├── 🏠 home.js                  # Home feed & recommendations
│   ├── 📊 impact.js                # Environmental impact tracking
│   ├── 👨‍💼 admin.js                  # Admin panel operations
│   └── ❤️ health.js                # Health check endpoints
│
├── 🛡️ middleware/                  # Express Middleware
│   ├── 🔐 auth.js                  # JWT auth, rate limiting, sanitization
│   ├── ❌ errorHandler.js          # Global error handling
│   └── ✅ validation.js            # Request validation middleware
│
├── ✅ validation/                  # Joi Validation Schemas
│   ├── 🔐 auth.schemas.js          # Authentication validation
│   ├── 👥 groups.schemas.js        # Group operation validation
│   ├── 📚 items.schemas.js         # Item management validation
│   ├── 💳 transactions.schemas.js  # Transaction validation
│   └── 📝 examples.schemas.js      # Example schema patterns
│
├── 🔧 utils/                       # Utility Functions
│   ├── 📊 firestore-helpers.js     # Database query helpers
│   ├── ✅ validators.js            # Custom validation functions
│   ├── 🗃️ cache-manager.js         # Redis caching layer
│   ├── 📝 logger.js                # Structured logging system
│   ├── 🏥 health-check.js          # System health monitoring
│   └── 🚀 db-performance.js        # Database performance optimization
│
├── 📊 issueReports.js              # Issue reporting system
├── 🎓 verifyStudent.js             # Student verification logic
└── 📚 Documentation/               # API Documentation (Generated)
    ├── api-docs.html               # Interactive API documentation
    └── postman-collection.json     # Postman API collection
```

---

## 🔑 Environment Configuration

### **📝 Required Environment Variables**
Create a `.env` file in the Backend directory with the following configuration:

```bash
# 🔥 Firebase Configuration
FIREBASE_SERVICE_ACCOUNT_JSON='{...}'  # Firebase service account JSON
STORAGE_BUCKET=your-project.appspot.com
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-client@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# 🌐 Server Configuration  
PORT=3000
NODE_ENV=production
BASE_URL=https://your-domain.com

# 🛡️ Security Configuration
JWT_SECRET=your-super-secret-jwt-key-min-32-characters
JWT_EXPIRES_IN=30d
BCRYPT_ROUNDS=12

# 🚦 Rate Limiting
RATE_LIMIT_WINDOW_MS=900000        # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100        # Max requests per window
RATE_LIMIT_SKIP_SUCCESSFUL_REQUESTS=false

# 🔄 CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,https://your-domain.com
CORS_CREDENTIALS=true

# 📧 Email Configuration (Optional - for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@yourdomain.com
SMTP_PASSWORD=your-app-password

# 🗃️ Caching Configuration
REDIS_URL=redis://localhost:6379
CACHE_TTL=3600                     # 1 hour in seconds

# 📊 Analytics & Monitoring
GOOGLE_ANALYTICS_ID=G-XXXXXXXXXX
SENTRY_DSN=https://your-sentry-dsn

# 🎓 Student Verification
SUPPORTED_COLLEGE_DOMAINS=*.edu,*.ac.in,*.edu.in
ADMIN_EMAIL=admin@yourdomain.com
VERIFICATION_EXPIRY_HOURS=48

# 🔐 API Keys (Optional)
GOOGLE_MAPS_API_KEY=your-google-maps-key
CLOUDINARY_CLOUD_NAME=your-cloudinary-name
CLOUDINARY_API_KEY=your-cloudinary-key
CLOUDINARY_API_SECRET=your-cloudinary-secret
```

---

## 🚀 Quick Start Guide

### **📋 Prerequisites**
- **Node.js**: 16.x or higher
- **npm**: 8.x or higher  
- **Firebase Project**: With Firestore, Auth, and Storage enabled
- **Git**: For version control

### **⚡ Installation & Setup**

#### **1. Clone & Install Dependencies**
```bash
# Clone the repository
git clone https://github.com/Arya182-ui/Lendly.git
cd Lendly/Backend

# Install all dependencies
npm install

# Verify installation
npm list --depth=0
```

#### **2. Firebase Setup**
```bash
# Install Firebase CLI globally
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase project
firebase init

# Select Firestore, Authentication, Storage, and Functions
# Download service account key from Firebase Console
```

#### **3. Environment Configuration**
```bash
# Copy environment template
cp .env.example .env

# Edit with your actual values
nano .env

# Validate environment variables
npm run validate-env
```

#### **4. Database Setup**
```bash
# Initialize Firestore collections
npm run setup-db

# Create security rules
firebase deploy --only firestore:rules

# Set up indexes
firebase deploy --only firestore:indexes
```

### **🏃‍♂️ Running the Server**

#### **Development Mode**
```bash
# Start with hot reload
npm run dev

# Start with debugging
npm run dev:debug

# Start with specific port
PORT=4000 npm run dev
```

#### **Production Mode**
```bash
# Build for production
npm run build

# Start production server
npm start

# Start with PM2 process manager
npm run start:pm2
```

#### **Testing & Quality Assurance**
```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run integration tests
npm run test:integration

# Lint code
npm run lint

# Fix linting issues
npm run lint:fix

# Format code
npm run format
```

---

## 📡 Complete API Reference

### **🔐 Authentication Endpoints**

#### **POST /api/auth/register**
Register a new student with college email verification.

```bash
# Request
POST /api/auth/register
Content-Type: application/json

{
  "email": "student@college.edu",
  "password": "SecurePassword123!",
  "firstName": "John",
  "lastName": "Doe",
  "collegeName": "University of Technology",
  "studentId": "2024CS001"
}

# Response (201 Created)
{
  "success": true,
  "message": "Registration successful. Please verify your email.",
  "data": {
    "uid": "user123456789",
    "email": "student@college.edu", 
    "emailVerified": false,
    "verificationStatus": "pending"
  }
}
```

#### **POST /api/auth/login**
Authenticate user and return JWT token.

```bash
# Request
POST /api/auth/login
Content-Type: application/json

{
  "email": "student@college.edu",
  "password": "SecurePassword123!"
}

# Response (200 OK)
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": {
      "uid": "user123456789",
      "email": "student@college.edu",
      "firstName": "John",
      "lastName": "Doe",
      "profileImage": "https://...",
      "trustScore": 4.8,
      "verified": true
    },
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expiresIn": "30d"
  }
}
```

#### **POST /api/auth/verify-email**
Verify college email with verification code.

#### **POST /api/auth/forgot-password**
Initiate password reset process.

#### **POST /api/auth/reset-password**
Reset password with verification token.

### **👤 User Management Endpoints**

#### **GET /api/user/profile**
Get current user's complete profile information.

```bash
# Request
GET /api/user/profile
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "uid": "user123456789",
    "profile": {
      "firstName": "John",
      "lastName": "Doe",
      "email": "student@college.edu",
      "profileImage": "https://...",
      "bio": "Computer Science student passionate about technology",
      "college": "University of Technology",
      "year": "3rd Year",
      "major": "Computer Science",
      "interests": ["technology", "sports", "music"],
      "trustScore": 4.8,
      "totalTransactions": 25,
      "joinedDate": "2024-01-15T00:00:00Z"
    },
    "stats": {
      "itemsLent": 15,
      "itemsBorrowed": 12,
      "friendsCount": 48,
      "groupsJoined": 6,
      "rewardPoints": 1250,
      "badges": ["Helper", "Trusted Member", "Early Adopter"]
    }
  }
}
```

#### **PUT /api/user/profile**
Update user profile information.

#### **GET /api/user/notifications**
Get user's notifications with pagination and filtering.

```bash
# Request
GET /api/user/notifications?page=1&limit=20&type=chat&status=unread
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "notifications": [
      {
        "id": "notif123",
        "type": "chat",
        "title": "New message from Sarah",
        "message": "Hey! Is the textbook still available?",
        "timestamp": "2024-01-20T10:30:00Z",
        "read": false,
        "actionUrl": "/chat/user456",
        "priority": "normal"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 3,
      "totalItems": 45,
      "hasNext": true
    },
    "unreadCount": 12
  }
}
```

#### **PUT /api/user/notifications/:id/read**
Mark specific notification as read.

#### **POST /api/user/report**
Report inappropriate user behavior.

### **👥 Friends Management Endpoints**

#### **GET /api/friends**
Get user's friends list with status filtering.

```bash
# Request
GET /api/friends?status=accepted&page=1&limit=50
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "friends": [
      {
        "uid": "friend123",
        "firstName": "Sarah",
        "lastName": "Wilson", 
        "profileImage": "https://...",
        "college": "University of Technology",
        "trustScore": 4.9,
        "mutualFriends": 8,
        "lastSeen": "2024-01-20T09:15:00Z",
        "status": "accepted",
        "friendshipDate": "2024-01-10T00:00:00Z"
      }
    ],
    "summary": {
      "totalFriends": 48,
      "pendingRequests": 3,
      "sentRequests": 2
    }
  }
}
```

#### **POST /api/friends/request**
Send friend request to another user.

```bash
# Request
POST /api/friends/request
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

{
  "targetUserId": "user456789",
  "message": "Hi! I saw you're in the same CS program. Let's connect!"
}

# Response (201 Created)
{
  "success": true,
  "message": "Friend request sent successfully",
  "data": {
    "requestId": "req123456",
    "status": "pending",
    "sentAt": "2024-01-20T10:45:00Z"
  }
}
```

#### **PUT /api/friends/request/:requestId**
Accept or decline friend request.

#### **DELETE /api/friends/:friendId**
Remove friend from friends list.

#### **GET /api/friends/suggestions**
Get friend suggestions based on mutual connections and interests.

### **🏢 Groups Management Endpoints**

#### **GET /api/groups**
Get user's groups or discover public groups.

```bash
# Request
GET /api/groups?type=joined&page=1&limit=20
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "groups": [
      {
        "id": "group123",
        "name": "CS Study Circle",
        "description": "Computer Science students helping each other",
        "type": "academic",
        "privacy": "public",
        "memberCount": 24,
        "isOwner": true,
        "isAdmin": true,
        "joinedAt": "2024-01-15T00:00:00Z",
        "lastActivity": "2024-01-20T08:30:00Z",
        "avatar": "https://...",
        "college": "University of Technology"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 2,
      "totalItems": 6
    }
  }
}
```

#### **POST /api/groups**
Create a new group.

```bash
# Request
POST /api/groups
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

{
  "name": "Photography Club",
  "description": "Share and learn photography skills together",
  "type": "hobby",
  "privacy": "public",
  "maxMembers": 50,
  "rules": "Be respectful, share knowledge, help each other grow",
  "college": "University of Technology"
}

# Response (201 Created)
{
  "success": true,
  "message": "Group created successfully",
  "data": {
    "groupId": "group456",
    "name": "Photography Club",
    "ownerId": "user123456789",
    "memberCount": 1,
    "createdAt": "2024-01-20T11:00:00Z"
  }
}
```

#### **POST /api/groups/:groupId/join**
Join a public group or request to join private group.

#### **DELETE /api/groups/:groupId/leave** 
Leave a group (with smart ownership transfer).

#### **PUT /api/groups/:groupId**
Update group information (owners/admins only).

#### **GET /api/groups/:groupId/members**
Get group members list with roles.

#### **PUT /api/groups/:groupId/members/:userId/role**
Update member role (owners/admins only).

### **💬 Enhanced Chat Endpoints**

#### **GET /api/chat/conversations**
Get user's conversation list with last messages.

```bash
# Request
GET /api/chat/conversations?page=1&limit=50
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "conversations": [
      {
        "conversationId": "conv123",
        "type": "individual",
        "participant": {
          "uid": "user456",
          "firstName": "Sarah",
          "lastName": "Wilson",
          "profileImage": "https://...",
          "isOnline": true,
          "lastSeen": "2024-01-20T10:45:00Z"
        },
        "lastMessage": {
          "messageId": "msg789",
          "content": "Thanks for letting me borrow the textbook!",
          "timestamp": "2024-01-20T10:45:00Z",
          "senderId": "user456",
          "messageType": "text",
          "isRead": false
        },
        "unreadCount": 2,
        "updatedAt": "2024-01-20T10:45:00Z"
      }
    ],
    "totalConversations": 12
  }
}
```

#### **GET /api/chat/:conversationId/messages**
Get messages from a conversation with pagination.

```bash
# Request
GET /api/chat/conv123/messages?page=1&limit=50&before=msg456
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "messages": [
      {
        "messageId": "msg789",
        "senderId": "user456",
        "content": "Thanks for letting me borrow the textbook!",
        "messageType": "text",
        "timestamp": "2024-01-20T10:45:00Z",
        "edited": false,
        "reactions": {
          "👍": ["user123"],
          "❤️": ["user456", "user789"]
        },
        "replyTo": null,
        "status": "delivered"
      }
    ],
    "hasMore": true,
    "nextPage": 2
  }
}
```

#### **POST /api/chat/:conversationId/messages**
Send a new message in conversation.

```bash
# Request
POST /api/chat/conv123/messages
Content-Type: application/json
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

{
  "content": "Hi! Is the calculus textbook still available?",
  "messageType": "text",
  "replyTo": null
}

# Response (201 Created)
{
  "success": true,
  "message": "Message sent successfully",
  "data": {
    "messageId": "msg890",
    "timestamp": "2024-01-20T11:00:00Z",
    "status": "sent"
  }
}
```

#### **PUT /api/chat/messages/:messageId**
Edit a message (within time limit).

#### **DELETE /api/chat/messages/:messageId**
Delete a message (for self or everyone).

#### **POST /api/chat/messages/:messageId/react**
Add/remove reaction to a message.

#### **PUT /api/chat/messages/:messageId/read**
Mark message as read.

### **📚 Items Management Endpoints**

#### **GET /api/items**
Search and browse available items with advanced filtering.

```bash
# Request
GET /api/items?category=books&available=true&location=campus&sort=newest&page=1&limit=20
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "items": [
      {
        "itemId": "item123",
        "title": "Calculus: Early Transcendentals",
        "description": "8th edition, excellent condition, all pages intact",
        "category": "books",
        "subcategory": "textbooks",
        "condition": "excellent",
        "availableFor": ["lend", "sell"],
        "pricing": {
          "lendPrice": 50,
          "sellPrice": 800,
          "currency": "INR",
          "deposit": 100
        },
        "owner": {
          "uid": "user789",
          "firstName": "Mike",
          "lastName": "Johnson",
          "trustScore": 4.7,
          "college": "University of Technology"
        },
        "images": [
          "https://storage.googleapis.com/...",
          "https://storage.googleapis.com/..."
        ],
        "location": "Central Campus",
        "available": true,
        "postedAt": "2024-01-18T00:00:00Z",
        "viewCount": 45,
        "interestedCount": 8
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 15,
      "totalItems": 289
    },
    "filters": {
      "categories": ["books", "electronics", "sports"],
      "priceRanges": ["0-100", "100-500", "500-1000", "1000+"],
      "conditions": ["new", "excellent", "good", "fair"]
    }
  }
}
```

#### **POST /api/items**
Create a new item listing.

```bash
# Request
POST /api/items
Content-Type: multipart/form-data
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Form Data:
title: "iPhone 13 - 128GB"
description: "Excellent condition, no scratches, includes charger"
category: "electronics"
subcategory: "smartphones"
condition: "excellent"
availableFor: ["lend", "sell"]
lendPrice: 200
sellPrice: 35000
deposit: 5000
location: "North Campus Hostel"
images: [file1.jpg, file2.jpg, file3.jpg]

# Response (201 Created)
{
  "success": true,
  "message": "Item listed successfully",
  "data": {
    "itemId": "item456",
    "title": "iPhone 13 - 128GB",
    "status": "active",
    "postedAt": "2024-01-20T11:30:00Z",
    "imageUrls": [
      "https://storage.googleapis.com/item456_1.jpg",
      "https://storage.googleapis.com/item456_2.jpg"
    ]
  }
}
```

#### **GET /api/items/:itemId**
Get detailed information about a specific item.

#### **PUT /api/items/:itemId**
Update item information (owner only).

#### **DELETE /api/items/:itemId**
Delete item listing (owner only).

#### **POST /api/items/:itemId/request**
Send request to borrow/buy an item.

#### **GET /api/items/my-listings**
Get current user's item listings.

#### **GET /api/items/my-requests**
Get user's sent/received item requests.

### **💳 Transactions & Wallet Endpoints**

#### **GET /api/wallet/balance**
Get current wallet balance and transaction summary.

```bash
# Request
GET /api/wallet/balance
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "currentBalance": 2450.00,
    "currency": "INR",
    "pendingAmount": 300.00,
    "totalEarned": 5200.00,
    "totalSpent": 2750.00,
    "rewardPoints": 1250,
    "lastUpdated": "2024-01-20T11:45:00Z"
  }
}
```

#### **GET /api/transactions**
Get transaction history with filtering and pagination.

```bash
# Request
GET /api/transactions?type=all&status=completed&page=1&limit=25
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "transactions": [
      {
        "transactionId": "txn123",
        "type": "lending",
        "amount": 150.00,
        "currency": "INR",
        "status": "completed",
        "item": {
          "itemId": "item789",
          "title": "Data Structures Textbook",
          "category": "books"
        },
        "counterparty": {
          "uid": "user456",
          "firstName": "Sarah",
          "lastName": "Wilson"
        },
        "description": "Textbook lending payment",
        "createdAt": "2024-01-15T10:00:00Z",
        "completedAt": "2024-01-15T10:01:00Z",
        "fees": 15.00
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 8,
      "totalItems": 187
    }
  }
}
```

#### **POST /api/transactions/create**
Create a new transaction.

#### **PUT /api/transactions/:transactionId/status**
Update transaction status.

#### **POST /api/wallet/add-money**
Add money to wallet.

#### **POST /api/wallet/withdraw**
Withdraw money from wallet.

### **🏆 Rewards & Achievements Endpoints**

#### **GET /api/rewards/summary**
Get user's rewards summary and available rewards.

```bash
# Request
GET /api/rewards/summary
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# Response (200 OK)
{
  "success": true,
  "data": {
    "currentPoints": 1250,
    "lifetimePoints": 2100,
    "level": "Silver Helper",
    "nextLevelPoints": 1500,
    "achievements": [
      {
        "achievementId": "first_lend",
        "name": "First Helper",
        "description": "Completed your first lending transaction",
        "icon": "🎉",
        "points": 100,
        "unlockedAt": "2024-01-10T00:00:00Z"
      }
    ],
    "availableRewards": [
      {
        "rewardId": "discount_10",
        "name": "10% Platform Fee Discount",
        "description": "Get 10% off on all platform fees",
        "cost": 500,
        "category": "discount",
        "validFor": "30 days"
      }
    ]
  }
}
```

#### **POST /api/rewards/claim**
Claim a reward using points.

#### **GET /api/rewards/leaderboard**
Get campus and global leaderboards.

#### **GET /api/rewards/achievements**
Get all available achievements and progress.

### **🔍 Search & Discovery Endpoints**

#### **GET /api/search**
Universal search across items, users, and groups.

#### **GET /api/recommendations**
Get personalized recommendations for items and connections.

### **📊 Analytics & Insights Endpoints**

#### **GET /api/analytics/dashboard**
Get user dashboard analytics and insights.

#### **GET /api/analytics/impact**
Get environmental and social impact metrics.

---

## ⚡ WebSocket Events (Socket.IO)

### **🔌 Connection Management**
```javascript
// Client connects
socket.on('connect', () => {
  console.log('Connected to Lendly server');
  
  // Join user-specific room for notifications
  socket.emit('join_user_room', { userId: 'user123' });
});

// Join conversation room
socket.emit('join_conversation', { conversationId: 'conv123' });
```

### **💬 Real-time Chat Events**
```javascript
// Send message
socket.emit('send_message', {
  conversationId: 'conv123',
  message: {
    content: 'Hello there!',
    messageType: 'text'
  }
});

// Receive new message
socket.on('new_message', (data) => {
  console.log('New message:', data.message);
  // Update UI with new message
});

// Typing indicators
socket.emit('typing_start', { conversationId: 'conv123' });
socket.emit('typing_stop', { conversationId: 'conv123' });

socket.on('user_typing', (data) => {
  console.log(`${data.user.firstName} is typing...`);
});

// Message reactions
socket.emit('add_reaction', {
  messageId: 'msg123',
  reaction: '👍'
});

socket.on('message_reaction', (data) => {
  // Update message with new reaction
});
```

### **🔔 Real-time Notifications**
```javascript
// Friend request received
socket.on('friend_request', (data) => {
  showNotification(`${data.requester.firstName} sent you a friend request`);
});

// Item request received  
socket.on('item_request', (data) => {
  showNotification(`New request for your ${data.item.title}`);
});

// Transaction updates
socket.on('transaction_update', (data) => {
  updateTransactionStatus(data.transactionId, data.status);
});
```

### **👥 Group Events**
```javascript
// Group member joins
socket.on('group_member_joined', (data) => {
  console.log(`${data.user.firstName} joined ${data.group.name}`);
});

// Group message
socket.on('group_message', (data) => {
  displayGroupMessage(data.message);
});
```

### **📍 Presence & Status**
```javascript
// User online/offline status
socket.on('user_status_change', (data) => {
  updateUserStatus(data.userId, data.isOnline);
});

// Last seen updates
socket.on('user_last_seen', (data) => {
  updateLastSeen(data.userId, data.lastSeen);
});
```

---

## 🛡️ Security & Best Practices

### **🔐 Authentication & Authorization**
- **JWT Tokens**: Secure stateless authentication
- **Role-based Access**: Admin, moderator, user permissions
- **Token Refresh**: Automatic token renewal system
- **Session Management**: Secure session handling

### **🛡️ Data Protection**
- **Input Validation**: Comprehensive Joi schema validation
- **SQL Injection Prevention**: Parameterized queries
- **XSS Protection**: Content sanitization
- **CSRF Protection**: Cross-site request forgery prevention
- **Rate Limiting**: DDoS and abuse prevention

### **🔒 Privacy & Compliance**
- **Data Encryption**: Sensitive data encryption at rest
- **GDPR Compliance**: Data protection regulations
- **Privacy Controls**: User data privacy settings
- **Audit Logging**: Comprehensive activity logging

### **🚦 Rate Limiting Configuration**
```javascript
// Rate limiting rules
const rateLimits = {
  general: { windowMs: 15 * 60 * 1000, max: 100 },      // 100 requests per 15 minutes
  auth: { windowMs: 15 * 60 * 1000, max: 5 },          // 5 auth attempts per 15 minutes
  chat: { windowMs: 60 * 1000, max: 30 },              // 30 messages per minute
  upload: { windowMs: 60 * 60 * 1000, max: 10 }        // 10 uploads per hour
};
```

---

## 📊 Performance & Monitoring

### **⚡ Performance Optimizations**
- **Database Indexing**: Optimized Firestore queries
- **Caching Strategy**: Redis caching for frequent data
- **Image Optimization**: Compressed image storage
- **CDN Integration**: Fast content delivery
- **Connection Pooling**: Efficient database connections

### **📈 Monitoring & Analytics**
- **Health Checks**: Endpoint monitoring
- **Performance Metrics**: Response time tracking
- **Error Tracking**: Real-time error monitoring
- **Usage Analytics**: User behavior insights
- **Resource Monitoring**: Server resource tracking

### **🔧 Health Check Endpoint**
```bash
# Check server health
GET /api/health/status

# Response
{
  "status": "healthy",
  "timestamp": "2024-01-20T12:00:00Z",
  "uptime": "5d 14h 32m 18s",
  "version": "1.0.0",
  "checks": {
    "database": "healthy",
    "storage": "healthy",
    "cache": "healthy",
    "external_apis": "healthy"
  },
  "stats": {
    "activeConnections": 1247,
    "totalRequests": 2450692,
    "averageResponseTime": "45ms",
    "errorRate": "0.02%"
  }
}
```

---

## 🚀 Deployment Guide

### **☁️ Vercel Deployment (Recommended)**
```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Deploy to production
vercel --prod

# Set environment variables
vercel env add FIREBASE_SERVICE_ACCOUNT_JSON production
vercel env add JWT_SECRET production
```

### **🐳 Docker Deployment**
```dockerfile
# Dockerfile
FROM node:16-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
```

```bash
# Build and run Docker container
docker build -t lendly-backend .
docker run -p 3000:3000 --env-file .env lendly-backend
```

### **☁️ Cloud Platform Deployments**

#### **Google Cloud Run**
```bash
# Deploy to Google Cloud Run
gcloud run deploy lendly-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

#### **AWS Lambda (Serverless)**
```bash
# Install Serverless Framework
npm install -g serverless

# Deploy to AWS Lambda
serverless deploy --stage production
```

#### **Heroku Deployment**
```bash
# Login to Heroku
heroku login

# Create Heroku app
heroku create lendly-backend

# Set environment variables
heroku config:set FIREBASE_SERVICE_ACCOUNT_JSON="{...}"
heroku config:set JWT_SECRET="your-secret"

# Deploy to Heroku
git push heroku main
```

---

## 🧪 Testing Strategy

### **🔬 Testing Framework**
```bash
# Run all tests
npm test

# Run specific test suites
npm run test:unit           # Unit tests
npm run test:integration    # Integration tests
npm run test:e2e           # End-to-end tests
npm run test:load          # Load testing

# Generate coverage report
npm run test:coverage
```

### **📋 Test Categories**
- **Unit Tests**: Individual function testing
- **Integration Tests**: API endpoint testing
- **Socket Tests**: WebSocket functionality
- **Security Tests**: Authentication and authorization
- **Performance Tests**: Load and stress testing

### **🧪 Test Examples**
```javascript
// Example API test
describe('Authentication API', () => {
  test('should register new user successfully', async () => {
    const response = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@college.edu',
        password: 'TestPassword123!',
        firstName: 'John',
        lastName: 'Test'
      });
      
    expect(response.status).toBe(201);
    expect(response.body.success).toBe(true);
  });
});

// Example Socket.IO test
describe('Chat WebSocket', () => {
  test('should emit new message event', (done) => {
    clientSocket.emit('send_message', testMessage);
    
    clientSocket.on('new_message', (data) => {
      expect(data.message.content).toBe(testMessage.content);
      done();
    });
  });
});
```

---

## 📚 Additional Resources

### **📖 Documentation Links**
- **[API Documentation](api-docs.html)** - Interactive API reference
- **[Postman Collection](postman-collection.json)** - Ready-to-use API collection
- **[Database Schema](database-schema.md)** - Firestore collection structure
- **[Socket.IO Events](socket-events.md)** - Complete WebSocket event reference
- **[Deployment Guide](deployment.md)** - Detailed deployment instructions

### **🔧 Development Tools**
- **[Firebase Console](https://console.firebase.google.com)** - Database management
- **[Vercel Dashboard](https://vercel.com/dashboard)** - Deployment monitoring
- **[Postman](https://www.postman.com/)** - API testing
- **[MongoDB Compass](https://www.mongodb.com/products/compass)** - Database GUI (if using MongoDB)

### **📞 Support & Community**
- **GitHub Issues**: [Report bugs and request features](https://github.com/Arya182-ui/Lendly/issues)
- **Documentation Wiki**: [Comprehensive guides and tutorials](https://github.com/Arya182-ui/Lendly/wiki)
- **Developer Forum**: [Community discussions and support](https://github.com/Arya182-ui/Lendly/discussions)
- **Email Support**: backend-support@lendly.app

---

## 📄 License & Contribution

### **📜 License**
This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

### **🤝 Contributing**
We welcome contributions! Please read our [Contributing Guide](../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### **🙏 Acknowledgments**
- **Microsoft Imagine Cup 2026** - Platform for innovation
- **Firebase Team** - Excellent backend services
- **Express.js Community** - Robust web framework
- **Socket.IO Team** - Real-time communication made simple
- **Open Source Contributors** - Making this project possible

---

<div align="center">

**🚀 Ready to power the future of student sharing?**

[📊 API Documentation](api-docs.html) • [🐛 Report Bug](https://github.com/Arya182-ui/Lendly/issues) • [💡 Request Feature](https://github.com/Arya182-ui/Lendly/discussions)

---

**Built with ❤️ for students, by students**

*Empowering campus communities through technology* ✨

⭐ **Star the repository if this backend powers your vision!**

![GitHub stars](https://img.shields.io/github/stars/Arya182-ui/Lendly?style=social)
![GitHub forks](https://img.shields.io/github/forks/Arya182-ui/Lendly?style=social)

</div>
