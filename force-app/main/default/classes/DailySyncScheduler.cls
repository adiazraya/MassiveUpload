/**
 * Schedulable wrapper for DailySyncProcessor
 * Schedule this to run nightly
 */
public class DailySyncScheduler implements Schedulable {
    public void execute(SchedulableContext context) {
        // Start the daily sync
        DailySyncProcessor batch = new DailySyncProcessor();
        Database.executeBatch(batch, 1);
    }
}




