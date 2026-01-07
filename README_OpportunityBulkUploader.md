# Opportunity Bulk Uploader - Usage Guide

## Overview
The `OpportunityBulkUploader` class provides a efficient way to upsert large volumes of Opportunity records to Salesforce. It automatically accumulates records and performs bulk upserts in batches of 10,000 records.

## Key Features
- **Automatic Batching**: Automatically triggers upsert when 10,000 records are accumulated
- **Upsert Support**: Uses External ID to update existing records or insert new ones
- **Error Handling**: Processes results with partial success (allOrNone=false)
- **Buffer Management**: Tracks and manages records in memory efficiently

## Prerequisites

### 1. Create External ID Field
You need to create a custom External ID field on the Opportunity object:

1. Go to **Setup → Object Manager → Opportunity**
2. Click **Fields & Relationships → New**
3. Select **Text** field type
4. Set the following:
   - Field Label: `External Id`
   - Field Name: `External_Id__c`
   - Length: 255
   - **Check "External ID"**
   - **Check "Unique"** (recommended)
5. Save and add to page layouts

### 2. Update Field API Name (if different)
If your External ID field has a different API name, update these lines in `OpportunityBulkUploader.cls`:
```apex
opp.External_Id__c = externalId;  // Line 19
Database.upsert(recordBuffer, Opportunity.External_Id__c, false);  // Line 51
```

## Usage Examples

### Example 1: Basic Usage (Individual Records)
```apex
// Get Account Id
Id accountId = [SELECT Id FROM Account WHERE Name = 'Acme Corp' LIMIT 1].Id;

// Add records one by one
for (Integer i = 0; i < 15000; i++) {
    OpportunityBulkUploader.addRecord(
        'EXT-2024-' + i,           // External ID (unique identifier)
        'Prospecting',              // Stage Name
        10000.50,                   // Amount
        accountId,                  // Account Id
        'Opportunity ' + i          // Opportunity Name
    );
}

// IMPORTANT: Flush remaining records at the end
OpportunityBulkUploader.flush();
```

### Example 2: Using Opportunity Objects
```apex
List<Opportunity> opportunities = new List<Opportunity>();

// Build your opportunities
for (Integer i = 0; i < 5000; i++) {
    Opportunity opp = new Opportunity();
    opp.External_Id__c = 'IMPORT-' + i;
    opp.Name = 'Imported Opp ' + i;
    opp.StageName = 'Qualification';
    opp.Amount = 25000;
    opp.CloseDate = Date.today().addDays(90);
    opp.AccountId = accountId;
    
    // Add to uploader
    OpportunityBulkUploader.addRecord(opp);
}

// Flush remaining records
OpportunityBulkUploader.flush();
```

### Example 3: Processing CSV Data
```apex
// Assuming you have CSV data parsed into a list
List<String[]> csvRows = parseCSV(); // Your CSV parsing logic

for (String[] row : csvRows) {
    try {
        OpportunityBulkUploader.addRecord(
            row[0],                      // External ID
            row[1],                      // Stage Name
            Decimal.valueOf(row[2]),     // Amount
            Id.valueOf(row[3]),          // Account Id
            row[4]                       // Name
        );
    } catch (Exception e) {
        System.debug('Error processing row: ' + e.getMessage());
    }
}

// Always flush at the end
OpportunityBulkUploader.flush();
```

### Example 4: Batch Apex Integration
```apex
global class OpportunityBatchLoader implements Database.Batchable<sObject> {
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Query your source data
        return Database.getQueryLocator([
            SELECT Id, External_System_Id__c, Name, Amount__c, Account__c, Stage__c
            FROM External_Opportunity__c
        ]);
    }
    
    global void execute(Database.BatchableContext bc, List<External_Opportunity__c> scope) {
        for (External_Opportunity__c extOpp : scope) {
            OpportunityBulkUploader.addRecord(
                extOpp.External_System_Id__c,
                extOpp.Stage__c,
                extOpp.Amount__c,
                extOpp.Account__c,
                extOpp.Name
            );
        }
        
        // Flush after each batch execution
        OpportunityBulkUploader.flush();
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch processing completed');
    }
}
```

### Example 5: REST API Integration
```apex
@RestResource(urlMapping='/api/opportunities/bulk')
global class OpportunityBulkAPI {
    
    @HttpPost
    global static String bulkUpload(List<OpportunityRecord> records) {
        try {
            for (OpportunityRecord rec : records) {
                OpportunityBulkUploader.addRecord(
                    rec.externalId,
                    rec.stageName,
                    rec.amount,
                    rec.accountId,
                    rec.name
                );
            }
            
            OpportunityBulkUploader.flush();
            
            return JSON.serialize(new Response(true, 'Successfully processed ' + records.size() + ' records'));
        } catch (Exception e) {
            return JSON.serialize(new Response(false, e.getMessage()));
        }
    }
    
    global class OpportunityRecord {
        global String externalId;
        global String stageName;
        global Decimal amount;
        global Id accountId;
        global String name;
    }
    
    global class Response {
        global Boolean success;
        global String message;
        
        global Response(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}
```

## Important Methods

### `addRecord(String externalId, String stageName, Decimal amount, Id accountId, String oppName)`
Adds a single record to the buffer. Automatically triggers batch processing when 10,000 records are reached.

### `addRecord(Opportunity opp)`
Alternative method that accepts a complete Opportunity object.

### `flush()`
**CRITICAL**: Must be called at the end of your data loading process to process remaining records in the buffer (less than 10,000).

### `getBufferSize()`
Returns the current number of records in the buffer.

### `clearBuffer()`
Clears the buffer without processing. Use with caution.

## Best Practices

1. **Always Call flush()**: After your data loading loop, always call `OpportunityBulkUploader.flush()` to ensure all records are processed.

2. **Governor Limits**: 
   - The class processes up to 10,000 records per batch
   - Be mindful of Heap Size limits if processing very large volumes
   - Consider using Batch Apex for millions of records

3. **Error Handling**: The upsert uses `allOrNone=false`, meaning:
   - Partial success is allowed
   - Failed records don't rollback successful ones
   - Check debug logs for error details

4. **External ID Field**: 
   - Must be unique to prevent duplicates
   - Use a meaningful naming convention
   - Consider adding validation rules

5. **Testing**: 
   - Test class is provided (`OpportunityBulkUploaderTest`)
   - Achieves >95% code coverage
   - Run tests before deploying to production

## Governor Limits Considerations

- **DML Rows**: Each batch processes up to 10,000 records (within Salesforce limit)
- **Heap Size**: Static variable holds records in memory. For very large volumes, consider:
  - Processing in smaller batches
  - Using Batch Apex
  - Implementing asynchronous processing

## Deployment Steps

1. **Deploy the Apex Class**:
   ```bash
   sf project deploy start --source-path OpportunityBulkUploader.cls
   ```

2. **Deploy the Test Class**:
   ```bash
   sf project deploy start --source-path OpportunityBulkUploaderTest.cls
   ```

3. **Run Tests**:
   ```bash
   sf apex run test --class-names OpportunityBulkUploaderTest --result-format human
   ```

4. **Verify Code Coverage**:
   - Should achieve >95% coverage
   - Required: 75% minimum for production deployment

## Monitoring and Debugging

### View Debug Logs
The class logs important information:
```
Batch processed: 10000 successful, 0 errors
Flushing remaining 5432 records
```

### Check for Errors
```apex
// After processing, query for potential issues
List<Opportunity> orphanedOpps = [
    SELECT Id, External_Id__c 
    FROM Opportunity 
    WHERE AccountId = null
];
```

## Troubleshooting

### Issue: Records Not Being Inserted
- **Solution**: Ensure you call `flush()` at the end of your process

### Issue: Duplicate Records
- **Solution**: Verify External ID field is marked as "Unique"

### Issue: Heap Size Exception
- **Solution**: Process data in smaller chunks using Batch Apex

### Issue: Field API Name Mismatch
- **Solution**: Update the External ID field API name in the class

## Support

For issues or questions:
1. Check Salesforce Debug Logs
2. Verify External ID field configuration
3. Review test class for usage examples
4. Check governor limit usage

---

**Version**: 1.0  
**Last Updated**: December 2025  
**Tested On**: API Version 59.0









