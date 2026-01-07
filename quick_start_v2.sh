#!/bin/bash

# Quick Start Script for V2
# Run this when API limits are available

echo "════════════════════════════════════════════════════════════════"
echo "🚀 V2 DEPLOYMENT & START"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload

echo "Step 1: Stopping old jobs..."
sf apex run --file emergency_stop.apex --target-org MassiveUploadOrg
echo ""

echo "Step 2: Checking API usage..."
sf apex run --file check_api_usage.apex --target-org MassiveUploadOrg
echo ""

echo "Step 3: Deploying V2..."
sf project deploy start \
  --source-dir force-app/main/default/classes/DynamicPartitionProcessorV2.cls \
  --source-dir force-app/main/default/classes/DynamicPartitionProcessorV2.cls-meta.xml \
  --target-org MassiveUploadOrg
echo ""

echo "Step 4: Starting V2..."
sf apex run --file start_v2.apex --target-org MassiveUploadOrg
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "✅ V2 STARTED!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Monitor progress:"
echo "  sf apex run --file check_progress_v2.apex --target-org MassiveUploadOrg"
echo ""
echo "Expected completion: 2-4 hours"
echo "════════════════════════════════════════════════════════════════"




