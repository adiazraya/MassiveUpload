// Test8 - 5-Partition Staggered Startup with 1.5-hour delays
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING TEST8 - IMPROVED APPROACH');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Strategy:');
System.debug('  - 5 partitions (400k records each)');
System.debug('  - 20-30 second delay between batches (Test7: 10-20s)');
System.debug('  - 1.5-hour stagger between partitions (Test7: 1 hour)');
System.debug('  - Exponential backoff retry: 2s, 5s, 10s (Test7: immediate)');
System.debug('  - Expected: 91-92% success rate (Test7: 90.16%)');
System.debug('');

// Clean up old progress and scheduled jobs
delete [SELECT Id FROM DataCloudPartition__c];
List<CronTrigger> oldJobs = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'Partition%'
];
for (CronTrigger ct : oldJobs) {
    System.abortJob(ct.Id);
}
System.debug('✓ Cleaned up old data');
System.debug('');

// Calculate ranges for 5 partitions
String minId = 'externalOpp0000001';
String maxId = 'externalOpp2000000';
List<String> boundaryPoints = new List<String>{
    'externalOpp0000001',
    'externalOpp0400001',
    'externalOpp0800001',
    'externalOpp1200001',
    'externalOpp1600001',
    'externalOpp2000000'
};

// Create progress records
List<DataCloudPartition__c> progressRecords = new List<DataCloudPartition__c>();
for (Integer i = 0; i < 5; i++) {
    progressRecords.add(new DataCloudPartition__c(
        Name = 'StaggeredPartition_' + i,
        PartitionId__c = i,
        CurrentOffset__c = 0,
        TotalProcessed__c = 0,
        TotalBulkAPICalls__c = 0,
        Status__c = 'Running'
    ));
}
insert progressRecords;
System.debug('✓ Created 5 progress records');
System.debug('');

// Get current time
Datetime now = System.now();

// Start partition 0 immediately
String range0Start = boundaryPoints[0];
String range0End = boundaryPoints[1];
DynamicPartitionProcessorV2 batch0 = new DynamicPartitionProcessorV2(
    0, 'StaggeredPartition_0', range0Start, range0End
);
Database.executeBatch(batch0, 1);
System.debug('✅ Partition 0 STARTED NOW: ' + range0Start + ' to ' + range0End);

// Schedule partitions 1-4 with 1.5-hour delays each (Test8 improvement)
Decimal hourDelay = 1.5;
for (Integer i = 1; i < 5; i++) {
    // Calculate schedule time: now + (i * 1.5 hours)
    Integer minutesToAdd = (Integer)(i * hourDelay * 60);
    Datetime scheduleTime = now.addMinutes(minutesToAdd);
    
    String cronExp = 
        scheduleTime.second() + ' ' +
        scheduleTime.minute() + ' ' +
        scheduleTime.hour() + ' ' +
        scheduleTime.day() + ' ' +
        scheduleTime.month() + ' ' +
        '? ' +
        scheduleTime.year();
    
    String rangeStart = boundaryPoints[i];
    String rangeEnd = (i < 4) ? boundaryPoints[i + 1] : maxId;
    
    PartitionScheduler scheduler = new PartitionScheduler(
        i, 'StaggeredPartition_' + i, rangeStart, rangeEnd
    );
    
    String jobName = 'Partition_' + i + '_Staggered';
    System.schedule(jobName, cronExp, scheduler);
    
    System.debug('✅ Partition ' + i + ' scheduled for ' + scheduleTime.format('HH:mm:ss') + 
                ' (+' + minutesToAdd + 'm): ' + rangeStart + ' to ' + rangeEnd);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ TEST8 CONFIGURED - 5 PARTITIONS');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Timeline (1.5-hour stagger):');
System.debug('  Now        : Partition 0 starts');
System.debug('  +1.5 hours : Partition 1 starts');
System.debug('  +3.0 hours : Partition 2 starts');
System.debug('  +4.5 hours : Partition 3 starts');
System.debug('  +6.0 hours : Partition 4 starts');
System.debug('  ~7.5 hours : All complete!');
System.debug('');
System.debug('Improvements over Test7:');
System.debug('  • Batch delay: 20-30s (was 10-20s)');
System.debug('  • Partition stagger: 1.5h (was 1h)');
System.debug('  • Retry: Exponential backoff 2s/5s/10s (was immediate)');
System.debug('  • Max retries: 3 (was 2)');
System.debug('');
System.debug('Monitor: sf apex run --file check_test8_progress.apex');
System.debug('════════════════════════════════════════════════════════════════');

