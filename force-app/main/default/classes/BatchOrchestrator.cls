/**
 * PRODUCTION ORCHESTRATOR
 * Called by Scheduled Flow every 5 minutes
 * Manages the entire 2M record sync process
 */
public class BatchOrchestrator {
    
    @InvocableMethod(label='Check and Start Batch' description='Checks if batch should run and starts it if needed')
    public static List<Result> checkAndStartBatch() {
        Result result = new Result();
        
        try {
            // Get or create progress tracker
            DataCloudSyncProgress__c progress = getProgress();
            
            // Check if batch is currently running
            List<AsyncApexJob> runningBatches = [
                SELECT Id, Status
                FROM AsyncApexJob 
                WHERE ApexClass.Name = 'DataCloudBatchProcessor'
                AND Status IN ('Processing', 'Queued', 'Preparing')
                LIMIT 1
            ];
            
            if (!runningBatches.isEmpty()) {
                result.message = 'Batch already running';
                result.action = 'WAIT';
                return new List<Result>{ result };
            }
            
            // Check if we need to process more records
            Integer currentOffset = Integer.valueOf(progress.CurrentOffset__c);
            
            // Query Data Cloud to see if more records exist
            String sqlQuery = 
                'SELECT "ExternalId__c" FROM "ExtOpportunities__dlm" ' +
                'ORDER BY "ExternalId__c" ' +
                'LIMIT 1 OFFSET ' + currentOffset;
            
            ConnectApi.CdpQueryInput queryInput = new ConnectApi.CdpQueryInput();
            queryInput.sql = sqlQuery;
            
            ConnectApi.CdpQueryOutputV2 queryOutput = ConnectApi.CdpQuery.queryAnsiSqlV2(queryInput);
            
            if (queryOutput == null || queryOutput.data == null || queryOutput.data.isEmpty()) {
                result.message = 'ALL COMPLETE! ' + progress.TotalProcessed__c + ' records processed';
                result.action = 'COMPLETE';
                progress.Status__c = 'Completed';
                update progress;
                return new List<Result>{ result };
            }
            
            // Start next batch
            DataCloudBatchProcessor batch = new DataCloudBatchProcessor(
                currentOffset,
                Integer.valueOf(progress.TotalProcessed__c),
                Integer.valueOf(progress.TotalBulkAPICalls__c),
                0
            );
            
            Id batchId = Database.executeBatch(batch, 1);
            
            progress.Status__c = 'Running';
            progress.LastBatchStarted__c = System.now();
            update progress;
            
            result.message = 'Started batch at offset ' + currentOffset + ' (Job: ' + batchId + ')';
            result.action = 'STARTED';
            
        } catch (Exception e) {
            result.message = 'ERROR: ' + e.getMessage();
            result.action = 'ERROR';
            System.debug('BatchOrchestrator error: ' + e.getMessage() + ' at ' + e.getStackTraceString());
        }
        
        return new List<Result>{ result };
    }
    
    private static DataCloudSyncProgress__c getProgress() {
        List<DataCloudSyncProgress__c> existing = [
            SELECT CurrentOffset__c, TotalProcessed__c, TotalBulkAPICalls__c, 
                   Status__c, LastBatchStarted__c
            FROM DataCloudSyncProgress__c
            WHERE Name = 'Default'
            LIMIT 1
        ];
        
        if (!existing.isEmpty()) {
            return existing[0];
        }
        
        // Create initial record
        DataCloudSyncProgress__c progress = new DataCloudSyncProgress__c(
            Name = 'Default',
            CurrentOffset__c = 0,
            TotalProcessed__c = 0,
            TotalBulkAPICalls__c = 0,
            Status__c = 'Initialized'
        );
        insert progress;
        return progress;
    }
    
    public class Result {
        @InvocableVariable(label='Message' description='Status message')
        public String message;
        
        @InvocableVariable(label='Action' description='Action taken: STARTED, WAIT, COMPLETE, or ERROR')
        public String action;
    }
}

