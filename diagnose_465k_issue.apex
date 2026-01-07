// DIAGNOSE WHY ONLY 465K RECORDS WERE CREATED
System.debug('══════════════════════════════════════════════════════════════');
System.debug('DIAGNOSING: Why only 465K out of 2M?');
System.debug('══════════════════════════════════════════════════════════════');

// 1. Check Data Cloud source
System.debug('');
System.debug('1. DATA CLOUD SOURCE CHECK:');
try {
    ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
    input.sql = 'SELECT COUNT(*) as total FROM "ExtOpportunities__dlm"';
    ConnectApi.CdpQueryOutputV2 result = ConnectApi.CdpQuery.queryAnsiSqlV2(input);
    System.debug('   Data Cloud total records: ' + result.rowCount);
} catch (Exception e) {
    System.debug('   ⚠️  Error querying Data Cloud: ' + e.getMessage());
}

// 2. Check Salesforce opportunities
Integer sfCount = [SELECT COUNT() FROM Opportunity];
System.debug('');
System.debug('2. SALESFORCE OPPORTUNITIES:');
System.debug('   Total: ' + sfCount);

// 3. Check if External_ID__c has values
List<Opportunity> sampleOpps = [
    SELECT Id, Name, External_ID__c, CreatedDate
    FROM Opportunity
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('');
System.debug('3. SAMPLE RECENT OPPORTUNITIES:');
for (Opportunity opp : sampleOpps) {
    System.debug('   ' + opp.Name + ' | ExtID: ' + opp.External_ID__c);
}

// 4. Check batch execution details
List<AsyncApexJob> recentJobs = [
    SELECT Id, Status, CreatedDate, CompletedDate, 
           TotalJobItems, JobItemsProcessed, NumberOfErrors,
           ExtendedStatus
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('');
System.debug('4. RECENT BATCH JOBS (Last 10):');
Integer totalItems = 0;
Integer totalProcessed = 0;
for (AsyncApexJob job : recentJobs) {
    System.debug('   ' + job.Status + ' | Items: ' + job.JobItemsProcessed + '/' + job.TotalJobItems + 
                 ' | Errors: ' + job.NumberOfErrors);
    if (job.ExtendedStatus != null) {
        System.debug('      → ' + job.ExtendedStatus);
    }
    totalItems += job.TotalJobItems;
    totalProcessed += job.JobItemsProcessed;
}
System.debug('   Total job items: ' + totalProcessed + '/' + totalItems);

// 5. Check debug logs for Bulk API responses
System.debug('');
System.debug('5. BULK API HYPOTHESIS:');
System.debug('   Batches completed: 200');
System.debug('   Records queried: 200 * 10,000 = 2,000,000');
System.debug('   Records created: 465,400');
System.debug('   Missing: ' + (2000000 - sfCount));
System.debug('   Success rate: ' + ((sfCount * 100) / 2000000) + '%');
System.debug('');
System.debug('   POSSIBLE CAUSES:');
System.debug('   ❌ Bulk API jobs may have failed silently');
System.debug('   ❌ Data Cloud may have duplicate records');
System.debug('   ❌ Upsert may be matching existing External_ID__c');
System.debug('   ❌ Field mapping errors in Bulk API CSV');

// 6. Test one batch manually
System.debug('');
System.debug('6. TESTING ONE BATCH MANUALLY:');
System.debug('   Let\'s query one batch from Data Cloud and check:');
try {
    ConnectApi.CdpQueryInput testInput = new ConnectApi.CdpQueryInput();
    testInput.sql = 'SELECT "External_ID__c", "Name__c", "Amount__c", "StageName__c", "CloseDate__c", "Account__c" ' +
                    'FROM "ExtOpportunities__dlm" ' +
                    'LIMIT 5 OFFSET 0';
    ConnectApi.CdpQueryOutputV2 testResult = ConnectApi.CdpQuery.queryAnsiSqlV2(testInput);
    
    System.debug('   Rows returned: ' + testResult.rowCount);
    System.debug('   Data structure: ' + JSON.serializePretty(testResult));
    
} catch (Exception e) {
    System.debug('   ⚠️  Error: ' + e.getMessage());
    System.debug('   ' + e.getStackTraceString());
}

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('NEXT STEPS:');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('1. Check Bulk API Jobs in Setup → Bulk Data Load Jobs');
System.debug('2. Look for failed/partial uploads');
System.debug('3. Verify External_ID__c field exists on Opportunity');
System.debug('4. Check if Data Cloud has 2M unique records');
System.debug('══════════════════════════════════════════════════════════════');





