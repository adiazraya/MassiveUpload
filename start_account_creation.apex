// Start creating 2 million Person Accounts
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🚀 STARTING 2 MILLION ACCOUNT CREATION');
System.debug('════════════════════════════════════════════════════════════════');
System.debug('');
System.debug('Target: 2,000,000 Person Accounts');
System.debug('Names: acc_test_massive_0000001 to acc_test_massive_2000000');
System.debug('Batch size: 10,000 accounts per Bulk API call');
System.debug('Expected batches: 200');
System.debug('Expected duration: 2-3 hours');
System.debug('');

Database.executeBatch(new MassiveAccountCreator(), 1);

System.debug('✅ Account creation started!');
System.debug('');
System.debug('Monitor progress:');
System.debug('  Setup → Apex Jobs (look for MassiveAccountCreator)');
System.debug('');
System.debug('After completion, run: download_account_ids.apex');
System.debug('════════════════════════════════════════════════════════════════');




