/**
 * Schedulable wrapper for the nightly Data Cloud to Salesforce sync
 * Schedule to run every night at a specific time
 * 
 * Usage in Execute Anonymous:
 *   // Schedule for every night at 2 AM
 *   String cronExp = '0 0 2 * * ?';
 *   System.schedule('Nightly Opportunity Sync', cronExp, new NightlyOpportunitySyncScheduler());
 * 
 * Or use Setup → Apex Classes → Schedule Apex
 */
public class NightlyOpportunitySyncScheduler implements Schedulable {
    
    public void execute(SchedulableContext context) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('NIGHTLY OPPORTUNITY SYNC STARTED');
        System.debug('Scheduled Job ID: ' + context.getTriggerId());
        System.debug('════════════════════════════════════════════════════════');
        
        // Check if there's already a batch running
        List<AsyncApexJob> runningBatches = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'DataCloudBatchProcessor'
            AND Status IN ('Processing', 'Queued', 'Preparing')
            LIMIT 1
        ];
        
        if (!runningBatches.isEmpty()) {
            System.debug('⚠ Batch already running, skipping this execution');
            System.debug('Running job ID: ' + runningBatches[0].Id);
            return;
        }
        
        // Start the batch processor from offset 0
        // Upsert will update existing and create new records
        DataCloudBatchProcessor batch = new DataCloudBatchProcessor();
        Id batchJobId = Database.executeBatch(batch, 1);
        
        System.debug('✓ Batch started: ' + batchJobId);
        System.debug('════════════════════════════════════════════════════════');
    }
}






