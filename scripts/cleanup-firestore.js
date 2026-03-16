#!/usr/bin/env node

/**
 * Firestore Cleanup Script
 * Deletes all documents from users and login_requests collections
 * Run with: node scripts/cleanup-firestore.js
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin
const serviceAccount = require('../android/app/google-services.json');

admin.initializeApp({
  credential: admin.credential.cert({
    projectId: serviceAccount.project_info.project_id,
    clientEmail: serviceAccount.client[0].client_email || 'firebase-adminsdk@' + serviceAccount.project_info.project_id + '.iam.gserviceaccount.com',
    privateKey: process.env.FIREBASE_PRIVATE_KEY || ''
  })
});

const db = admin.firestore();

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function deleteCollection(collectionPath, batchSize = 100) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  console.log(`Deleted ${batchSize} documents`);

  // Recurse on the next process tick to avoid blocking
  process.nextTick(() => {
    deleteQueryBatch(query, resolve);
  });
}

async function main() {
  console.log('\n🗑️  FIRESTORE CLEANUP SCRIPT\n');
  console.log('This will delete ALL documents from:');
  console.log('  - users collection');
  console.log('  - login_requests collection');
  console.log('  - presence collection');
  console.log('\n⚠️  THIS ACTION CANNOT BE UNDONE!\n');

  rl.question('Type "DELETE" to confirm: ', async (answer) => {
    if (answer !== 'DELETE') {
      console.log('❌ Cleanup cancelled');
      rl.close();
      process.exit(0);
    }

    try {
      console.log('\n🧹 Cleaning up Firestore...\n');

      console.log('Deleting users collection...');
      await deleteCollection('users');
      console.log('✅ Users collection cleaned\n');

      console.log('Deleting login_requests collection...');
      await deleteCollection('login_requests');
      console.log('✅ Login requests collection cleaned\n');

      console.log('Deleting presence collection...');
      await deleteCollection('presence');
      console.log('✅ Presence collection cleaned\n');

      console.log('✅ Firestore cleanup complete!\n');
      
    } catch (error) {
      console.error('❌ Error during cleanup:', error);
      process.exit(1);
    }

    rl.close();
    process.exit(0);
  });
}

main();
