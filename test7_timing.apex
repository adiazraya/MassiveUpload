// Test7 Timing Analysis
System.debug('════════════════════════════════════════════════════════════════');
System.debug('⏱️  TEST7 TIMING ANALYSIS');
System.debug('════════════════════════════════════════════════════════════════');

// Get partition records with timestamps
List<DataCloudPartition__c> partitions = [
    SELECT Name, CreatedDate, LastModifiedDate, Status__c,
           TotalProcessed__c, TotalBulkAPICalls__c
    FROM DataCloudPartition__c
    WHERE Name LIKE 'StaggeredPartition_%'
    ORDER BY Name
];

Datetime startTime = null;
Datetime endTime = null;

System.debug('');
System.debug('Partition Timestamps:');
for (DataCloudPartition__c p : partitions) {
    System.debug('  ' + p.Name + ':');
    System.debug('    Created:  ' + p.CreatedDate.format('HH:mm:ss'));
    System.debug('    Modified: ' + p.LastModifiedDate.format('HH:mm:ss'));
    System.debug('    Status: ' + p.Status__c);
    
    if (startTime == null || p.CreatedDate < startTime) {
        startTime = p.CreatedDate;
    }
    if (endTime == null || p.LastModifiedDate > endTime) {
        endTime = p.LastModifiedDate;
    }
}

System.debug('');
System.debug('──────────────────────────────────────────────────────────────');
System.debug('Overall Timing:');
System.debug('  Start Time: ' + startTime.format('yyyy-MM-dd HH:mm:ss'));
System.debug('  End Time:   ' + endTime.format('yyyy-MM-dd HH:mm:ss'));

Long milliseconds = endTime.getTime() - startTime.getTime();
Long seconds = milliseconds / 1000;
Long minutes = seconds / 60;
Long hours = minutes / 60;
Long remainingMinutes = minutes - (hours * 60);

System.debug('');
System.debug('📊 TOTAL DURATION: ' + hours + 'h ' + remainingMinutes + 'm');
System.debug('   (' + minutes + ' minutes total)');
System.debug('──────────────────────────────────────────────────────────────');

// Calculate throughput
Integer totalRecords = 1803153;
Decimal recordsPerMinute = Decimal.valueOf(totalRecords) / Decimal.valueOf(minutes);
Decimal recordsPerHour = recordsPerMinute * 60;

System.debug('');
System.debug('Processing Speed:');
System.debug('  Records Processed: 1,999,999');
System.debug('  Opportunities Created: 1,803,153');
System.debug('  Throughput: ~' + recordsPerMinute.setScale(0) + ' records/minute');
System.debug('  Throughput: ~' + recordsPerHour.setScale(0) + ' records/hour');

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');

