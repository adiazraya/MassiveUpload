// Final Test7 Results Analysis
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🎉 TEST7 FINAL RESULTS');
System.debug('════════════════════════════════════════════════════════════════');

// 1. Check partition progress
List<DataCloudPartition__c> partitions = [
    SELECT Name, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
    FROM DataCloudPartition__c
    WHERE Name LIKE 'StaggeredPartition_%'
    ORDER BY Name
];

Integer totalProcessed = 0;
Integer totalCalls = 0;
System.debug('');
System.debug('Partition Status:');
for (DataCloudPartition__c p : partitions) {
    Integer processed = p.TotalProcessed__c != null ? Integer.valueOf(p.TotalProcessed__c) : 0;
    Integer calls = p.TotalBulkAPICalls__c != null ? Integer.valueOf(p.TotalBulkAPICalls__c) : 0;
    totalProcessed += processed;
    totalCalls += calls;
    System.debug('  ' + p.Name + ': ' + String.valueOf(processed).leftPad(9) + ' records, ' + 
                String.valueOf(calls).leftPad(5) + ' calls (' + p.Status__c + ')');
}

System.debug('');
System.debug('──────────────────────────────────────────────────────────────');
System.debug('Total Records Processed: ' + String.valueOf(totalProcessed).leftPad(9));
System.debug('Total Bulk API Calls:    ' + String.valueOf(totalCalls).leftPad(9));

// 2. Check opportunities created
Integer test7Count = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test7'];
System.debug('Opportunities Created:   ' + String.valueOf(test7Count).leftPad(9));
System.debug('──────────────────────────────────────────────────────────────');

// 3. Calculate success rate
if (totalProcessed > 0) {
    Decimal successRate = (Decimal.valueOf(test7Count) / Decimal.valueOf(totalProcessed)) * 100;
    System.debug('');
    System.debug('📊 SUCCESS RATE: ' + successRate.setScale(2) + '%');
    System.debug('');
    
    // Compare to Test4
    Decimal test4Rate = 89.0;
    Decimal improvement = successRate - test4Rate;
    
    System.debug('Comparison to Test4:');
    System.debug('  Test4: 89.00%');
    System.debug('  Test7: ' + successRate.setScale(2) + '%');
    System.debug('  Improvement: ' + (improvement >= 0 ? '+' : '') + improvement.setScale(2) + '%');
    System.debug('');
    
    if (successRate >= 90) {
        System.debug('✅ EXCELLENT! Retry logic worked!');
    } else if (successRate >= 85) {
        System.debug('✅ GOOD! Similar to Test4');
    } else {
        System.debug('⚠️  Lower than expected');
    }
    
    // Extra opportunities vs Test4
    Integer test4Expected = (Integer)(totalProcessed * 0.89);
    Integer extraOpps = test7Count - test4Expected;
    System.debug('');
    System.debug('Extra Opportunities vs Test4: ' + (extraOpps >= 0 ? '+' : '') + String.valueOf(extraOpps).leftPad(9));
}

// 4. Check if still running
List<AsyncApexJob> runningJobs = [
    SELECT Id, Status
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DynamicPartitionProcessorV2'
    AND Status IN ('Processing', 'Queued', 'Preparing')
];

System.debug('');
System.debug('──────────────────────────────────────────────────────────────');
if (runningJobs.size() > 0) {
    System.debug('⏳ Status: Still processing (' + runningJobs.size() + ' jobs active)');
} else {
    System.debug('✅ Status: Processing COMPLETE!');
}

System.debug('════════════════════════════════════════════════════════════════');

