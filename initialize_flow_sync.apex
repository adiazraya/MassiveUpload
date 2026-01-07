// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZE FLOW-ORCHESTRATED SYNC (PRODUCTION READY!)
// Run this ONCE to set up the sync starting from current position
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 INITIALIZING FLOW-ORCHESTRATED SYNC');
System.debug('═══════════════════════════════════════════════════════════════');

// Get current opportunity count
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Salesforce opportunities: ' + currentCount);

// Create or reset progress tracker
List<DataCloudSyncProgress__c> existing = [
    SELECT Id FROM DataCloudSyncProgress__c WHERE Name = 'Default' LIMIT 1
];

DataCloudSyncProgress__c progress;
if (!existing.isEmpty()) {
    progress = existing[0];
    System.debug('Found existing progress tracker');
} else {
    progress = new DataCloudSyncProgress__c(Name = 'Default');
    System.debug('Creating new progress tracker');
}

// Set initial values
progress.CurrentOffset__c = 0;  // Start from beginning (will UPSERT existing)
progress.TotalProcessed__c = 0;
progress.TotalBulkAPICalls__c = 0;
progress.Status__c = 'Initialized';
progress.LastBatchStarted__c = null;

upsert progress;

System.debug('');
System.debug('✅ Progress tracker initialized!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('NEXT STEPS - CREATE THE SCHEDULED FLOW:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('1. Go to: Setup → Flows → New Flow → Scheduled Flow');
System.debug('2. Configure:');
System.debug('   - Object: [any] or leave empty');
System.debug('   - Schedule: Every 5 minutes');
System.debug('   - Start: Now');
System.debug('');
System.debug('3. Add Action Element:');
System.debug('   - Search: "Check and Start Batch"');
System.debug('   - Select the BatchOrchestrator action');
System.debug('   - No input parameters needed');
System.debug('');
System.debug('4. Save & Activate the Flow');
System.debug('');
System.debug('5. The Flow will:');
System.debug('   - Run every 5 minutes');
System.debug('   - Check if batch is running');
System.debug('   - If not, start next batch');
System.debug('   - Process 2000 records per batch');
System.debug('   - Continue until all 2M records processed');
System.debug('');
System.debug('6. Monitor progress:');
System.debug('   - Run: SELECT * FROM DataCloudSyncProgress__c');
System.debug('   - Check CurrentOffset__c increasing');
System.debug('   - Or run count_comparison.apex');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('PRODUCTION BENEFITS:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('✅ No chaining limits - Flow handles orchestration');
System.debug('✅ No scheduler bugs - Only 1 scheduled Flow');
System.debug('✅ Self-healing - Restarts if crashes');
System.debug('✅ Progress tracking - Always know where you are');
System.debug('✅ All in Salesforce - No external systems needed');
System.debug('');
System.debug('Ready for nightly 2M record loads! 🎯');
System.debug('════════════════════════════════════════════════════════════════════');




