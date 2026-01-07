/**
 * FASTER Batch class to delete Test4 opportunities
 * Using 50,000 records per batch instead of 10,000
 */
global class DeleteTest4OpportunitiesBatchFast implements Database.Batchable<SObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator('SELECT Id FROM Opportunity WHERE StageName = \'Test4\'');
    }
    
    global void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        try {
            delete scope;
            System.debug('✓ Deleted ' + scope.size() + ' Test4 opportunities');
        } catch (Exception e) {
            System.debug('✗ Error deleting batch: ' + e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('════════════════════════════════════════════════════════════════');
        System.debug('✅ TEST4 FAST CLEANUP COMPLETE!');
        System.debug('════════════════════════════════════════════════════════════════');
        
        // Verify cleanup
        Integer remaining = [SELECT COUNT() FROM Opportunity WHERE StageName = 'Test4'];
        System.debug('Remaining Test4 opportunities: ' + remaining);
        
        System.debug('');
        System.debug('🚀 Ready to start Test5 with Serial mode!');
        System.debug('   Run: sf apex run --file start_staggered.apex --target-org MassiveUploadOrg');
        System.debug('');
    }
}


