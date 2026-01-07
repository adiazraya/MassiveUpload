// START FRESH TEST - Clean slate to 2M opportunities
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING FRESH TEST');
System.debug('══════════════════════════════════════════════════════════════');

// Verify clean slate
Integer currentCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + currentCount);

if (currentCount > 0) {
    System.debug('⚠️  WARNING: Found ' + currentCount + ' existing opportunities');
    System.debug('   Consider running delete_all_test_opps.apex first');
} else {
    System.debug('✓ Clean slate confirmed - 0 opportunities');
}

// Clean up any previous scheduled jobs
List<CronTrigger> scheduledJobs = [
    SELECT Id, CronJobDetail.Name FROM CronTrigger 
    WHERE CronJobDetail.Name LIKE 'DataCloud%'
];
for (CronTrigger job : scheduledJobs) {
    System.abortJob(job.Id);
    System.debug('Aborted: ' + job.CronJobDetail.Name);
}
if (scheduledJobs.size() > 0) {
    System.debug('✓ Cleaned up ' + scheduledJobs.size() + ' old scheduled jobs');
}

System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('STARTING FRESH TEST RUN');
System.debug('══════════════════════════════════════════════════════════════');

// Start DataCloudBatchProcessor from beginning
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ BATCH STARTED: ' + batchJobId);
System.debug('');
System.debug('CONFIGURATION:');
System.debug('  Source: ExtOpportunities__dlm (Data Cloud)');
System.debug('  Target: Opportunity (Salesforce Core)');
System.debug('  Records per batch: 10,000');
System.debug('  Total records: ~2,000,000');
System.debug('  Total batches: ~200');
System.debug('  Estimated time: ~2 hours');
System.debug('  Operation: UPSERT via Bulk API');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MONITORING INSTRUCTIONS');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Check progress every 15 minutes with this simple command:');
System.debug('');
System.debug('  Integer count = [SELECT COUNT() FROM Opportunity];');
System.debug('  System.debug(\'Progress: \' + count + \' opps (\' + (count * 100 / 2000000) + \'%)\');');
System.debug('');
System.debug('EXPECTED PROGRESSION:');
System.debug('  15 min:    100,000 opps (5%)');
System.debug('  30 min:    250,000 opps (13%)');
System.debug('  45 min:    450,000 opps (23%)');
System.debug('  60 min:    650,000 opps (33%)');
System.debug('  75 min:    850,000 opps (43%)');
System.debug('  90 min:  1,050,000 opps (53%)');
System.debug('  105 min: 1,250,000 opps (63%)');
System.debug('  120 min: 1,450,000 opps (73%)');
System.debug('  135 min: 1,650,000 opps (83%)');
System.debug('  150 min: 1,850,000 opps (93%)');
System.debug('  165 min: 2,000,000 opps (100%) ✅');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('CHECK BATCH STATUS:');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('');
System.debug('  List<AsyncApexJob> jobs = [');
System.debug('      SELECT Status, CreatedDate, TotalJobItems, JobItemsProcessed,');
System.debug('             NumberOfErrors, ExtendedStatus');
System.debug('      FROM AsyncApexJob');
System.debug('      WHERE ApexClass.Name = \'DataCloudBatchProcessor\'');
System.debug('      AND CreatedDate = TODAY');
System.debug('      ORDER BY CreatedDate DESC LIMIT 3');
System.debug('  ];');
System.debug('  for (AsyncApexJob job : jobs) {');
System.debug('      System.debug(job.Status + \' - \' + job.JobItemsProcessed + \'/\' + job.TotalJobItems);');
System.debug('  }');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('✅ TEST RUNNING - MONITOR FOR ~2-3 HOURS');
System.debug('══════════════════════════════════════════════════════════════');





