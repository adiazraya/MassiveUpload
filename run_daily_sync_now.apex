// Start daily sync manually (for testing or immediate run)
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING DAILY SYNC NOW');
System.debug('════════════════════════════════════════════════════════════════');

DailySyncProcessor batch = new DailySyncProcessor();
Id batchId = Database.executeBatch(batch, 1);

System.debug('✓ Daily sync started (Job ID: ' + batchId + ')');
System.debug('');
System.debug('This will:');
System.debug('  • Query ALL records from Data Cloud (2M)');
System.debug('  • UPSERT to Salesforce Opportunities');
System.debug('  • Process 2,000 records per batch');
System.debug('  • Self-schedule continuously until complete');
System.debug('');
System.debug('Expected: 2-4 hours');
System.debug('');
System.debug('Monitor: Setup → Apex Jobs');
System.debug('Stop: sf apex run --file emergency_stop.apex');
System.debug('════════════════════════════════════════════════════════════════');




