#!/bin/bash
# Test8 Monitoring Script

echo "════════════════════════════════════════════════════════════════"
echo "📊 TEST8 MONITORING DASHBOARD"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Check progress
sf apex run --file check_test8_progress.apex --target-org MassiveUploadOrg 2>&1 | \
  grep -E "Scheduled Partitions|Partition_|StaggeredPartition_|Total|Test8 Opportunities|Success Rate|✅|⚠️|Projected|Active Jobs"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "💡 Test8 Improvements:"
echo "   • Batch delay: 20-30s (was 10-20s)"
echo "   • Partition stagger: 1.5h (was 1h)" 
echo "   • Retry: Exponential backoff 2s/5s/10s"
echo "   • Max retries: 3 (was 2)"
echo "   • Expected: 91-92% (Test7: 90.16%)"
echo "════════════════════════════════════════════════════════════════"

