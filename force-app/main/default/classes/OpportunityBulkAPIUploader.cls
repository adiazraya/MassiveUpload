/**
 * Uploads Opportunities using Salesforce Bulk API 2.0
 * Handles 2M+ records by making HTTP callouts to Bulk API
 * 
 * Usage:
 *   OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
 *   uploader.addRecord(externalId, stageName, amount, accountId, name);
 *   // ... add all records
 *   uploader.executeUpload(); // Starts the batch process
 */
public class OpportunityBulkAPIUploader {
    
    // Instance variable to accumulate records
    private List<OpportunityData> recordBuffer = new List<OpportunityData>();
    private static final Integer BATCH_SIZE = 10000;
    private static final Integer RECORDS_PER_BATCH_EXECUTION = 50000; // 5 API calls per batch
    
    // Inner class to hold opportunity data
    public class OpportunityData {
        public String externalId;
        public String stageName;
        public Decimal amount;
        public String accountId;
        public String name;
        public String closeDate;
        
        public OpportunityData(String extId, String stage, Decimal amt, String accId, String oppName, Date closeDate) {
            this.externalId = extId;
            this.stageName = stage;
            this.amount = amt;
            this.accountId = accId;
            this.name = oppName;
            this.closeDate = String.valueOf(closeDate);
        }
    }
    
    /**
     * Add a single record to the buffer
     */
    public void addRecord(String externalId, String stageName, Decimal amount, String accountId, String oppName, Date closeDate) {
        recordBuffer.add(new OpportunityData(externalId, stageName, amount, accountId, oppName, closeDate));
    }
    
    /**
     * Execute the upload process using Batch Apex
     */
    public void executeUpload() {
        if (recordBuffer.isEmpty()) {
            System.debug('No records to upload');
            return;
        }
        
        System.debug('Starting bulk upload for ' + recordBuffer.size() + ' records');
        
        // Start the batch job
        OpportunityBulkAPIBatch batch = new OpportunityBulkAPIBatch(recordBuffer);
        Database.executeBatch(batch, 50000); // Process 50K records per batch (5 API calls)
    }
    
    /**
     * Get current buffer size
     */
    public Integer getBufferSize() {
        return recordBuffer.size();
    }
    
    // Static buffer to accumulate records across multiple Flow invocations
    private static List<OpportunityData> staticBuffer = new List<OpportunityData>();
    private static Integer totalRecordsProcessed = 0;
    private static Integer batchesCreated = 0;
    
    /**
     * Invocable method for Flow - Upload single Opportunity via Bulk API
     * This method can be called from Flow Builder for each record
     */
    @InvocableMethod(
        label='Upload Opportunities via Bulk API'
        description='Uploads opportunities using Salesforce Bulk API 2.0. Accumulates records and processes in batches.'
        category='Opportunity'
    )
    public static List<FlowResponse> uploadOpportunityFromFlow(List<FlowRequest> requests) {
        List<FlowResponse> responses = new List<FlowResponse>();
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BULK API UPLOADER - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Transaction ID: ' + Request.getCurrent().getRequestId());
        System.debug('Current User: ' + UserInfo.getUserName());
        System.debug('Timestamp: ' + System.now());
        System.debug('Requests received: ' + (requests != null ? requests.size() : 0));
        System.debug('Current buffer size: ' + staticBuffer.size());
        System.debug('Total processed so far: ' + totalRecordsProcessed);
        System.debug('Batches created so far: ' + batchesCreated);
        
        if (requests == null || requests.isEmpty()) {
            System.debug('ERROR: No requests provided');
            FlowResponse response = new FlowResponse();
            response.success = false;
            response.message = 'No record provided';
            responses.add(response);
            return responses;
        }
        
        FlowRequest request = requests[0];
        FlowResponse response = new FlowResponse();
        
        System.debug('────────────────────────────────────────────────────────');
        System.debug('Record Details:');
        System.debug('  External ID: ' + request.externalId);
        System.debug('  Name: ' + request.name);
        System.debug('  Stage: ' + request.stageName);
        System.debug('  Amount: ' + request.amount);
        System.debug('  Account ID: ' + request.accountId);
        System.debug('  Close Date: ' + request.closeDate);
        System.debug('────────────────────────────────────────────────────────');
        
        try {
            // Set default close date if not provided
            Date closeDate = request.closeDate != null ? request.closeDate : Date.today().addDays(30);
            
            // Add record to static buffer
            OpportunityData oppData = new OpportunityData(
                request.externalId,
                request.stageName,
                request.amount,
                request.accountId,
                request.name,
                closeDate
            );
            staticBuffer.add(oppData);
            totalRecordsProcessed++;
            
            System.debug('✓ Record added to buffer');
            System.debug('  Buffer size now: ' + staticBuffer.size());
            System.debug('  Total records processed: ' + totalRecordsProcessed);
            
            response.success = true;
            response.message = 'Record added. Buffer: ' + staticBuffer.size() + ', Total processed: ' + totalRecordsProcessed;
            response.recordCount = staticBuffer.size();
            
            // Auto-trigger upload when buffer reaches 10,000 records
            if (staticBuffer.size() >= 10000) {
                System.debug('════════════════════════════════════════════════════════');
                System.debug('TRIGGERING BATCH UPLOAD - 10,000 records reached!');
                System.debug('════════════════════════════════════════════════════════');
                
                OpportunityBulkAPIBatch batch = new OpportunityBulkAPIBatch(new List<OpportunityData>(staticBuffer));
                Id batchJobId = Database.executeBatch(batch, 50000);
                batchesCreated++;
                
                System.debug('✓ Batch job created: ' + batchJobId);
                System.debug('  Batch number: ' + batchesCreated);
                System.debug('  Records in batch: ' + staticBuffer.size());
                System.debug('  Clearing buffer...');
                
                response.message = 'Batch #' + batchesCreated + ' submitted (Job ID: ' + batchJobId + '). Records: 10000. Total processed: ' + totalRecordsProcessed;
                staticBuffer.clear();
                
                System.debug('✓ Buffer cleared. New size: ' + staticBuffer.size());
            }
            
        } catch (Exception e) {
            System.debug('════════════════════════════════════════════════════════');
            System.debug('ERROR OCCURRED!');
            System.debug('════════════════════════════════════════════════════════');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('════════════════════════════════════════════════════════');
            
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
            response.recordCount = 0;
        }
        
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BULK API UPLOADER - END');
        System.debug('Final buffer size: ' + staticBuffer.size());
        System.debug('Total processed: ' + totalRecordsProcessed);
        System.debug('Batches created: ' + batchesCreated);
        System.debug('════════════════════════════════════════════════════════');
        
        responses.add(response);
        return responses;
    }
    
    /**
     * Public method to manually trigger upload of buffered records
     * Call this from a scheduled job or batch apex
     */
    public static FlowResponse flushBuffer() {
        FlowResponse response = new FlowResponse();
        
        try {
            if (staticBuffer.isEmpty()) {
                response.success = true;
                response.message = 'No records in buffer to upload';
                response.recordCount = 0;
            } else {
                Integer count = staticBuffer.size();
                OpportunityBulkAPIBatch batch = new OpportunityBulkAPIBatch(new List<OpportunityData>(staticBuffer));
                Database.executeBatch(batch, 50000);
                staticBuffer.clear();
                
                response.success = true;
                response.message = 'Successfully queued ' + count + ' records for upload';
                response.recordCount = count;
            }
        } catch (Exception e) {
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
            response.recordCount = 0;
        }
        
        return response;
    }
    
    /**
     * Get current static buffer size
     */
    public static Integer getStaticBufferSize() {
        return staticBuffer.size();
    }
    
    /**
     * Input class for Flow - individual opportunity fields
     */
    public class FlowRequest {
        @InvocableVariable(label='External ID' description='Unique external identifier' required=true)
        public String externalId;
        
        @InvocableVariable(label='Stage Name' description='Opportunity stage (e.g., Prospecting)' required=true)
        public String stageName;
        
        @InvocableVariable(label='Amount' description='Opportunity amount' required=true)
        public Decimal amount;
        
        @InvocableVariable(label='Account ID' description='Related Account ID' required=true)
        public String accountId;
        
        @InvocableVariable(label='Name' description='Opportunity name' required=true)
        public String name;
        
        @InvocableVariable(label='Close Date' description='Close date (defaults to 30 days from today if not provided)' required=false)
        public Date closeDate;
    }
    
    /**
     * Output class for Flow - represents the response
     */
    public class FlowResponse {
        @InvocableVariable(label='Success' description='Whether the upload was queued successfully')
        public Boolean success;
        
        @InvocableVariable(label='Message' description='Result message')
        public String message;
        
        @InvocableVariable(label='Record Count' description='Number of records queued for upload')
        public Integer recordCount;
    }
}
