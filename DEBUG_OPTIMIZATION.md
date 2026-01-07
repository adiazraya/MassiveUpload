# Debug Logging Optimization

## Date: December 18, 2025

## Problem
Debug logs have size limits (20MB per log, 1000MB per 24 hours). With 2,000 batches running, excessive debug statements could:
- Fill up debug logs
- Make troubleshooting harder (too much noise)
- Potentially slow down execution (minimal impact)

**Important:** Process CONTINUES even if debug logs fill up. Debug logging doesn't stop execution.

## Solution: Smart Logging

### Changes Applied
1. **Log only every 100th batch** (every 100,000 records)
   - Reduces log volume by 99%
   - Still provides progress visibility
   
2. **Removed decorative borders** (═══════)
   - Saves ~60 characters per batch
   
3. **Condensed messages:**
   - Before: `✓ Bulk API call made (1000 records)`
   - After: (no message, only on errors)
   
4. **Always log critical events:**
   - Exceptions
   - Bulk API errors
   - Completion messages

### Debug Output
**Normal operation (every 100 batches):**
```
START Offset: 0
EXEC Offset: 0, Total: 0, Bulk Calls: 0
Progress: 100000 records, 100 API calls, Offset: 100000
FINISH Offset: 100000, Total: 100000
Next batch scheduled at offset 100000
...
Progress: 200000 records, 200 API calls, Offset: 200000
...
ALL COMPLETE: 2000000 records, 2000 API calls
```

**On errors (always logged):**
```
Bulk API ERROR offset 50000: [error message]
EXCEPTION at offset 75000
Type: CalloutException
Message: [error details]
```

### Benefits
✅ **99% reduction in log volume**  
✅ **Still see progress every 100K records**  
✅ **All errors are captured**  
✅ **Process runs uninterrupted**  
✅ **Easier to read logs**

## Files Changed
- `force-app/main/default/classes/DataCloudBatchProcessor.cls`

## Usage
No changes needed - same scripts work:
- `start_fresh_upsert.apex` - Process all 2M records
- `resume_processing.apex` - Resume from specific offset

## Monitoring
Even with minimal logging, you can still monitor via SOQL:
```apex
// Check progress
Integer count = [SELECT COUNT() FROM Opportunity];
System.debug('Opportunities: ' + count);

// Check batch status
List<AsyncApexJob> jobs = [
    SELECT Status, CreatedDate, NumberOfErrors
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'DataCloudBatchProcessor'
    AND CreatedDate = TODAY
    ORDER BY CreatedDate DESC LIMIT 10
];
```






