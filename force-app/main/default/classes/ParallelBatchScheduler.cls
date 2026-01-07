/**
 * Schedulable wrapper for ParallelBatchOrchestrator
 * Allows scheduling the orchestrator to run hourly
 * 
 * Usage in Anonymous Apex:
 *   // Schedule to run every hour
 *   System.schedule('DC Sync - Hour 0', '0 0 * * * ?', new ParallelBatchScheduler());
 *   System.schedule('DC Sync - Hour 1', '0 1 * * * ?', new ParallelBatchScheduler());
 *   // ... repeat for all 24 hours
 */
public class ParallelBatchScheduler implements Schedulable {
    
    public void execute(SchedulableContext context) {
        // Call the orchestrator
        ParallelBatchOrchestrator.checkAndStartParallelBatches();
    }
}




