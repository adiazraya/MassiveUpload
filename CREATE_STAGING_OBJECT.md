# Create Staging Object for Data Cloud Flow

## Step-by-Step: Create Opportunity_Staging__c

### 1. Create Custom Object

**Setup → Object Manager → Create → Custom Object**

**Object Settings:**
- Label: `Opportunity Staging`
- Plural Label: `Opportunity Stagings`
- Object Name: `Opportunity_Staging`
- Record Name: `Staging Record`
- Data Type: Auto Number
- Display Format: `STG-{00000}`
- Starting Number: `1`

**Optional Features:**
- ✅ Allow Reports
- ✅ Allow Activities
- ✅ Track Field History (optional)
- ✅ Allow Search

Click **Save**

---

### 2. Create Custom Fields

**For each field below, go to: Object Manager → Opportunity Staging → Fields & Relationships → New**

#### Field 1: External_Id__c
- Data Type: **Text**
- Field Label: `External Id`
- Length: `255`
- Field Name: `External_Id__c`
- Required: ✅
- Unique: ✅
- External ID: ✅

#### Field 2: Stage_Name__c
- Data Type: **Text**
- Field Label: `Stage Name`
- Length: `255`
- Required: ✅

#### Field 3: Amount__c
- Data Type: **Number**
- Field Label: `Amount`
- Length: `18`
- Decimal Places: `2`

#### Field 4: Account_Id__c
- Data Type: **Text**
- Field Label: `Account Id`
- Length: `18`
- Required: ✅

#### Field 5: Opportunity_Name__c
- Data Type: **Text**
- Field Label: `Opportunity Name`
- Length: `255`
- Required: ✅

#### Field 6: Close_Date__c
- Data Type: **Date**
- Field Label: `Close Date`

#### Field 7: Processed__c
- Data Type: **Checkbox**
- Field Label: `Processed`
- Default Value: **Unchecked**

#### Field 8: Processed_Date__c
- Data Type: **Date/Time**
- Field Label: `Processed Date`

---

### 3. Create List View (Optional but Helpful)

**Object Manager → Opportunity Staging → List Views → New**

Name: `Unprocessed Records`
Filter:
- `Processed__c equals False`

Columns:
- Staging Record Name
- External Id
- Stage Name
- Amount
- Account Id
- Opportunity Name
- Close Date
- Created Date

---

### 4. Update Your Flow

**In your Data Cloud activated Flow:**

1. Remove the "Upload Opportunities via Bulk API" action
2. Add **Create Records** action:
   - Object: `Opportunity Staging`
   - Set Field Values:
     ```
     External_Id__c = {!$Record.externalid__c}
     Stage_Name__c = {!$Record.stagename__c}
     Amount__c = {!$Record.amount__c}
     Account_Id__c = {!$Record.account__c}
     Opportunity_Name__c = {!$Record.name__c}
     Close_Date__c = {!$Record.closedate__c}
     Processed__c = {!$GlobalConstant.False}
     ```
3. Save and Activate

---

### 5. Let Data Cloud Load All Records

Your Flow will now run 2M times, each creating 1 staging record.

**Monitor progress:**
```apex
// Run in Execute Anonymous to check progress
Integer total = [SELECT COUNT() FROM Opportunity_Staging__c];
Integer unprocessed = [SELECT COUNT() FROM Opportunity_Staging__c WHERE Processed__c = false];
System.debug('Total staging records: ' + total);
System.debug('Unprocessed: ' + unprocessed);
```

---

### 6. Process Staging Records via Batch

**Once all 2M staging records are created**, run this in Execute Anonymous:

```apex
OpportunityStagingProcessor processor = new OpportunityStagingProcessor();
Database.executeBatch(processor, 10000);
System.debug('Batch started! Check Setup → Apex Jobs for progress.');
```

**Monitor the batch:**
```apex
AsyncApexJob job = [
    SELECT Status, JobItemsProcessed, TotalJobItems, NumberOfErrors
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'OpportunityStagingProcessor'
    ORDER BY CreatedDate DESC LIMIT 1
];
System.debug('Status: ' + job.Status);
System.debug('Progress: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
```

---

## Summary of the Pattern

```
┌─────────────────────────────────────────┐
│ Data Cloud (2M records)                 │
│ ExtOpportunities__dlm                   │
└──────────────┬──────────────────────────┘
               │
               │ Triggers Flow 2M times
               │ (each record = separate transaction)
               ▼
┌─────────────────────────────────────────┐
│ Flow (2M executions)                    │
│ Each: 1 DML = Create Staging Record    │
│ Total: 2M staging records ✅            │
└──────────────┬──────────────────────────┘
               │
               │ After completion
               ▼
┌─────────────────────────────────────────┐
│ Batch Apex                              │
│ OpportunityStagingProcessor             │
│ Reads 10K at a time                     │
└──────────────┬──────────────────────────┘
               │
               │ 200 Bulk API calls
               ▼
┌─────────────────────────────────────────┐
│ Bulk API 2.0 (200 jobs)                │
│ Each: 10K records                       │
└──────────────┬──────────────────────────┘
               │
               │ Upserts
               ▼
┌─────────────────────────────────────────┐
│ Opportunity Object                      │
│ 2M records created ✅                   │
└─────────────────────────────────────────┘
```

**This is the ONLY way** to make Flow + Bulk API work with 2M records!








