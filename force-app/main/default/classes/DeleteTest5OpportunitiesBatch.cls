/**
 * Batch class to delete Test5 opportunities  
 */
global class DeleteTest5OpportunitiesBatch implements Database.Batchable<SObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id FROM Opportunity WHERE StageName = \'Test5\'');
    }
    
    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        try {
            delete scope;
            System.debug('✓ Deleted ' + scope.size() + ' Test5 opportunities');
        } catch (Exception e) {
            System.debug('✗ Error: ' + e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        Integer remaining = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test5'];
        System.debug('════════════════════════════════════════════════════════════════');
        System.debug('✅ TEST5 DELETION COMPLETE!');
        System.debug('════════════════════════════════════════════════════════════════');
        System.debug('Remaining Test5 opportunities: ' + remaining);
        
        if (remaining == 0) {
            System.debug('');
            System.debug('🚀 Ready to start Test7!');
            System.debug('   Run: sf apex run --file start_staggered.apex --target-org MassiveUploadOrg');
        }
        System.debug('════════════════════════════════════════════════════════════════');
    }
}


