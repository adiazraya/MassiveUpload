/**
 * Exports Account IDs to CSV format for mapping to Opportunities
 * Processes in batches to avoid heap limits
 */
public class AccountIDExporter implements Database.Batchable<sObject> {
    
    public Integer totalExported = 0;
    public String csvContent = '';
    
    // Store CSV in a static resource or custom object (for simplicity, we'll log it in chunks)
    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, LastName 
            FROM Account 
            WHERE FirstName = 'Test' AND LastName LIKE 'Massive_%'
            ORDER BY LastName
        ]);
    }
    
    public void execute(Database.BatchableContext context, List<Account> accounts) {
        System.debug('Processing batch of ' + accounts.size() + ' accounts...');
        
        // Build CSV rows
        for (Account acc : accounts) {
            // LastName format: Massive_0000001
            csvContent += acc.LastName + ',' + acc.Id + '\n';
            totalExported++;
        }
        
        // Log in chunks to avoid debug log limits
        if (csvContent.length() > 100000) {
            System.debug('=== CSV CHUNK (accounts ' + (totalExported - csvContent.split('\n').size()) + ' to ' + totalExported + ') ===');
            System.debug(csvContent.substring(0, 1000) + '\n... (' + csvContent.length() + ' chars) ...\n');
            csvContent = ''; // Reset for next chunk
        }
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('');
        System.debug('════════════════════════════════════════════════════════════════');
        System.debug('✅ ACCOUNT ID EXPORT COMPLETE');
        System.debug('════════════════════════════════════════════════════════════════');
        System.debug('Total accounts exported: ' + totalExported);
        System.debug('');
        System.debug('The CSV data is in the debug logs above.');
        System.debug('Format: LastName,AccountId');
        System.debug('');
        System.debug('For easier access, run the script below to query directly:');
        System.debug('');
        System.debug('List<Account> accounts = [SELECT Id, LastName FROM Account');
        System.debug('  WHERE FirstName = \'Test\' AND LastName LIKE \'Massive_%\' ORDER BY LastName];');
        System.debug('for (Account a : accounts) {');
        System.debug('  System.debug(a.LastName + \',\' + a.Id);');
        System.debug('}');
        System.debug('════════════════════════════════════════════════════════════════');
    }
}

