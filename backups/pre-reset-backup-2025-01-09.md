# Pre-Reset Backup - January 9, 2025

## Backup Purpose
This backup was created before performing a Firebase Authentication reset.

## What will be LOST during reset:
- ❌ All test users in Firebase Authentication
- ❌ All authentication sessions and tokens
- ❌ All login requests (in Firestore `login_requests` collection)
- ❌ Custom user claims

## What will be PRESERVED:
- ✅ Firestore database structure and data
- ✅ Firestore security rules (backed up below)
- ✅ Storage rules (backed up below)
- ✅ Cloud Functions (backed up below)
- ✅ User documents in Firestore (can be cleaned up separately if needed)

## Configuration Notes
- Firebase project: [Check google-services.json for project details]
- Super Admin UID: Configured via Firebase Functions config
- Current security model: Role-based (admin/member) with approval workflow

## Backed Up Files (in backups/ directory)
✅ `firestore.rules.backup-2025-01-09` - Firestore security rules
✅ `storage.rules.backup-2025-01-09` - Storage security rules  
✅ `functions.backup-2025-01-09/` - Complete Cloud Functions code and config

## Restoration Instructions
If you need to restore after reset:
```bash
# Restore Firestore rules
cp backups/firestore.rules.backup-2025-01-09 firestore.rules
firebase deploy --only firestore:rules

# Restore Storage rules
cp backups/storage.rules.backup-2025-01-09 storage.rules
firebase deploy --only storage

# Restore Functions (if needed)
cp -r backups/functions.backup-2025-01-09/* functions/
cd functions && npm install && npm run deploy
```

---

