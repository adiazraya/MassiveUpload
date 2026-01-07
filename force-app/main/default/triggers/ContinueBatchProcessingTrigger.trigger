/**
 * Trigger for ContinueBatchProcessing__e Platform Event
 * Implements 2-minute delay before starting next batch
 * This prevents concurrent Bulk API jobs and record locking
 */
trigger ContinueBatchProcessingTrigger on ContinueBatchProcessing__e (after insert) {
    for (ContinueBatchProcessing__e event : Trigger.New) {
        // Use Queueable with delay to implement 2-minute wait
        System.enqueueJob(new DelayedBatchStarter(
            Integer.valueOf(event.currentOffset__c),
            Integer.valueOf(event.totalProcessed__c),
            Integer.valueOf(event.totalBulkAPICalls__c),
            Integer.valueOf(event.maxRecords__c)
        ));
    }
}




