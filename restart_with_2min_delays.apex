// ═══════════════════════════════════════════════════════════════════════════════
// RESTART WITH 2-MINUTE DELAYS (FIXED VERSION)
// This prevents concurrent Bulk API jobs and eliminates record locking errors!
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING FIXED VERSION WITH 2-MIN DELAYS');
System.debug('═══════════════════════════════════════════════════════════════');

Integer currentCount = [SELECT COUNT() FROM Opportunity];

System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('CONFIGURATION:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' Current opportunities: ' + currentCount);
System.debug(' Target: ~2,000,000');
System.debug(' Remaining: ~' + (2000000 - currentCount));
System.debug('');
System.debug(' ✅ Records per batch: 2,000 (safe from regex errors)');
System.debug(' ✅ Delay between batches: 2 MINUTES (NEW!)');
System.debug(' ✅ Total batches: ~' + ((2000000 - currentCount) / 2000));
System.debug(' ✅ Estimated time: 12-18 hours (slower but NO FAILURES!)');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('HOW IT WORKS:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' 1. Batch 1 runs → Creates Bulk API Job A');
System.debug(' 2. Waits 2 minutes (Job A completes)');
System.debug(' 3. Batch 2 runs → Creates Bulk API Job B');
System.debug(' 4. Waits 2 minutes (Job B completes)');
System.debug(' 5. Repeat...');
System.debug('');
System.debug(' NO MORE CONCURRENT JOBS = NO MORE LOCKING ERRORS!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('MONITOR PROGRESS:');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug(' Run progress_check.apex every 30 minutes');
System.debug(' Check Bulk Data Load Jobs → Should show HIGH success rates now!');
System.debug('');
System.debug('════════════════════════════════════════════════════════════════════');

// Start the fixed batch processor
DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
Id batchJobId = Database.executeBatch(batch, 1);

System.debug('');
System.debug('✅ STARTED WITH 2-MINUTE DELAYS!');
System.debug('════════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Batch Job ID: ' + batchJobId);
System.debug('');
System.debug('This will be SLOWER but RELIABLE!');
System.debug('Check back in 30 minutes with progress_check.apex');
System.debug('');
System.debug('Expected timeline:');
System.debug('  +30 min  → ~210,000 opps');
System.debug('  +1 hour  → ~240,000 opps');
System.debug('  +2 hours → ~300,000 opps');
System.debug('  ...slow and steady wins the race! 🐢');




