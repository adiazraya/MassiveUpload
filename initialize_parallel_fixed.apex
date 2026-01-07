// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZE PARALLEL SYNC - FIXED for Hierarchy Custom Setting
// Uses proper SetupOwnerId for Hierarchy Custom Setting
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 INITIALIZING PARALLEL SYNC (10 PARTITIONS) - FIXED');
System.debug('═══════════════════════════════════════════════════════════════');

Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Salesforce opportunities: ' + currentCount);
System.debug('Target: 2,000,000');
System.debug('');

// Get org ID for Hierarchy Custom Setting
String orgId = UserInfo.getOrganizationId();

// Create/reset 10 partition trackers
for (Integer i = 0; i < 10; i++) {
    String partitionName = 'Partition' + i;
    
    List<DataCloudSyncProgress__c> existing = [
        SELECT Id FROM DataCloudSyncProgress__c WHERE Name = :partitionName LIMIT 1
    ];
    
    DataCloudSyncProgress__c progress;
    if (!existing.isEmpty()) {
        progress = existing[0];
    } else {
        progress = new DataCloudSyncProgress__c(
            Name = partitionName,
            SetupOwnerId = orgId
        );
    }
    
    progress.PartitionId__c = i;
    progress.CurrentOffset__c = 0;
    progress.TotalProcessed__c = 0;
    progress.TotalBulkAPICalls__c = 0;
    progress.Status__c = 'Initialized';
    progress.LastBatchStarted__c = null;
    
    upsert progress;
    System.debug('✓ ' + partitionName + ' initialized (offsets ' + (i*200000) + '-' + ((i+1)*200000-1) + ')');
}

System.debug('');
System.debug('✅ All 10 partitions initialized!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('NEXT: Create Scheduled Flow');
System.debug('  1. Setup → Flows → New Flow → Scheduled');
System.debug('  2. Every 5 minutes');
System.debug('  3. Action: "Check and Start Parallel Batches"');
System.debug('  4. Activate!');
System.debug('');
System.debug('Expected completion: 8-12 hours for 2M records! 🚀');
System.debug('════════════════════════════════════════════════════════════════════');




