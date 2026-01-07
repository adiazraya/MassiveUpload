// RESTART WITH 10K RECORDS PER BATCH (10X FASTER!)
System.debug('══════════════════════════════════════════════════════════════');
System.debug('RESTARTING WITH 10,000 RECORDS PER BATCH');
System.debug('══════════════════════════════════════════════════════════════');

// Check current state
Integer beforeCount = [SELECT COUNT() FROM Opportunity];
System.debug('Current Opportunities: ' + beforeCount);
System.debug('Target: ~2,111,000');
System.debug('Remaining: ~' + (2111000 - beforeCount));

// Start fresh from offset 0 with NEW 10K batch size
// Upsert will update existing records and create new ones
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✓ BATCH STARTED: ' + batchJobId);
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('NEW CONFIGURATION (10X FASTER!)');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('Records per batch: 10,000 (was 1,000)');
System.debug('Total batches needed: ~200 (was 2,000)');
System.debug('Estimated time: 1-2 hours (was 10+ hours)');
System.debug('Operation: UPSERT (updates existing + creates new)');
System.debug('');
System.debug('Progress logging: Every 100,000 records');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('MONITORING');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('Check progress every 10-15 minutes:');
System.debug('  Integer count = [SELECT COUNT() FROM Opportunity];');
System.debug('  System.debug(\'Opportunities: \' + count);');
System.debug('');
System.debug('══════════════════════════════════════════════════════════════');
System.debug('PROCESS STARTED - MUCH FASTER NOW!');
System.debug('══════════════════════════════════════════════════════════════');






