// 5-Partition Staggered Startup with 1-hour delays
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING 5-PARTITION STAGGERED APPROACH');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Strategy:');
System.debug('  - 5 partitions (400k records each)');
System.debug('  - 10-second delay between Bulk API calls');
System.debug('  - 1-hour stagger between partition starts');
System.debug('  - Expected: 100% success rate, ~5 hours total');
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

// Schedule partitions 1-4 with 1-hour delays each
for (Integer i = 1; i < 5; i++) {
    Datetime scheduleTime = now.addHours(i);
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
                ': ' + rangeStart + ' to ' + rangeEnd);
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('✅ 5 PARTITIONS CONFIGURED');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Timeline:');
System.debug('  Now      : Partition 0 starts');
System.debug('  +1 hour  : Partition 1 starts');
System.debug('  +2 hours : Partition 2 starts');
System.debug('  +3 hours : Partition 3 starts');
System.debug('  +4 hours : Partition 4 starts');
System.debug('  ~5 hours : All complete!');
System.debug('');
System.debug('Monitor: sf apex run --file check_staggered_progress.apex');
System.debug('════════════════════════════════════════════════════════════════');

