// ═══════════════════════════════════════════════════════════════════════════════
// START QUEUEABLE VERSION (Simpler & More Reliable!)
// No Platform Events - Direct Queueable chain with scheduled delay
// ═══════════════════════════════════════════════════════════════════════════════

System.debug('═══════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING QUEUEABLE VERSION (PRODUCTION-READY)');
System.debug('═══════════════════════════════════════════════════════════════');

Integer currentCount = [SELECT COUNT() FROM Opportunity];

System.debug('');
System.debug('Current: ' + currentCount);
System.debug('Target: 2,000,000');
System.debug('Remaining: ~' + (2000000 - currentCount));
System.debug('');
System.debug('ARCHITECTURE: Queueable → Scheduled Job → Queueable → ...');
System.debug('  - Much simpler than Platform Events');
System.debug('  - Self-cleaning scheduled jobs');
System.debug('  - 2-minute delay between batches');
System.debug('  - Batch size: 2,000 records');
System.debug('');

// Start the Queueable chain
Id jobId = System.enqueueJob(new DataCloudQueueableProcessor());

System.debug('✅ STARTED! Job ID: ' + jobId);
System.debug('');
System.debug('Monitor with: is_it_running.apex');
System.debug('Check progress: count_comparison.apex');
System.debug('');
System.debug('Expected completion: 24-36 hours');




