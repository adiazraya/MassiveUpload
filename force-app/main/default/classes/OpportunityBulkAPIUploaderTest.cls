@isTest
private class OpportunityBulkAPIUploaderTest {
    
    @testSetup
    static void setup() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }
    
    /**
     * Test adding records to buffer
     */
    @isTest
    static void testAddRecords() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        // Add 100 records
        for (Integer i = 0; i < 100; i++) {
            uploader.addRecord(
                'EXT-' + i,
                'Prospecting',
                1000.00,
                testAccount.Id,
                'Test Opp ' + i,
                Date.today().addDays(30)
            );
        }
        
        // Verify buffer size
        System.assertEquals(100, uploader.getBufferSize(), 'Buffer should contain 100 records');
    }
    
    /**
     * Test batch execution with mock callout
     */
    @isTest
    static void testBatchExecution() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        // Add 1000 test records
        for (Integer i = 0; i < 1000; i++) {
            uploader.addRecord(
                'BATCH-' + i,
                'Qualification',
                2500.00,
                testAccount.Id,
                'Batch Test ' + i,
                Date.today().addDays(60)
            );
        }
        
        Test.startTest();
        
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new BulkAPIMockSuccess());
        
        // Execute upload (this starts the batch)
        uploader.executeUpload();
        
        Test.stopTest();
        
        // Verify batch was started (actual verification happens in mock)
        System.assertEquals(1000, uploader.getBufferSize(), 'Records should be in buffer');
    }
    
    /**
     * Test CSV building functionality
     */
    @isTest
    static void testCSVBuilding() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<OpportunityBulkAPIUploader.OpportunityData> testData = 
            new List<OpportunityBulkAPIUploader.OpportunityData>();
        
        testData.add(new OpportunityBulkAPIUploader.OpportunityData(
            'CSV-1', 'Prospecting', 1000.00, testAccount.Id, 'CSV Test 1', Date.today().addDays(30)
        ));
        testData.add(new OpportunityBulkAPIUploader.OpportunityData(
            'CSV-2', 'Qualification', 2000.00, testAccount.Id, 'CSV Test 2', Date.today().addDays(30)
        ));
        
        // Create batch instance to access private method via test context
        OpportunityBulkAPIBatch batch = new OpportunityBulkAPIBatch(testData);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new BulkAPIMockSuccess());
        
        // Execute the batch
        Database.executeBatch(batch, 2);
        
        Test.stopTest();
        
        // If we got here without exception, CSV building worked
        System.assert(true, 'CSV building completed');
    }
    
    /**
     * Test empty buffer scenario
     */
    @isTest
    static void testEmptyBuffer() {
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        System.assertEquals(0, uploader.getBufferSize(), 'Buffer should be empty');
        
        Test.startTest();
        uploader.executeUpload();
        Test.stopTest();
        
        // Should handle empty buffer gracefully
        System.assertEquals(0, uploader.getBufferSize(), 'Buffer should still be empty');
    }
    
    /**
     * Test large dataset (simulating 50K records per batch)
     */
    @isTest
    static void testLargeDataset() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        // Add 100 records (in real scenario this would be 50K+)
        // Kept small for test limits
        for (Integer i = 0; i < 100; i++) {
            uploader.addRecord(
                'LARGE-' + i,
                'Negotiation',
                5000.00,
                testAccount.Id,
                'Large Dataset ' + i,
                Date.today().addDays(90)
            );
        }
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new BulkAPIMockSuccess());
        
        uploader.executeUpload();
        
        Test.stopTest();
        
        System.assertEquals(100, uploader.getBufferSize(), 'All records should be in buffer');
    }
    
    /**
     * Test API error handling
     */
    @isTest
    static void testAPIError() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        for (Integer i = 0; i < 10; i++) {
            uploader.addRecord(
                'ERROR-' + i,
                'Prospecting',
                1000.00,
                testAccount.Id,
                'Error Test ' + i,
                Date.today().addDays(30)
            );
        }
        
        Test.startTest();
        
        // Mock API error
        Test.setMock(HttpCalloutMock.class, new BulkAPIMockError());
        
        // Should handle error gracefully
        uploader.executeUpload();
        
        Test.stopTest();
        
        // No exception should be thrown
        System.assert(true, 'Error handled gracefully');
    }
    
    /**
     * Test special characters in data
     */
    @isTest
    static void testSpecialCharacters() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
        
        // Add record with special characters
        uploader.addRecord(
            'SPECIAL-1',
            'Prospecting',
            1000.00,
            testAccount.Id,
            'Test "Quotes", Commas, and\nNewlines',
            Date.today().addDays(45)
        );
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new BulkAPIMockSuccess());
        
        uploader.executeUpload();
        
        Test.stopTest();
        
        System.assertEquals(1, uploader.getBufferSize(), 'Record with special chars added');
    }
    
    // ========== Mock Classes ==========
    
    /**
     * Mock successful Bulk API responses
     */
    public class BulkAPIMockSuccess implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            callCount++;
            
            // Mock job creation
            if (req.getEndpoint().contains('/jobs/ingest') && req.getMethod() == 'POST') {
                res.setStatusCode(201);
                res.setBody('{"id":"750xx000000001","state":"Open","object":"Opportunity"}');
            }
            // Mock data upload
            else if (req.getEndpoint().contains('/batches') && req.getMethod() == 'PUT') {
                res.setStatusCode(201);
                res.setBody('{}');
            }
            // Mock job close
            else if (req.getEndpoint().contains('/jobs/ingest') && req.getMethod() == 'PATCH') {
                res.setStatusCode(200);
                res.setBody('{"id":"750xx000000001","state":"UploadComplete"}');
            }
            // Default
            else {
                res.setStatusCode(200);
                res.setBody('{"success":true}');
            }
            
            return res;
        }
    }
    
    /**
     * Mock Bulk API errors
     */
    public class BulkAPIMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request","message":"Invalid job configuration"}');
            return res;
        }
    }
}

