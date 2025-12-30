# 🚀 Quick Start: Testing Email/Password Authentication

## Step 1: Enable in Firebase Console (REQUIRED)

1. Go to https://console.firebase.google.com/
2. Select project: **chalmumbai**
3. Click **Authentication** → **Sign-in method** tab
4. Find **Email/Password** and click it
5. Toggle **Enable** switch
6. Click **Save**

## Step 2: Create Test User

### Option A: Firebase Console
1. Go to **Authentication** → **Users** tab
2. Click **Add user** button
3. Enter:
   - Email: `test@example.com`
   - Password: `test123456`
4. Click **Add user**

### Option B: Firestore (After Google sign-in)
1. User signs in with Google first
2. You (admin) approve them in Admin Panel
3. User can then use email/password

## Step 3: Approve User (REQUIRED)

### In Firestore Console:
1. Go to **Firestore Database**
2. Open `users` collection
3. Find the user document (by email)
4. Set these fields:
   ```
   approved: true
   blocked: false
   ```

### Or in Admin Panel:
1. Run the app and sign in as admin
2. Go to Admin Panel
3. Find user in pending approvals
4. Click "Approve"

## Step 4: Approve Device (REQUIRED)

### In Admin Panel:
1. User must sign in once (will be pending)
2. Go to **Admin Panel** → **Login Requests**
3. Find the user's device request
4. Click **Approve**

## Step 5: Test Authentication

1. Run the app: `flutter run -d macos`
2. On login page, enter:
   - Email: `test@example.com`
   - Password: `test123456`
3. Click **Sign In**
4. Should successfully authenticate!

## 🔍 View Debug Logs

Check the console/terminal for detailed logs:

```
🔐 Attempting email/password sign-in for: test@example.com
✅ Email/password sign-in successful
🔍 Auth Debug:
  UID: xxx
  Email: test@example.com
  ...
🔍 Firestore Debug:
  Approved: true
  Blocked: false
  ...
```

## ❌ Common Errors

### "Email/password authentication is not enabled"
**Fix**: Complete Step 1 (Enable in Firebase Console)

### "No account found with this email"
**Fix**: Complete Step 2 (Create test user)

### "Incorrect password"
**Fix**: Check password is correct (min 6 characters)

### "Pending Approval"
**Fix**: Complete Step 3 (Approve user in Firestore/Admin Panel)

### "Device Pending"
**Fix**: Complete Step 4 (Approve device in Admin Panel)

## 📝 Current Test Credentials

After setup, you can use:
- **Email**: `test@example.com`
- **Password**: `test123456`

**Note**: You must complete all 4 steps above before testing!

## 🎯 Quick Check

Run this to verify no code errors:
```bash
cd kaam25_app
flutter analyze
```

Should show: ✅ **No issues found!**

## 📚 Full Documentation

- [FIREBASE_AUTH_SETUP.md](FIREBASE_AUTH_SETUP.md) - Complete setup guide
- [AUTHENTICATION_IMPROVEMENTS.md](AUTHENTICATION_IMPROVEMENTS.md) - Technical details

---

**Need help?** Check the debug logs in your terminal when running the app!
