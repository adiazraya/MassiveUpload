// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZE PARALLEL SYNC - DataCloudPartition__c Version
// Creates 10 partition records for parallel processing
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 INITIALIZING PARALLEL SYNC (10 PARTITIONS)');
System.debug('═══════════════════════════════════════════════════════════════');

Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Salesforce opportunities: ' + currentCount);
System.debug('Target: 2,000,000');
System.debug('');

// Delete any existing records first
List<DataCloudPartition__c> existing = [SELECT Id FROM DataCloudPartition__c];
if (!existing.isEmpty()) {
    delete existing;
    System.debug('✓ Deleted ' + existing.size() + ' existing partition records');
}

// Create 10 partition records
List<DataCloudPartition__c> partitions = new List<DataCloudPartition__c>();

for (Integer i = 0; i < 10; i++) {
    String partitionName = 'Partition' + i;
    
    DataCloudPartition__c progress = new DataCloudPartition__c(
        Name = partitionName,
        PartitionId__c = i,
        CurrentOffset__c = 0,
        TotalProcessed__c = 0,
        TotalBulkAPICalls__c = 0,
        Status__c = 'Initialized',
        LastBatchStarted__c = null
    );
    
    partitions.add(progress);
    System.debug('✓ ' + partitionName + ' ready (offsets ' + (i*200000) + '-' + ((i+1)*200000-1) + ')');
}

insert partitions;

System.debug('');
System.debug('✅ All 10 partitions created!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('NEXT: Create Scheduled Flow');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('1. Setup → Flows → New Flow → Scheduled Flow');
System.debug('2. Configure:');
System.debug('   - Schedule: Every 5 minutes');
System.debug('   - Start: Now');
System.debug('');
System.debug('3. Add Action:');
System.debug('   - Search: "Check and Start Parallel Batches"');
System.debug('   - Select: ParallelBatchOrchestrator action');
System.debug('');
System.debug('4. Save and Activate!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('PERFORMANCE:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('10 parallel partitions × 2000 records/batch');
System.debug('= ~20,000 records every 5 minutes');
System.debug('= ~240,000 records/hour');
System.debug('= ~8-12 hours for 2M records! 🚀');
System.debug('');
System.debug('Monitor: SELECT Name, Status__c, CurrentOffset__c, TotalProcessed__c');
System.debug('         FROM DataCloudPartition__c ORDER BY PartitionId__c');
System.debug('════════════════════════════════════════════════════════════════════');





