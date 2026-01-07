// Download Account IDs after creation
System.debug('════════════════════════════════════════════════════════════════');
System.debug('📥 EXPORTING ACCOUNT IDS');
System.debug('════════════════════════════════════════════════════════════════');

// First check how many accounts were created
Integer accountCount = [
    SELECT COUNT() 
    FROM Account 
    WHERE FirstName LIKE 'acc_test_massive_%'
];

System.debug('');
System.debug('Accounts found: ' + accountCount);

if (accountCount == 0) {
    System.debug('');
    System.debug('⚠️  No accounts found!');
    System.debug('Run start_account_creation.apex first');
} else if (accountCount < 2000000) {
    System.debug('⚠️  Only ' + accountCount + ' accounts created so far');
    System.debug('Wait for account creation to complete');
    System.debug('Target: 2,000,000 accounts');
} else {
    System.debug('✅ All accounts created!');
    System.debug('');
    System.debug('Starting export...');
    
    // Start export batch
    Database.executeBatch(new AccountIDExporter(), 200);
    
    System.debug('');
    System.debug('Export started in background');
    System.debug('Check debug logs for CSV output');
}

System.debug('════════════════════════════════════════════════════════════════');




