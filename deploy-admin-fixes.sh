#!/bin/bash

# Deployment Script for Kaam25 Admin Panel Fixes
# This script builds and deploys the updated Cloud Functions and Firestore rules

set -e  # Exit on error

echo "🚀 Starting Kaam25 Admin Panel Deployment"
echo "=========================================="

# Navigate to project root
cd "$(dirname "$0")"

echo ""
echo "📦 Step 1: Building Cloud Functions..."
cd functions
npm run build
if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions built successfully"
else
    echo "❌ Failed to build Cloud Functions"
    exit 1
fi
cd ..

echo ""
echo "🔐 Step 2: Deploying Firestore Security Rules..."
firebase deploy --only firestore:rules --project chalmumbai
if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully"
else
    echo "⚠️  Warning: Firestore rules deployment had issues"
fi

echo ""
echo "☁️  Step 3: Deploying Cloud Functions..."
firebase deploy --only functions --project chalmumbai
if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions deployed successfully"
else
    echo "❌ Failed to deploy Cloud Functions"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo ""
echo "What was fixed:"
echo "  1. Admin authentication now checks Firestore role"
echo "  2. Custom claims are automatically set for admins"
echo "  3. Device approval auto-approves users"
echo "  4. Block user includes reason and timestamp"
echo "  5. UI shows loading states and better feedback"
echo "  6. Confirmation dialog for blocking users"
echo ""
echo "Next steps:"
echo "  1. Hot restart your app (press 'R' in terminal)"
echo "  2. Navigate to Admin Panel"
echo "  3. Test user and device approvals"
echo ""
