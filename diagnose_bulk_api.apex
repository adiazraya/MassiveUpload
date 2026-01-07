// Check Bulk API job results
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 BULK API JOB ANALYSIS');
System.debug('════════════════════════════════════════════════════════════════');

// Get recent Bulk Data Load Jobs
List<AsyncApexJob> bulkJobs = [
    SELECT Id, JobType, Status, JobItemsProcessed, TotalJobItems, 
           NumberOfErrors, CompletedDate, ExtendedStatus
    FROM AsyncApexJob 
    WHERE JobType = 'BatchApexWorker'
    AND ApexClass.Name = 'DynamicPartitionProcessorV2'
    ORDER BY CompletedDate DESC
    LIMIT 5
];

System.debug('');
System.debug('Recent V2 Batch Jobs:');
for (AsyncApexJob job : bulkJobs) {
    System.debug('  Job: ' + job.Id);
    System.debug('    Status: ' + job.Status);
    System.debug('    Items Processed: ' + job.JobItemsProcessed + ' / ' + job.TotalJobItems);
    System.debug('    Errors: ' + job.NumberOfErrors);
    if (job.ExtendedStatus != null) {
        System.debug('    Extended Status: ' + job.ExtendedStatus);
    }
}

// Try to get actual Bulk Data Load Jobs (not AsyncApexJob)
// These are the HTTP callout jobs to Bulk API
List<BulkApiResultStore> bulkDataJobs = [
    SELECT Id, CreatedDate
    FROM BulkApiResultStore
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('');
System.debug('BulkApiResultStore records found: ' + bulkDataJobs.size());

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('DIAGNOSIS:');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('V2 "processed": 1,997,999 records');
System.debug('Actually updated: 372,862 records');
System.debug('Missing: 1,625,137 records');
System.debug('');
System.debug('This suggests Bulk API jobs are:');
System.debug('  1. Completing successfully (Status = Completed)');
System.debug('  2. BUT not actually upserting the records');
System.debug('  3. Possible causes:');
System.debug('     - Invalid AccountId values');
System.debug('     - Validation rules blocking updates');
System.debug('     - Field-level security');
System.debug('     - External_ID__c not configured for UPSERT');
System.debug('     - Required fields missing');
System.debug('');
System.debug('NEXT STEP: Check Bulk Data Load Jobs in Setup');
System.debug('Setup → Bulk Data Load Jobs → View recent jobs');
System.debug('Look for "Records Failed" or "Records Processed"');
System.debug('════════════════════════════════════════════════════════════════');




