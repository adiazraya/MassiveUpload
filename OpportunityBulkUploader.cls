public class OpportunityBulkUploader {
    
    // Static collection to accumulate records across multiple method calls
    private static List<Opportunity> recordBuffer = new List<Opportunity>();
    private static final Integer BATCH_SIZE = 10000;
    
    /**
     * Receives a single opportunity record and adds it to the buffer.
     * Automatically triggers bulk upsert when buffer reaches 10,000 records.
     * 
     * @param externalId - Unique identifier for upsert operation
     * @param stageName - Opportunity stage (e.g., 'Prospecting', 'Closed Won')
     * @param amount - Opportunity amount
     * @param accountId - Related Account Id
     * @param oppName - Opportunity name
     */
    public static void addRecord(String externalId, String stageName, Decimal amount, Id accountId, String oppName) {
        
        // Create the Opportunity record
        Opportunity opp = new Opportunity();
        opp.External_Id__c = externalId; // Assuming External_Id__c is the external ID field
        opp.StageName = stageName;
        opp.Amount = amount;
        opp.AccountId = accountId;
        opp.Name = oppName;
        opp.CloseDate = Date.today().addDays(30); // Default close date, adjust as needed
        
        // Add to buffer
        recordBuffer.add(opp);
        
        // Check if buffer has reached batch size
        if (recordBuffer.size() >= BATCH_SIZE) {
            processBatch();
        }
    }
    
    /**
     * Alternative method that accepts an Opportunity object directly
     */
    public static void addRecord(Opportunity opp) {
        recordBuffer.add(opp);
        
        if (recordBuffer.size() >= BATCH_SIZE) {
            processBatch();
        }
    }
    
    /**
     * Processes the current batch by performing bulk upsert
     */
    private static void processBatch() {
        if (recordBuffer.isEmpty()) {
            return;
        }
        
        try {
            // Perform upsert using External_Id__c field
            // Replace 'External_Id__c' with your actual external ID field API name
            Database.UpsertResult[] results = Database.upsert(
                recordBuffer, 
                Opportunity.External_Id__c, 
                false // allOrNone = false, allows partial success
            );
            
            // Process results and log errors
            Integer successCount = 0;
            Integer errorCount = 0;
            
            for (Database.UpsertResult result : results) {
                if (result.isSuccess()) {
                    successCount++;
                } else {
                    errorCount++;
                    // Log errors
                    for (Database.Error err : result.getErrors()) {
                        System.debug('Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                        System.debug('Fields: ' + err.getFields());
                    }
                }
            }
            
            System.debug('Batch processed: ' + successCount + ' successful, ' + errorCount + ' errors');
            
        } catch (Exception e) {
            System.debug('Exception during upsert: ' + e.getMessage());
            throw e;
        } finally {
            // Clear the buffer after processing
            recordBuffer.clear();
        }
    }
    
    /**
     * Flushes any remaining records in the buffer.
     * Should be called at the end of your data loading process.
     */
    public static void flush() {
        if (!recordBuffer.isEmpty()) {
            System.debug('Flushing remaining ' + recordBuffer.size() + ' records');
            processBatch();
        }
    }
    
    /**
     * Returns the current buffer size
     */
    public static Integer getBufferSize() {
        return recordBuffer.size();
    }
    
    /**
     * Clears the buffer without processing (use with caution)
     */
    public static void clearBuffer() {
        recordBuffer.clear();
    }
}









