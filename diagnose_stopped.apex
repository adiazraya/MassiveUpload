// DIAGNOSTIC: Why did it stop at 1.3M?
System.debug('══════════════════════════════════════════════════════════════');
System.debug('INVESTIGATING INCOMPLETE PROCESS');
System.debug('══════════════════════════════════════════════════════════════');

// 1. Check Data Cloud total
System.debug('\n1. DATA CLOUD COUNT:');
ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
input.sql = 'SELECT COUNT(*) as total_count FROM ExtOpportunities__dlm';
ConnectApi.CdpQueryOutputV2 result = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
if (result.data != null && result.data.size() > 0) {
    ConnectApi.CdpQueryV2Row row = result.data[0];
    String jsonStr = JSON.serialize(row);
    List<Object> rowList = (List<Object>) JSON.deserializeUntyped(jsonStr);
    System.debug('   Data Cloud total: ' + rowList[0]);
}

// 2. Check Salesforce total
System.debug('\n2. SALESFORCE COUNT:');
Integer oppCount = [SELECT COUNT() FROM Opportunity];
System.debug('   Salesforce total: ' + oppCount);
System.debug('   Expected: ~2,111,000');
System.debug('   Missing: ~' + (2111000 - oppCount));

// 3. Check batch job status - LAST 100 JOBS
System.debug('\n3. RECENT BATCH JOBS (Last 100):');
List<AsyncApexJob> jobs = [
    SELECT Id, Status, CreatedDate, CompletedDate, JobItemsProcessed, 
           TotalJobItems, NumberOfErrors, ExtendedStatus
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = LAST_N_DAYS:1
    ORDER BY CreatedDate DESC
    LIMIT 100
];

Integer completed = 0;
Integer failed = 0;
Integer aborted = 0;
Integer queued = 0;
Integer processing = 0;
AsyncApexJob lastJob = null;

for (AsyncApexJob job : jobs) {
    if (job.Status == 'Completed') completed++;
    else if (job.Status == 'Failed') failed++;
    else if (job.Status == 'Aborted') aborted++;
    else if (job.Status == 'Queued') queued++;
    else if (job.Status == 'Processing') processing++;
    
    if (lastJob == null) lastJob = job;
}

System.debug('   Total jobs checked: ' + jobs.size());
System.debug('   Completed: ' + completed);
System.debug('   Failed: ' + failed);
System.debug('   Aborted: ' + aborted);
System.debug('   Processing: ' + processing);
System.debug('   Queued: ' + queued);

if (lastJob != null) {
    System.debug('\n   LAST JOB:');
    System.debug('   - ID: ' + lastJob.Id);
    System.debug('   - Status: ' + lastJob.Status);
    System.debug('   - Created: ' + lastJob.CreatedDate);
    System.debug('   - Completed: ' + lastJob.CompletedDate);
    System.debug('   - Errors: ' + lastJob.NumberOfErrors);
    if (String.isNotBlank(lastJob.ExtendedStatus)) {
        System.debug('   - Extended Status: ' + lastJob.ExtendedStatus);
    }
}

// 4. Check scheduled jobs
System.debug('\n4. SCHEDULED JOBS:');
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name, State, NextFireTime
    FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];
System.debug('   Scheduled jobs: ' + scheduledJobs.size());

// 5. Check if there are more records to process
System.debug('\n5. CHECK NEXT BATCH OF DATA:');
Integer testOffset = completed * 1000;
System.debug('   Testing offset: ' + testOffset);

ConnectApi.CdpQueryInput testInput = new ConnectApi.CdpQueryInput();
testInput.sql = 'SELECT externalid__c FROM ExtOpportunities__dlm ORDER BY externalid__c LIMIT 1 OFFSET ' + testOffset;
ConnectApi.CdpQueryOutputV2 testResult = ConnectApi.CdpQuery.queryAnsiSqlV2(testInput);

if (testResult != null && testResult.data != null && !testResult.data.isEmpty()) {
    System.debug('   ✓ More records exist at offset ' + testOffset);
    System.debug('   → Process stopped prematurely!');
} else {
    System.debug('   ✗ No records at offset ' + testOffset);
    System.debug('   → This might be the end of data');
}

// 6. Calculate expected records processed
System.debug('\n6. ANALYSIS:');
Integer recordsProcessed = completed * 1000;
System.debug('   Completed batches: ' + completed);
System.debug('   Records processed (estimated): ' + recordsProcessed);
System.debug('   Current opportunities: ' + oppCount);

System.debug('\n══════════════════════════════════════════════════════════════');
System.debug('DIAGNOSTIC COMPLETE');
System.debug('══════════════════════════════════════════════════════════════');






