// Manual batch kickoff - continues from where it left off
System.debug('====== MANUAL BATCH KICKOFF ======');

// Check current progress
Integer currentOppCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + currentOppCount);

// Calculate next offset (round down to nearest 1000)
Integer nextOffset = (currentOppCount / 1000) * 1000;
System.debug('Next Offset: ' + nextOffset);

// Verify records exist at this offset
ConnectApi.CdpQueryInput testQuery = new ConnectApi.CdpQueryInput();
testQuery.sql = 'SELECT externalid__c FROM ExtOpportunities__dlm ORDER BY externalid__c LIMIT 1 OFFSET ' + nextOffset;
ConnectApi.CdpQueryOutputV2 testResult = ConnectApi.CdpQuery.queryAnsiSqlV2(testQuery);

if (testResult != null && testResult.data != null && !testResult.data.isEmpty()) {
    System.debug('✓ Records found at offset ' + nextOffset);
    
    // Kick off batch
    DataCloudBatchProcessor batch = new DataCloudBatchProcessor(nextOffset, 0, 0);
    Id jobId = Database.executeBatch(batch, 1);
    
    System.debug('✓ Batch started: ' + jobId);
    System.debug('This will process 1000 records from offset ' + nextOffset);
    System.debug('');
    System.debug('To continue processing:');
    System.debug('Run this script again after this batch completes');
    System.debug('OR use: DataCloudScheduler.scheduleProcessing()');
    
} else {
    System.debug('✗ No records found at offset ' + nextOffset);
    System.debug('All records may already be processed!');
}

System.debug('');
System.debug('====== KICKOFF COMPLETE ======');








