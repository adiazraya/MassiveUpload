#!/bin/bash
# Test7 Monitoring Script

echo "════════════════════════════════════════════════════════════════"
echo "📊 TEST7 MONITORING DASHBOARD"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check partition progress
echo "Checking partition progress..."
sf apex run --file check_staggered_progress.apex --target-org MassiveUploadOrg 2>&1 | grep -E "Partition_|StaggeredPartition_|Running Jobs"

echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""

# Check Test7 count and success rate
sf apex run --file check_test7_early.apex --target-org MassiveUploadOrg 2>&1 | grep -E "Test7 Opportunities|Success Rate|✅|⚠️|❌"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "💡 Run this script every 10 minutes to monitor progress"
echo "════════════════════════════════════════════════════════════════"


