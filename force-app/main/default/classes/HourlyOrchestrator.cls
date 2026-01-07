/**
 * HOURLY ORCHESTRATOR - Manages the daily sync process
 * Runs every hour, checks progress, starts new batch if needed
 * Avoids self-scheduling bug by using external hourly trigger
 */
public class HourlyOrchestrator implements Schedulable {
    
    public void execute(SchedulableContext context) {
        System.debug('=== Hourly Orchestrator Running ===');
        
        // Check if DailySyncProcessor is currently running
        List<AsyncApexJob> runningBatches = [
            SELECT Id, Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'DailySyncProcessor'
            AND Status IN ('Processing', 'Queued', 'Preparing')
            LIMIT 1
        ];
        
        if (!runningBatches.isEmpty()) {
            System.debug('Sync already running, waiting');
            return;
        }
        
        // Get or create progress record
        List<DataCloudPartition__c> progressList = [
            SELECT CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, Status__c
            FROM DataCloudPartition__c
            WHERE Name = 'DailySync'
            LIMIT 1
        ];
        
        DataCloudPartition__c progress;
        if (progressList.isEmpty()) {
            // First run - initialize
            progress = new DataCloudPartition__c(
                Name = 'DailySync',
                PartitionId__c = 0,
                CurrentOffset__c = 0,
                TotalProcessed__c = 0,
                TotalBulkAPICalls__c = 0,
                Status__c = 'Running'
            );
            insert progress;
            System.debug('Initialized new sync');
        } else {
            progress = progressList[0];
        }
        
        // Check if completed
        if (progress.Status__c == 'Completed') {
            System.debug('Sync already completed for today');
            return;
        }
        
        // Start next batch
        System.debug('Starting batch from offset: ' + progress.CurrentOffset__c);
        DailySyncProcessor batch = new DailySyncProcessor();
        batch.currentOffset = Integer.valueOf(progress.CurrentOffset__c);
        batch.totalProcessed = Integer.valueOf(progress.TotalProcessed__c);
        batch.totalBulkAPICalls = Integer.valueOf(progress.TotalBulkAPICalls__c);
        
        Database.executeBatch(batch, 1);
        System.debug('Batch started');
    }
}

