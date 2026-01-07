@isTest
private class OpportunityBulkUploaderTest {
    
    @testSetup
    static void setup() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }
    
    /**
     * Test adding records one by one and automatic batch processing
     */
    @isTest
    static void testBulkUploadWithAutoBatch() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Add 10,000 records to trigger automatic batch processing
        for (Integer i = 0; i < 10000; i++) {
            OpportunityBulkUploader.addRecord(
                'EXT-' + i,                    // externalId
                'Prospecting',                  // stageName
                1000.00 + i,                   // amount
                testAccount.Id,                // accountId
                'Test Opportunity ' + i        // oppName
            );
        }
        
        Test.stopTest();
        
        // Verify records were inserted
        List<Opportunity> insertedOpps = [SELECT Id, External_Id__c FROM Opportunity];
        System.assertEquals(10000, insertedOpps.size(), 'Should have inserted 10,000 opportunities');
        
        // Verify buffer was cleared
        System.assertEquals(0, OpportunityBulkUploader.getBufferSize(), 'Buffer should be empty after batch');
    }
    
    /**
     * Test flush method for remaining records
     */
    @isTest
    static void testFlushRemainingRecords() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Add less than batch size
        for (Integer i = 0; i < 500; i++) {
            OpportunityBulkUploader.addRecord(
                'EXT-FLUSH-' + i,
                'Qualification',
                2000.00,
                testAccount.Id,
                'Flush Test ' + i
            );
        }
        
        // Buffer should have 500 records
        System.assertEquals(500, OpportunityBulkUploader.getBufferSize(), 'Buffer should have 500 records');
        
        // Flush remaining records
        OpportunityBulkUploader.flush();
        
        Test.stopTest();
        
        // Verify records were inserted
        List<Opportunity> insertedOpps = [SELECT Id FROM Opportunity WHERE External_Id__c LIKE 'EXT-FLUSH-%'];
        System.assertEquals(500, insertedOpps.size(), 'Should have inserted 500 opportunities');
        
        // Verify buffer was cleared
        System.assertEquals(0, OpportunityBulkUploader.getBufferSize(), 'Buffer should be empty after flush');
    }
    
    /**
     * Test upsert functionality (update existing records)
     */
    @isTest
    static void testUpsertExistingRecords() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // First, insert some opportunities
        List<Opportunity> initialOpps = new List<Opportunity>();
        for (Integer i = 0; i < 100; i++) {
            Opportunity opp = new Opportunity(
                External_Id__c = 'UPSERT-' + i,
                Name = 'Initial Opp ' + i,
                StageName = 'Prospecting',
                Amount = 500.00,
                CloseDate = Date.today(),
                AccountId = testAccount.Id
            );
            initialOpps.add(opp);
        }
        insert initialOpps;
        
        Test.startTest();
        
        // Now use the uploader to update these records
        for (Integer i = 0; i < 100; i++) {
            OpportunityBulkUploader.addRecord(
                'UPSERT-' + i,
                'Closed Won',           // Changed stage
                1500.00,                // Changed amount
                testAccount.Id,
                'Updated Opp ' + i      // Changed name
            );
        }
        
        OpportunityBulkUploader.flush();
        
        Test.stopTest();
        
        // Verify records were updated (not duplicated)
        List<Opportunity> updatedOpps = [
            SELECT Id, Name, StageName, Amount, External_Id__c 
            FROM Opportunity 
            WHERE External_Id__c LIKE 'UPSERT-%'
        ];
        
        System.assertEquals(100, updatedOpps.size(), 'Should still have only 100 opportunities');
        
        // Verify at least one was updated
        Opportunity firstOpp = updatedOpps[0];
        System.assertEquals('Closed Won', firstOpp.StageName, 'Stage should be updated');
        System.assertEquals(1500.00, firstOpp.Amount, 'Amount should be updated');
    }
    
    /**
     * Test adding Opportunity objects directly
     */
    @isTest
    static void testAddOpportunityObject() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        for (Integer i = 0; i < 50; i++) {
            Opportunity opp = new Opportunity(
                External_Id__c = 'OBJ-' + i,
                Name = 'Object Test ' + i,
                StageName = 'Negotiation',
                Amount = 3000.00,
                CloseDate = Date.today().addDays(60),
                AccountId = testAccount.Id
            );
            OpportunityBulkUploader.addRecord(opp);
        }
        
        OpportunityBulkUploader.flush();
        
        Test.stopTest();
        
        List<Opportunity> insertedOpps = [SELECT Id FROM Opportunity WHERE External_Id__c LIKE 'OBJ-%'];
        System.assertEquals(50, insertedOpps.size(), 'Should have inserted 50 opportunities');
    }
    
    /**
     * Test clear buffer functionality
     */
    @isTest
    static void testClearBuffer() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        // Add some records
        for (Integer i = 0; i < 10; i++) {
            OpportunityBulkUploader.addRecord(
                'CLEAR-' + i,
                'Prospecting',
                1000.00,
                testAccount.Id,
                'Clear Test ' + i
            );
        }
        
        System.assertEquals(10, OpportunityBulkUploader.getBufferSize(), 'Buffer should have 10 records');
        
        // Clear without processing
        OpportunityBulkUploader.clearBuffer();
        
        System.assertEquals(0, OpportunityBulkUploader.getBufferSize(), 'Buffer should be empty');
        
        // Verify no records were inserted
        List<Opportunity> opps = [SELECT Id FROM Opportunity WHERE External_Id__c LIKE 'CLEAR-%'];
        System.assertEquals(0, opps.size(), 'No opportunities should be inserted');
    }
    
    /**
     * Test processing multiple batches
     */
    @isTest
    static void testMultipleBatches() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Add 25,000 records (will trigger 2 full batches + 5,000 in buffer)
        for (Integer i = 0; i < 25000; i++) {
            OpportunityBulkUploader.addRecord(
                'MULTI-' + i,
                'Prospecting',
                1000.00,
                testAccount.Id,
                'Multi Batch ' + i
            );
        }
        
        // Should have 5,000 remaining in buffer
        System.assertEquals(5000, OpportunityBulkUploader.getBufferSize(), 'Buffer should have 5,000 records');
        
        // Flush remaining
        OpportunityBulkUploader.flush();
        
        Test.stopTest();
        
        // Verify all records were inserted
        List<Opportunity> insertedOpps = [SELECT Id FROM Opportunity WHERE External_Id__c LIKE 'MULTI-%'];
        System.assertEquals(25000, insertedOpps.size(), 'Should have inserted 25,000 opportunities');
    }
}









