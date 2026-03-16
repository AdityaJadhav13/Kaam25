"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeCollections = exports.onDocumentUpdated = exports.onDocumentCreated = exports.onFolderUpdated = exports.onFolderCreated = exports.onChatMessageCreated = exports.onAnnouncementCreated = exports.validateUserAccess = exports.enforceViolationBlock = exports.setAdminClaim = exports.changeUserRole = exports.rejectDevice = exports.removeDevice = exports.unblockUser = exports.blockUser = exports.approveDevice = exports.approveUser = exports.bootstrapUser = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
admin.initializeApp();
const db = admin.firestore();
function logAdminAction(log) {
    // Structured log for Cloud Logging queries
    console.log(JSON.stringify({
        severity: log.result === 'error' ? 'ERROR' : 'INFO',
        ...log,
    }));
}
function getSuperAdminUid() {
    // Read from super_admin.uid (set via: firebase functions:config:set super_admin.uid="...")
    const uid = functions.config().super_admin?.uid;
    if (!uid) {
        throw new functions.https.HttpsError('failed-precondition', 'SUPER_ADMIN_UID not configured');
    }
    return uid;
}
// Better admin check that queries Firestore
async function assertAdminAsync(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    // Check custom claim first (fast)
    if (context.auth.token.admin) {
        return;
    }
    // Fallback to Firestore check (for admins without custom claims set yet)
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userData = userDoc.data();
    if (userData?.role !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }
    // Set custom claim for future requests
    await admin.auth().setCustomUserClaims(context.auth.uid, { admin: true });
}
exports.bootstrapUser = functions.https.onCall(async (data, context) => {
    const { uid, email, name, photoUrl, deviceId, deviceInfo } = data;
    if (!uid || !email) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and email are required');
    }
    const superAdminUid = getSuperAdminUid();
    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    if (snap.exists) {
        return { ok: true, skipped: true };
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const isSuperAdmin = uid === superAdminUid;
    const base = {
        email,
        name: name || email,
        photoUrl: photoUrl || null,
        createdAt: now,
        lastLogin: now,
        blocked: false,
        devices: isSuperAdmin ? [deviceId] : [],
    };
    if (isSuperAdmin) {
        await userRef.set({
            ...base,
            role: 'admin',
            approved: true,
        });
        // Set custom claim so Firestore rules recognize admin
        await admin.auth().setCustomUserClaims(uid, { admin: true });
    }
    else {
        await userRef.set({
            ...base,
            role: 'member',
            approved: false,
        });
        await db.collection('login_requests').doc(`${uid}_${deviceId}`).set({
            userId: uid,
            deviceId,
            deviceInfo: deviceInfo || {},
            status: 'pending',
            createdAt: now,
        }, { merge: true });
        // Notify admins about the new pending request
        await notifyAdminsOfPendingApproval(email, name || email);
    }
    return { ok: true };
});
exports.approveUser = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid } = data;
    if (!uid)
        throw new functions.https.HttpsError('invalid-argument', 'uid required');
    // Approve user and set custom claim if they're an admin
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'approveUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userData = userDoc.data();
    // Idempotency check - if already approved, return early with indicator
    if (userData?.approved === true && userData?.blocked !== true) {
        logAdminAction({ action: 'approveUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'no-op', reason: 'Already approved' });
        return { ok: true, alreadyApproved: true };
    }
    // Find any pending login requests for this user and approve the first device
    const pendingRequests = await db.collection('login_requests')
        .where('userId', '==', uid)
        .where('status', '==', 'pending')
        .limit(1)
        .get();
    let approvedDeviceId = null;
    if (!pendingRequests.empty) {
        const request = pendingRequests.docs[0];
        const requestData = request.data();
        approvedDeviceId = requestData.deviceId;
        // Approve the login request
        await request.ref.update({ status: 'approved', approvedAt: admin.firestore.FieldValue.serverTimestamp() });
        // Add device to user's devices array
        await userRef.update({
            approved: true,
            blocked: false,
            devices: admin.firestore.FieldValue.arrayUnion(approvedDeviceId),
        });
    }
    else {
        // No pending device, just approve the user
        await userRef.set({ approved: true, blocked: false }, { merge: true });
    }
    // If user is admin, set custom claim
    if (userData?.role === 'admin') {
        await admin.auth().setCustomUserClaims(uid, { admin: true });
    }
    logAdminAction({ action: 'approveUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'success', deviceApproved: approvedDeviceId });
    // Notify the approved user
    await notifyUser(uid, '✅ Access Approved', 'Your account has been approved. Welcome to Kaam 25!', {
        type: 'user_approved',
        senderId: context.auth?.uid || '',
    });
    return { ok: true, alreadyApproved: false, deviceApproved: approvedDeviceId };
});
exports.approveDevice = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, deviceId } = data;
    if (!uid || !deviceId) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and deviceId required');
    }
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'approveDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    // Check if device already approved (idempotency)
    const userData = userDoc.data();
    const existingDevices = userData?.devices || [];
    if (existingDevices.includes(deviceId)) {
        logAdminAction({ action: 'approveDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'no-op', reason: 'Device already approved' });
        return { ok: true, alreadyApproved: true };
    }
    // Add device to user's approved devices
    await userRef.update({
        devices: admin.firestore.FieldValue.arrayUnion(deviceId),
        approved: true // Auto-approve user when approving their first device
    });
    // Update the login request status
    await db.collection('login_requests').doc(`${uid}_${deviceId}`).set({
        status: 'approved',
        handledAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    logAdminAction({ action: 'approveDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'success' });
    // Notify the user whose device was approved
    await notifyUser(uid, '📱 Device Approved', 'Your new device has been approved for access.', {
        type: 'device_approved',
        senderId: context.auth?.uid || '',
    });
    return { ok: true, alreadyApproved: false };
});
exports.blockUser = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, reason } = data;
    if (!uid)
        throw new functions.https.HttpsError('invalid-argument', 'uid required');
    // Prevent self-blocking
    if (context.auth?.uid === uid) {
        logAdminAction({ action: 'blockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'rejected', reason: 'Self-blocking prevented' });
        throw new functions.https.HttpsError('permission-denied', 'You cannot block yourself');
    }
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'blockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userData = userDoc.data();
    // Idempotency check - if already blocked, return early
    if (userData?.blocked === true) {
        logAdminAction({ action: 'blockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'no-op', reason: 'Already blocked' });
        return { ok: true, alreadyBlocked: true };
    }
    await userRef.set({
        blocked: true,
        approved: false,
        blockedAt: admin.firestore.FieldValue.serverTimestamp(),
        blockedReason: reason || 'Blocked by administrator'
    }, { merge: true });
    logAdminAction({ action: 'blockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'success' });
    // Notify the blocked user
    await notifyUser(uid, '🚫 Account Suspended', reason || 'Your access has been suspended by an administrator.', {
        type: 'user_blocked',
        senderId: context.auth?.uid || '',
    });
    return { ok: true, alreadyBlocked: false };
});
exports.unblockUser = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid } = data;
    if (!uid)
        throw new functions.https.HttpsError('invalid-argument', 'uid required');
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'unblockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userData = userDoc.data();
    // Idempotency check - if not blocked, return early
    if (userData?.blocked !== true) {
        logAdminAction({ action: 'unblockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'no-op', reason: 'User not blocked' });
        return { ok: true, wasNotBlocked: true };
    }
    await userRef.update({
        blocked: false,
        approved: true,
        unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
        blockedReason: admin.firestore.FieldValue.delete()
    });
    logAdminAction({ action: 'unblockUser', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'success' });
    return { ok: true, wasNotBlocked: false };
});
exports.removeDevice = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, deviceId } = data;
    if (!uid || !deviceId) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and deviceId required');
    }
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'removeDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    // Remove device from user's approved devices
    await userRef.update({
        devices: admin.firestore.FieldValue.arrayRemove(deviceId)
    });
    // Update the login request status to 'removed'
    const loginRequestRef = db.collection('login_requests').doc(`${uid}_${deviceId}`);
    const loginRequestDoc = await loginRequestRef.get();
    if (loginRequestDoc.exists) {
        await loginRequestRef.update({
            status: 'removed',
            removedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    logAdminAction({ action: 'removeDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'success' });
    return { ok: true };
});
// Reject a pending device request (without blocking the user)
exports.rejectDevice = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, deviceId, reason } = data;
    if (!uid || !deviceId) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and deviceId required');
    }
    const loginRequestRef = db.collection('login_requests').doc(`${uid}_${deviceId}`);
    const loginRequestDoc = await loginRequestRef.get();
    if (!loginRequestDoc.exists) {
        logAdminAction({ action: 'rejectDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'error', reason: 'Login request not found' });
        throw new functions.https.HttpsError('not-found', 'Login request not found');
    }
    // Idempotency check - if already rejected, return early
    const requestData = loginRequestDoc.data();
    if (requestData?.status === 'rejected') {
        logAdminAction({ action: 'rejectDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'no-op', reason: 'Already rejected' });
        return { ok: true, alreadyRejected: true };
    }
    // Update the login request status to 'rejected'
    await loginRequestRef.update({
        status: 'rejected',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedReason: reason || 'Device request rejected by administrator',
    });
    logAdminAction({ action: 'rejectDevice', actor: context.auth?.uid, target: `${uid}:${deviceId}`, timestamp: new Date().toISOString(), result: 'success' });
    // Notify the user whose device was rejected
    await notifyUser(uid, '📱 Device Rejected', reason || 'Your device request was rejected.', {
        type: 'device_rejected',
        senderId: context.auth?.uid || '',
    });
    return { ok: true, alreadyRejected: false };
});
// Change user role (promote to admin or demote to member)
exports.changeUserRole = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, newRole } = data;
    if (!uid || !newRole || !['admin', 'member'].includes(newRole)) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and valid newRole (admin/member) required');
    }
    // Prevent self-demotion (admin can't demote themselves)
    if (context.auth?.uid === uid && newRole === 'member') {
        logAdminAction({ action: 'changeUserRole', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'rejected', reason: 'Self-demotion prevented' });
        throw new functions.https.HttpsError('permission-denied', 'You cannot demote yourself');
    }
    const userRef = db.collection('users').doc(uid);
    const userDoc = await userRef.get();
    if (!userDoc.exists) {
        logAdminAction({ action: 'changeUserRole', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'error', reason: 'User not found' });
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    // Idempotency check - if already same role, return early
    const userData = userDoc.data();
    if (userData?.role === newRole) {
        logAdminAction({ action: 'changeUserRole', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'no-op', reason: `Already ${newRole}` });
        return { ok: true, alreadySameRole: true };
    }
    // Update role in Firestore
    await userRef.update({
        role: newRole,
        roleChangedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // Update custom claims
    await admin.auth().setCustomUserClaims(uid, { admin: newRole === 'admin' });
    logAdminAction({ action: 'changeUserRole', actor: context.auth?.uid, target: uid, timestamp: new Date().toISOString(), result: 'success', reason: `Role changed to ${newRole}` });
    // Notify the user about their role change
    const roleLabel = newRole === 'admin' ? 'Admin 🛡️' : 'Member';
    await notifyUser(uid, '🔄 Role Updated', `You have been ${newRole === 'admin' ? 'promoted to' : 'changed to'} ${roleLabel}.`, {
        type: 'role_changed',
        newRole: newRole,
        senderId: context.auth?.uid || '',
    });
    return { ok: true, alreadySameRole: false };
});
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const { uid, admin: isAdmin } = data;
    if (!uid || typeof isAdmin !== 'boolean') {
        throw new functions.https.HttpsError('invalid-argument', 'uid and admin flag required');
    }
    await admin.auth().setCustomUserClaims(uid, { admin: isAdmin });
    return { ok: true };
});
// ========== SECURITY VIOLATION ENFORCEMENT ==========
/**
 * Firestore Trigger: Enforce automatic blocking on violation threshold
 * Triggered when users.screenshotAttempts is updated
 */
exports.enforceViolationBlock = functions.firestore
    .document('users/{uid}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const uid = context.params.uid;
    // Check if screenshotAttempts was incremented
    const beforeAttempts = before.screenshotAttempts || 0;
    const afterAttempts = after.screenshotAttempts || 0;
    if (afterAttempts <= beforeAttempts) {
        return null; // No violation increase
    }
    const VIOLATION_THRESHOLD = 3;
    // Auto-block if threshold exceeded
    if (afterAttempts >= VIOLATION_THRESHOLD && !after.blocked) {
        console.log(`🚨 Auto-blocking user ${uid} for ${afterAttempts} violations`);
        await change.after.ref.update({
            blocked: true,
            approved: false,
            blockedAt: admin.firestore.FieldValue.serverTimestamp(),
            blockedReason: `Automatic suspension: ${afterAttempts} security violations detected`,
        });
        // Send notification to all admins
        await notifyAdminsOfViolation(uid, after.email, afterAttempts);
    }
    return null;
});
/**
 * Notify admins via FCM when user is blocked for violations
 */
async function notifyAdminsOfViolation(violatorUid, violatorEmail, attempts) {
    try {
        const adminsSnapshot = await db.collection('users')
            .where('role', '==', 'admin')
            .get();
        if (adminsSnapshot.empty) {
            console.log('No admins to notify');
            return;
        }
        const fcmTokens = [];
        adminsSnapshot.forEach((doc) => {
            const data = doc.data();
            if (data.fcmToken) {
                fcmTokens.push(data.fcmToken);
            }
        });
        if (fcmTokens.length === 0) {
            console.log('No admin FCM tokens available');
            return;
        }
        const message = {
            notification: {
                title: '🚨 Security Violation',
                body: `User ${violatorEmail} blocked after ${attempts} screenshot attempts`,
            },
            data: {
                type: 'security_violation',
                violatorUid,
                violatorEmail,
                attempts: attempts.toString(),
            },
            tokens: fcmTokens,
        };
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`✅ Notified ${response.successCount} admins of violation`);
    }
    catch (error) {
        console.error('❌ Failed to notify admins:', error);
    }
}
/**
 * Callable function: Validate user is not blocked
 * Called before granting access to protected resources
 */
exports.validateUserAccess = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userData = userDoc.data();
    if (userData.blocked) {
        throw new functions.https.HttpsError('permission-denied', userData.blockedReason || 'Your access has been suspended');
    }
    if (!userData.approved) {
        throw new functions.https.HttpsError('permission-denied', 'Access pending approval');
    }
    return {
        ok: true,
        user: {
            uid: userDoc.id,
            email: userData.email,
            name: userData.name,
            role: userData.role,
            screenshotAttempts: userData.screenshotAttempts || 0,
        },
    };
});
// ========== NOTIFICATIONS ==========
/**
 * Firestore Trigger: Send FCM notification when new announcement is created
 */
exports.onAnnouncementCreated = functions.firestore
    .document('announcements/{announcementId}')
    .onCreate(async (snap, context) => {
    const announcement = snap.data();
    const announcementId = context.params.announcementId;
    console.log(`📢 New announcement created: ${announcement.title}`);
    try {
        const message = {
            notification: {
                title: `📢 ${announcement.title}`,
                body: announcement.description?.substring(0, 200) || '',
            },
            data: {
                type: 'announcement',
                announcementId: announcementId,
                announcementType: announcement.type || 'general',
                actionRequired: announcement.actionRequired?.toString() || 'false',
                senderId: announcement.createdBy || '',
                senderName: announcement.createdByName || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(message);
        console.log(`✅ Announcement notification sent`);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending announcement notification:', error);
        return { success: false, error };
    }
});
/**
 * Firestore Trigger: Send FCM notification when new chat message is posted
 * NOTE: Path is chats/team_chat/messages (subcollection), NOT chat_messages
 */
exports.onChatMessageCreated = functions.firestore
    .document('chats/team_chat/messages/{messageId}')
    .onCreate(async (snap, context) => {
    const message = snap.data();
    // Don't send notification for file-only messages without text
    if (!message.content || message.content.trim() === '') {
        return null;
    }
    try {
        const notification = {
            notification: {
                title: `💬 ${message.senderName}`,
                body: message.messageType === 'file' ? '📎 Sent a file' : message.content?.substring(0, 200),
            },
            data: {
                type: 'chat',
                messageId: context.params.messageId,
                senderId: message.senderId || '',
                senderName: message.senderName || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(notification);
        console.log(`✅ Chat notification sent for message from ${message.senderName}`);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending chat notification:', error);
        return { success: false, error };
    }
});
// ========== FOLDER & FILE NOTIFICATIONS ==========
/**
 * Firestore Trigger: Send FCM notification when a new folder is created
 */
exports.onFolderCreated = functions.firestore
    .document('folders/{folderId}')
    .onCreate(async (snap, context) => {
    const folder = snap.data();
    const folderId = context.params.folderId;
    try {
        // Look up creator name
        let creatorName = 'Someone';
        if (folder.createdBy) {
            const userDoc = await db.collection('users').doc(folder.createdBy).get();
            if (userDoc.exists) {
                creatorName = userDoc.data()?.name || creatorName;
            }
        }
        const message = {
            notification: {
                title: '📁 New Folder',
                body: `${creatorName} created "${folder.name}"`,
            },
            data: {
                type: 'folder_created',
                folderId: folderId,
                parentId: folder.parentId || '',
                senderId: folder.createdBy || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(message);
        console.log(`✅ Folder created notification sent: ${folder.name}`);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending folder notification:', error);
        return { success: false, error };
    }
});
/**
 * Firestore Trigger: Send FCM notification when a folder is renamed
 */
exports.onFolderUpdated = functions.firestore
    .document('folders/{folderId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Only notify on name change
    if (before.name === after.name)
        return null;
    try {
        let editorName = 'Someone';
        // Use updatedBy if available, else createdBy
        const editorUid = after.updatedBy || after.createdBy;
        if (editorUid) {
            const userDoc = await db.collection('users').doc(editorUid).get();
            if (userDoc.exists) {
                editorName = userDoc.data()?.name || editorName;
            }
        }
        const message = {
            notification: {
                title: '📁 Folder Renamed',
                body: `${editorName} renamed "${before.name}" → "${after.name}"`,
            },
            data: {
                type: 'folder_renamed',
                folderId: context.params.folderId,
                parentId: after.parentId || '',
                senderId: editorUid || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(message);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending folder rename notification:', error);
        return { success: false, error };
    }
});
/**
 * Firestore Trigger: Send FCM notification when a new file/document is uploaded
 */
exports.onDocumentCreated = functions.firestore
    .document('documents/{documentId}')
    .onCreate(async (snap, context) => {
    const doc = snap.data();
    const documentId = context.params.documentId;
    try {
        let uploaderName = 'Someone';
        if (doc.uploadedBy) {
            const userDoc = await db.collection('users').doc(doc.uploadedBy).get();
            if (userDoc.exists) {
                uploaderName = userDoc.data()?.name || uploaderName;
            }
        }
        const message = {
            notification: {
                title: '📄 New File',
                body: `${uploaderName} uploaded "${doc.fileName}"`,
            },
            data: {
                type: 'file_uploaded',
                documentId: documentId,
                folderId: doc.folderId || '',
                senderId: doc.uploadedBy || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(message);
        console.log(`✅ File upload notification sent: ${doc.fileName}`);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending file upload notification:', error);
        return { success: false, error };
    }
});
/**
 * Firestore Trigger: Send FCM notification when a document is renamed
 */
exports.onDocumentUpdated = functions.firestore
    .document('documents/{documentId}')
    .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    // Only notify on file name change
    if (before.fileName === after.fileName)
        return null;
    try {
        let editorName = 'Someone';
        const editorUid = after.updatedBy || after.uploadedBy;
        if (editorUid) {
            const userDoc = await db.collection('users').doc(editorUid).get();
            if (userDoc.exists) {
                editorName = userDoc.data()?.name || editorName;
            }
        }
        const message = {
            notification: {
                title: '📄 File Renamed',
                body: `${editorName} renamed "${before.fileName}" → "${after.fileName}"`,
            },
            data: {
                type: 'file_renamed',
                documentId: context.params.documentId,
                folderId: after.folderId || '',
                senderId: editorUid || '',
            },
            topic: 'all_users',
        };
        await admin.messaging().send(message);
        return { success: true };
    }
    catch (error) {
        console.error('❌ Error sending file rename notification:', error);
        return { success: false, error };
    }
});
// ========== ADMIN → USER DIRECT NOTIFICATIONS ==========
/**
 * Send a direct FCM notification to a specific user by UID.
 * Falls back silently if user has no token or notifications disabled.
 */
async function notifyUser(targetUid, title, body, dataPayload) {
    try {
        const userDoc = await db.collection('users').doc(targetUid).get();
        if (!userDoc.exists)
            return;
        const userData = userDoc.data();
        if (!userData)
            return;
        // Respect user's notification preference
        if (userData.notificationsEnabled === false)
            return;
        const fcmToken = userData.fcmToken;
        if (!fcmToken)
            return;
        await admin.messaging().send({
            notification: { title, body },
            data: dataPayload,
            token: fcmToken,
        });
        console.log(`✅ Direct notification sent to ${targetUid}`);
    }
    catch (error) {
        // Token might be stale — clean it up
        const errMsg = error?.code;
        if (errMsg === 'messaging/registration-token-not-registered') {
            await db.collection('users').doc(targetUid).update({
                fcmToken: admin.firestore.FieldValue.delete(),
                fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
            });
            console.log(`🧹 Cleaned stale FCM token for ${targetUid}`);
        }
        else {
            console.error(`❌ Failed to notify ${targetUid}:`, error);
        }
    }
}
/**
 * Send notification to all admins about a pending login request
 */
async function notifyAdminsOfPendingApproval(userEmail, userName) {
    try {
        const message = {
            notification: {
                title: '👤 New Login Request',
                body: `${userName || userEmail} is waiting for approval`,
            },
            data: {
                type: 'pending_approval',
                userEmail: userEmail,
            },
            topic: 'admin_notifications',
        };
        await admin.messaging().send(message);
        console.log('✅ Pending approval notification sent to admins');
    }
    catch (error) {
        console.error('❌ Failed to notify admins of pending approval:', error);
    }
}
// ========== INITIALIZE COLLECTIONS ==========
// Creates placeholder documents so collections appear in Firebase Console
exports.initializeCollections = functions.https.onCall(async (data, context) => {
    await assertAdminAsync(context);
    const results = {};
    // Create team_chat parent document if it doesn't exist
    const teamChatRef = db.collection('chats').doc('team_chat');
    const teamChatDoc = await teamChatRef.get();
    if (!teamChatDoc.exists) {
        await teamChatRef.set({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            name: 'Team Chat',
            type: 'group',
        });
        results['chats/team_chat'] = true;
    }
    else {
        results['chats/team_chat'] = false; // Already exists
    }
    // Note: announcements collection will auto-create when first announcement is made
    // We don't need a placeholder for it
    logAdminAction({
        action: 'initializeCollections',
        actor: context.auth?.uid,
        target: null,
        timestamp: new Date().toISOString(),
        result: 'success'
    });
    return { ok: true, created: results };
});
//# sourceMappingURL=index.js.map