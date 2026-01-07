// Check existing progress and start
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 CHECKING EXISTING PROGRESS');
System.debug('════════════════════════════════════════════════════════════════');

List<DataCloudPartition__c> progress = [
    SELECT Name, Status__c, CurrentOffset__c, TotalProcessed__c
    FROM DataCloudPartition__c
    WHERE Name = 'DailySync'
];

if (!progress.isEmpty()) {
    System.debug('Found existing progress:');
    System.debug('  Status: ' + progress[0].Status__c);
    System.debug('  Offset: ' + progress[0].CurrentOffset__c);
    System.debug('  Processed: ' + progress[0].TotalProcessed__c);
    System.debug('');
    
    if (progress[0].Status__c == 'Completed') {
        System.debug('⚠️  Already completed. Resetting for new run...');
        delete progress;
    }
}

System.debug('Starting orchestrator...');
HourlyOrchestrator orch = new HourlyOrchestrator();
orch.execute(null);

System.debug('✓ Orchestrator executed');
System.debug('Check: Setup → Apex Jobs');
System.debug('════════════════════════════════════════════════════════════════');




