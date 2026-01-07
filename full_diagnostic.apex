// ═══════════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE DIAGNOSTIC - Find out why count is stuck at 184,815
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🔍 WHY IS COUNT STUCK? FULL DIAGNOSTIC');
System.debug('═══════════════════════════════════════════════════════════════');
System.debug('');

// 1. Current opportunity count
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('📊 Current opportunities: ' + currentCount);
System.debug('📊 Target: 2,000,000');
System.debug('📊 Gap: ' + (2000000 - currentCount) + ' records missing');
System.debug('');

// 2. Check DataCloudBatchProcessor jobs
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('BATCH JOBS STATUS:');
System.debug('════════════════════════════════════════════════════════════════════');

List<AsyncApexJob> batchJobs = [
    SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors,
           CreatedDate, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 20
];

if (batchJobs.isEmpty()) {
    System.debug('❌ NO BATCH JOBS FOUND TODAY!');
    System.debug('   The DataCloudBatchProcessor is NOT running!');
} else {
    System.debug('Found ' + batchJobs.size() + ' batch jobs today');
    System.debug('');
    
    Integer running = 0, completed = 0, failed = 0, aborted = 0;
    
    for (Integer i = 0; i < Math.min(5, batchJobs.size()); i++) {
        AsyncApexJob job = batchJobs[i];
        System.debug('Job #' + (i+1) + ' - ' + job.Id);
        System.debug('  Status: ' + job.Status);
        System.debug('  Errors: ' + job.NumberOfErrors);
        System.debug('  Created: ' + job.CreatedDate.format('HH:mm:ss'));
        
        if (job.Status == 'Processing' || job.Status == 'Queued') running++;
        else if (job.Status == 'Completed') completed++;
        else if (job.Status == 'Failed') failed++;
        else if (job.Status == 'Aborted') aborted++;
        
        if (String.isNotBlank(job.ExtendedStatus)) {
            System.debug('  ⚠️ Error: ' + job.ExtendedStatus);
        }
        System.debug('');
    }
    
    System.debug('Summary: Running=' + running + ', Completed=' + completed + 
                 ', Failed=' + failed + ', Aborted=' + aborted);
}
System.debug('');

// 3. Check scheduled jobs
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('SCHEDULED JOBS:');
System.debug('════════════════════════════════════════════════════════════════════');

List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloudBatchProcessor%'
];

if (scheduledJobs.isEmpty()) {
    System.debug('⚠️ NO SCHEDULED JOBS!');
    System.debug('   Self-scheduling has stopped!');
} else {
    for (CronTrigger job : scheduledJobs) {
        System.debug('Scheduled: ' + job.CronJobDetail.Name);
        System.debug('  State: ' + job.State);
        System.debug('  Next Fire: ' + job.NextFireTime);
    }
}
System.debug('');

// 4. Check Bulk Data Load Jobs (check recent ones)
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('CHECKING DATA CLOUD:');
System.debug('════════════════════════════════════════════════════════════════════');

try {
    ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
    input.sql = 'SELECT COUNT(*) as total FROM "ExtOpportunities__dlm"';
    ConnectApi.CdpQueryOutputV2 output = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
    
    if (!output.data.isEmpty()) {
        List<Object> firstRow = (List<Object>) JSON.deserializeUntyped(JSON.serialize(output.data[0]));
        Object countObj = firstRow[0];
        System.debug('📊 Records in Data Cloud: ' + countObj);
        System.debug('📊 Records in Salesforce: ' + currentCount);
        System.debug('📊 Difference: ' + (Integer.valueOf(String.valueOf(countObj)) - currentCount));
    }
} catch (Exception e) {
    System.debug('Could not query Data Cloud: ' + e.getMessage());
}
System.debug('');

// 5. Sample recent opportunities to see if they're being updated
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('RECENT OPPORTUNITY UPDATES:');
System.debug('════════════════════════════════════════════════════════════════════');

List<Opportunity> recentOpps = [
    SELECT Id, External_ID__c, LastModifiedDate
    FROM Opportunity
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];

if (recentOpps.isEmpty()) {
    System.debug('No opportunities found!');
} else {
    System.debug('Last 5 modified opportunities:');
    for (Opportunity opp : recentOpps) {
        System.debug('  ' + opp.External_ID__c + ' - Modified: ' + opp.LastModifiedDate.format('yyyy-MM-dd HH:mm:ss'));
    }
    
    Datetime lastModified = recentOpps[0].LastModifiedDate;
    Long minutesAgo = (Datetime.now().getTime() - lastModified.getTime()) / 60000;
    System.debug('');
    System.debug('⏰ Last update was ' + minutesAgo + ' minutes ago');
    
    if (minutesAgo > 30) {
        System.debug('⚠️ WARNING: No updates in over 30 minutes!');
        System.debug('   The process might have stopped!');
    }
}
System.debug('');

// 6. Final diagnosis
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('DIAGNOSIS:');
System.debug('════════════════════════════════════════════════════════════════════');

if (batchJobs.isEmpty()) {
    System.debug('❌ PROBLEM: No batch jobs running!');
    System.debug('   → ACTION: Run restart_with_2k_batches.apex');
} else if (scheduledJobs.isEmpty()) {
    System.debug('⚠️ PROBLEM: Self-scheduling stopped!');
    System.debug('   → ACTION: Run restart_with_2k_batches.apex');
} else {
    System.debug('Jobs are running and scheduled...');
    System.debug('Check the "Last update" time above:');
    System.debug('  - If recent (<10 min): Process is working, just slow');
    System.debug('  - If old (>30 min): Jobs might be failing silently');
    System.debug('');
    System.debug('Next: Check Setup → Bulk Data Load Jobs to see actual progress');
}

System.debug('════════════════════════════════════════════════════════════════════');




