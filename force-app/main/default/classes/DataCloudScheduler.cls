/**
 * Schedulable class to continuously process Data Cloud records
 * Runs every minute and processes next batch of 1000 records
 * 
 * Usage:
 *   // Schedule to run every minute
 *   DataCloudScheduler.scheduleProcessing();
 *   
 *   // Or manually schedule
 *   System.schedule('DataCloud Processor', '0 * * * * ?', new DataCloudScheduler());
 */
global class DataCloudScheduler implements Schedulable {
    
    global void execute(SchedulableContext context) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('SCHEDULER EXECUTING');
        System.debug('════════════════════════════════════════════════════════');
        
        try {
            // Get current progress
            Integer currentOffset = getCurrentOffset();
            System.debug('Current offset: ' + currentOffset);
            
            // Check if there are more records to process
            if (hasMoreRecords(currentOffset)) {
                System.debug('→ More records exist, starting batch...');
                
                // Start a batch for the next chunk
                DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
                    currentOffset, 0, 0
                );
                Database.executeBatch(batch, 1);
                
                System.debug('✓ Batch started for offset ' + currentOffset);
                
                // Reschedule for 1 minute later
                reschedule();
                
            } else {
                System.debug('✓ All records processed! Stopping scheduler.');
                // Don't reschedule - we're done
            }
            
        } catch (Exception e) {
            System.debug('✗ Error: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Get the current processing offset based on Salesforce Opportunity count
     */
    private Integer getCurrentOffset() {
        try {
            // Count opportunities that were created by our process
            // We'll use a simple count for now
            Integer oppCount = [SELECT COUNT() FROM Opportunity];
            
            // Round down to nearest 1000
            return (oppCount / 1000) * 1000;
            
        } catch (Exception e) {
            System.debug('Error getting offset: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * Check if more records exist at the given offset
     */
    private Boolean hasMoreRecords(Integer offset) {
        try {
            String sqlQuery = 
                'SELECT externalid__c FROM ExtOpportunities__dlm ' +
                'ORDER BY externalid__c LIMIT 1 OFFSET ' + offset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            return (queryOutput != null && queryOutput.data != null && !queryOutput.data.isEmpty());
            
        } catch (Exception e) {
            System.debug('Error checking for more records: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Reschedule this job to run in 1 minute
     */
    private void reschedule() {
        try {
            // Abort current scheduled job if it exists
            List<CronTrigger> existingJobs = [
                SELECT Id FROM CronTrigger 
                WHERE CronJobDetail.Name = 'DataCloud Processor Auto'
                AND State != 'DELETED'
            ];
            
            for (CronTrigger job : existingJobs) {
                System.abortJob(job.Id);
            }
            
            // Schedule for 1 minute from now
            Datetime now = Datetime.now();
            Datetime nextRun = now.addMinutes(1);
            
            String cronExp = nextRun.second() + ' ' + 
                           nextRun.minute() + ' ' + 
                           nextRun.hour() + ' ' + 
                           nextRun.day() + ' ' + 
                           nextRun.month() + ' ? ' + 
                           nextRun.year();
            
            System.schedule('DataCloud Processor Auto', cronExp, new DataCloudScheduler());
            System.debug('✓ Rescheduled for ' + nextRun);
            
        } catch (Exception e) {
            System.debug('Error rescheduling: ' + e.getMessage());
        }
    }
    
    /**
     * Public method to start the processing
     */
    public static void scheduleProcessing() {
        // Start immediately
        Datetime now = Datetime.now().addSeconds(10);
        String cronExp = now.second() + ' ' + 
                       now.minute() + ' ' + 
                       now.hour() + ' ' + 
                       now.day() + ' ' + 
                       now.month() + ' ? ' + 
                       now.year();
        
        System.schedule('DataCloud Processor Auto', cronExp, new DataCloudScheduler());
        System.debug('✓ Scheduler started! Will run in 10 seconds.');
    }
    
    /**
     * Stop all scheduled jobs
     */
    public static void stopProcessing() {
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'DataCloud Processor%'
            AND State != 'DELETED'
        ];
        
        for (CronTrigger job : jobs) {
            System.abortJob(job.Id);
            System.debug('✓ Aborted job: ' + job.CronJobDetail.Name);
        }
        
        System.debug('✓ All scheduler jobs stopped.');
    }
}

