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
exports.setAdminClaim = exports.blockUser = exports.approveDevice = exports.approveUser = exports.bootstrapUser = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
admin.initializeApp();
const db = admin.firestore();
function getSuperAdminUid() {
    const uid = functions.config().super?.admin_uid;
    if (!uid) {
        throw new functions.https.HttpsError('failed-precondition', 'SUPER_ADMIN_UID not configured');
    }
    return uid;
}
function assertAdmin(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
    }
    if (!context.auth.token.admin) {
        throw new functions.https.HttpsError('permission-denied', 'Admin only');
    }
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
    }
    return { ok: true };
});
exports.approveUser = functions.https.onCall(async (data, context) => {
    assertAdmin(context);
    const { uid } = data;
    if (!uid)
        throw new functions.https.HttpsError('invalid-argument', 'uid required');
    await db.collection('users').doc(uid).set({ approved: true }, { merge: true });
    return { ok: true };
});
exports.approveDevice = functions.https.onCall(async (data, context) => {
    assertAdmin(context);
    const { uid, deviceId } = data;
    if (!uid || !deviceId) {
        throw new functions.https.HttpsError('invalid-argument', 'uid and deviceId required');
    }
    const userRef = db.collection('users').doc(uid);
    await userRef.update({ devices: admin.firestore.FieldValue.arrayUnion(deviceId) });
    await db.collection('login_requests').doc(`${uid}_${deviceId}`).set({
        status: 'approved',
        handledAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.blockUser = functions.https.onCall(async (data, context) => {
    assertAdmin(context);
    const { uid } = data;
    if (!uid)
        throw new functions.https.HttpsError('invalid-argument', 'uid required');
    await db.collection('users').doc(uid).set({ blocked: true, approved: false }, { merge: true });
    return { ok: true };
});
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
    assertAdmin(context);
    const { uid, admin: isAdmin } = data;
    if (!uid || typeof isAdmin !== 'boolean') {
        throw new functions.https.HttpsError('invalid-argument', 'uid and admin flag required');
    }
    await admin.auth().setCustomUserClaims(uid, { admin: isAdmin });
    return { ok: true };
});
//# sourceMappingURL=index.js.map