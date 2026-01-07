/**
 * Batch class to delete ALL opportunities with External_ID__c
 * Used for cleaning up test data before re-testing the nightly sync
 */
public class DeleteTestOpportunitiesBatch implements Database.Batchable<SObject> {
    
    public Database.QueryLocator start(Database.BatchableContext context) {
        // Query all opportunities from external system (have External_ID__c)
        return Database.getQueryLocator([
            SELECT Id 
            FROM Opportunity 
            WHERE External_ID__c != null
        ]);
    }
    
    public void execute(Database.BatchableContext context, List<Opportunity> scope) {
        Database.delete(scope, false);
    }
    
    public void finish(Database.BatchableContext context) {
        System.debug('Deletion complete');
        Integer remainingCount = [SELECT COUNT() FROM Opportunity WHERE External_ID__c != null];
        System.debug('Remaining opportunities with External_ID__c: ' + remainingCount);
    }
}






