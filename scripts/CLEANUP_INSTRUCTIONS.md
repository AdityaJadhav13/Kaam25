# Firestore Cleanup Guide

## Option 1: Firebase Console (Manual - Recommended for Safety)

1. **Go to Firebase Console** → Firestore Database
2. **Delete these collections:**
   - Click on `users` → Select all documents → Delete
   - Click on `login_requests` → Select all documents → Delete  
   - Click on `presence` → Select all documents → Delete

3. **Keep these collections** (if they have data):
   - `folders` - Your document folders
   - `documents` - Your uploaded documents
   - `chats/team_chat/messages` - Team chat messages
   - `announcements` - Any announcements

## Option 2: Automated Script (Requires Service Account)

If you have a Firebase service account key:

```bash
# Install firebase-admin
cd scripts
npm install firebase-admin readline

# Set your private key as env variable
export FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Run cleanup
node cleanup-firestore.js
```

## Manual Firestore Rules Update (After Cleanup)

Since you're resetting, you may want to temporarily relax rules for testing:

```javascript
// Temporary testing rules - REPLACE LATER
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**⚠️ Deploy strict rules before production!**

