// Test8 Final Results Analysis
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🎉 TEST8 FINAL RESULTS - BREAKTHROUGH!');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Partition completion
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c,
           CreatedDate, LastModifiedDate
    FROM DataCloudPartition__c
    WHERE Name LIKE 'StaggeredPartition_%'
    ORDER BY Name
];

Integer totalProcessed = 0;
Integer totalCalls = 0;
Datetime startTime = null;
Datetime endTime = null;

System.debug('');
System.debug('Partition Results:');
for (DataCloudPartition__c p : partitions) {
    Integer processed = p.TotalProcessed__c != null ? Integer.valueOf(p.TotalProcessed__c) : 0;
    Integer calls = p.TotalBulkAPICalls__c != null ? Integer.valueOf(p.TotalBulkAPICalls__c) : 0;
    totalProcessed += processed;
    totalCalls += calls;
    
    if (startTime == null || p.CreatedDate < startTime) {
        startTime = p.CreatedDate;
    }
    if (endTime == null || p.LastModifiedDate > endTime) {
        endTime = p.LastModifiedDate;
    }
    
    System.debug('  ' + p.Name + ': ' + String.valueOf(processed).leftPad(9) + ' records (' + p.Status__c + ')');
}

System.debug('');
System.debug('──────────────────────────────────────────────────────────────');
System.debug('Total Processed:     ' + String.valueOf(totalProcessed).leftPad(9));
System.debug('Total API Calls:     ' + String.valueOf(totalCalls).leftPad(9));

// 2. Opportunities created
Integer test8Count = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test8'];
System.debug('Opportunities Created: ' + String.valueOf(test8Count).leftPad(7));
System.debug('──────────────────────────────────────────────────────────────');

// 3. Success rate
Decimal successRate = (Decimal.valueOf(test8Count) / Decimal.valueOf(totalProcessed)) * 100;
System.debug('');
System.debug('📊 SUCCESS RATE: ' + successRate.setScale(2) + '%');
System.debug('');

// 4. Compare to previous tests
System.debug('COMPARISON TO PREVIOUS TESTS:');
System.debug('  Test4: 89.00% (~1,780,000 opportunities)');
System.debug('  Test7: 90.16% (1,803,153 opportunities)');
System.debug('  Test8: ' + successRate.setScale(2) + '% (' + test8Count + ' opportunities)');
System.debug('');

// Calculate improvements
Integer test7Count = 1803153;
Decimal test7Rate = 90.16;
Integer improvedOpps = test8Count - test7Count;
Decimal improvedRate = successRate - test7Rate;

System.debug('IMPROVEMENT OVER TEST7:');
System.debug('  Additional Opportunities: +' + String.valueOf(improvedOpps).leftPad(9));
System.debug('  Success Rate Improvement: +' + improvedRate.setScale(2) + '%');
System.debug('');

if (successRate >= 99) {
    System.debug('✅ EXCEPTIONAL! Nearly perfect success rate!');
} else if (successRate >= 95) {
    System.debug('✅ EXCELLENT! Outstanding improvement!');
} else if (successRate >= 91) {
    System.debug('✅ GREAT! Exceeded expectations!');
}

// 5. Timing
if (startTime != null && endTime != null) {
    Long milliseconds = endTime.getTime() - startTime.getTime();
    Long minutes = milliseconds / 60000;
    Long hours = minutes / 60;
    Long remainingMinutes = minutes - (hours * 60);
    
    System.debug('');
    System.debug('──────────────────────────────────────────────────────────────');
    System.debug('TIMING:');
    System.debug('  Start:    ' + startTime.format('yyyy-MM-dd HH:mm:ss'));
    System.debug('  End:      ' + endTime.format('yyyy-MM-dd HH:mm:ss'));
    System.debug('  Duration: ' + hours + 'h ' + remainingMinutes + 'm');
    
    Decimal recordsPerMin = Decimal.valueOf(test8Count) / Decimal.valueOf(minutes);
    System.debug('  Throughput: ~' + recordsPerMin.setScale(0) + ' records/minute');
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🎉 TEST8 SUCCESS! BEST RESULTS YET!');
System.debug('════════════════════════════════════════════════════════════════');

