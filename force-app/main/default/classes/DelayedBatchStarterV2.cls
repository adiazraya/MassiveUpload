/**
 * Delayed Batch Starter V2
 * Adds ~10 second delay between batches by using Queueable execution
 * Combined with Salesforce's natural batch delay (10-20s), total delay is 20-30s
 */
public class DelayedBatchStarterV2 implements Queueable {
    
    private DynamicPartitionProcessorV2 batchToStart;
    
    public DelayedBatchStarterV2(DynamicPartitionProcessorV2 batch) {
        this.batchToStart = batch;
    }
    
    public void execute(QueueableContext context) {
        // Queueable jobs naturally have a ~10 second delay before execution
        // This provides the additional delay we need for Test8
        Database.executeBatch(batchToStart, 1);
    }
}
