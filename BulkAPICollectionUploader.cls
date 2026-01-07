/**
 * Processes collections of opportunities from Data Cloud Flow
 * Receives up to 10,000 records per invocation and sends to Bulk API
 * 
 * Flow Configuration:
 *   - Data Cloud activation batches 10,000 records
 *   - Flow receives collection
 *   - Flow calls this Apex action with collection
 *   - Apex makes 1 Bulk API call with all 10K records
 */
public class BulkAPICollectionUploader {
    
    /**
     * Invocable method that receives a collection of opportunity records from Flow
     * and processes them via Bulk API
     */
    @InvocableMethod(
        label='Process Opportunity Collection via Bulk API'
        description='Receives a collection of opportunities and processes them via Bulk API in one batch'
        category='Opportunity'
    )
    public static List<CollectionResponse> processOpportunityCollection(List<CollectionRequest> requests) {
        System.debug('════════════════════════════════════════════════════════');
        System.debug('BULK API COLLECTION UPLOADER - START');
        System.debug('════════════════════════════════════════════════════════');
        System.debug('Timestamp: ' + System.now());
        System.debug('Transaction ID: ' + Request.getCurrent().getRequestId());
        System.debug('Requests received: ' + (requests != null ? requests.size() : 0));
        
        List<CollectionResponse> responses = new List<CollectionResponse>();
        CollectionResponse response = new CollectionResponse();
        
        if (requests == null || requests.isEmpty()) {
            System.debug('✗ No requests provided');
            response.success = false;
            response.message = 'No request provided';
            response.recordCount = 0;
            responses.add(response);
            return responses;
        }
        
        CollectionRequest request = requests[0];
        
        if (request.opportunities == null || request.opportunities.isEmpty()) {
            System.debug('✗ No opportunities in request');
            response.success = false;
            response.message = 'No opportunities provided in collection';
            response.recordCount = 0;
            responses.add(response);
            return responses;
        }
        
        System.debug('────────────────────────────────────────────────────────');
        System.debug('Collection received with ' + request.opportunities.size() + ' records');
        System.debug('────────────────────────────────────────────────────────');
        
        try {
            // Convert Flow records to OpportunityData objects
            List<OpportunityBulkAPIUploader.OpportunityData> oppDataList = 
                new List<OpportunityBulkAPIUploader.OpportunityData>();
            
            Integer validRecords = 0;
            Integer errorRecords = 0;
            
            for (OpportunityRecord oppRecord : request.opportunities) {
                try {
                    // Set default close date if not provided
                    Date closeDate = oppRecord.closeDate != null ? 
                        oppRecord.closeDate : Date.today().addDays(30);
                    
                    OpportunityBulkAPIUploader.OpportunityData oppData = 
                        new OpportunityBulkAPIUploader.OpportunityData(
                            oppRecord.externalId,
                            oppRecord.stageName,
                            oppRecord.amount,
                            oppRecord.accountId,
                            oppRecord.name,
                            closeDate
                        );
                    
                    oppDataList.add(oppData);
                    validRecords++;
                    
                } catch (Exception e) {
                    errorRecords++;
                    System.debug('✗ Error converting record: ' + e.getMessage());
                    System.debug('  External ID: ' + oppRecord.externalId);
                }
            }
            
            System.debug('✓ Converted ' + validRecords + ' records successfully');
            if (errorRecords > 0) {
                System.debug('⚠ Failed to convert ' + errorRecords + ' records');
            }
            
            if (oppDataList.isEmpty()) {
                System.debug('✗ No valid records to process');
                response.success = false;
                response.message = 'No valid records to process';
                response.recordCount = 0;
                responses.add(response);
                return responses;
            }
            
            // Send to Bulk API
            System.debug('────────────────────────────────────────────────────────');
            System.debug('Sending ' + oppDataList.size() + ' records to Bulk API...');
            
            OpportunityBulkAPIBatch bulkBatch = new OpportunityBulkAPIBatch(oppDataList);
            Id batchJobId = Database.executeBatch(bulkBatch, 50000);
            
            System.debug('✓ Bulk API batch job created: ' + batchJobId);
            System.debug('════════════════════════════════════════════════════════');
            System.debug('BULK API COLLECTION UPLOADER - SUCCESS');
            System.debug('════════════════════════════════════════════════════════');
            
            response.success = true;
            response.message = 'Successfully queued ' + oppDataList.size() + ' records for Bulk API upload. Job ID: ' + batchJobId;
            response.recordCount = oppDataList.size();
            response.batchJobId = String.valueOf(batchJobId);
            
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
            response.message = 'Error: ' + e.getMessage() + ' (Line ' + e.getLineNumber() + ')';
            response.recordCount = 0;
        }
        
        responses.add(response);
        return responses;
    }
    
    /**
     * Input wrapper - the collection request from Flow
     */
    public class CollectionRequest {
        @InvocableVariable(
            label='Opportunity Records' 
            description='Collection of opportunity records to process (up to 10,000)'
            required=true
        )
        public List<OpportunityRecord> opportunities;
    }
    
    /**
     * Individual opportunity record structure
     * This maps to the fields from your Data Cloud object
     */
    public class OpportunityRecord {
        @InvocableVariable(
            label='External ID'
            description='Unique external identifier'
            required=true
        )
        public String externalId;
        
        @InvocableVariable(
            label='Stage Name'
            description='Opportunity stage (e.g., Prospecting, Closed Won)'
            required=true
        )
        public String stageName;
        
        @InvocableVariable(
            label='Amount'
            description='Opportunity amount'
            required=true
        )
        public Decimal amount;
        
        @InvocableVariable(
            label='Account ID'
            description='Related Account ID (18-character Salesforce ID)'
            required=true
        )
        public String accountId;
        
        @InvocableVariable(
            label='Name'
            description='Opportunity name'
            required=true
        )
        public String name;
        
        @InvocableVariable(
            label='Close Date'
            description='Opportunity close date (defaults to 30 days from today if not provided)'
            required=false
        )
        public Date closeDate;
    }
    
    /**
     * Output response back to Flow
     */
    public class CollectionResponse {
        @InvocableVariable(
            label='Success'
            description='Whether the batch was successfully queued'
        )
        public Boolean success;
        
        @InvocableVariable(
            label='Message'
            description='Result message with details'
        )
        public String message;
        
        @InvocableVariable(
            label='Record Count'
            description='Number of records processed'
        )
        public Integer recordCount;
        
        @InvocableVariable(
            label='Batch Job ID'
            description='Salesforce Batch Apex Job ID for monitoring'
        )
        public String batchJobId;
    }
}








