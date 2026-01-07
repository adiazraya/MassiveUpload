# SIMPLE DAILY SYNC SOLUTION - Final Production Setup

## What This Does

**Simple, repeatable daily sync** from Data Cloud to Salesforce Opportunities:
- Processes ALL records (2M) every night
- Uses Bulk API for performance
- Self-schedules until complete
- Stops automatically when done
- Can be scheduled or run manually

---

## One-Time Setup

### 1. Deploy the Code

```bash
cd /Users/alberto.diazraya/Documents/Projects/caixa/MassiveUpload
sf project deploy start --source-dir force-app/main/default/classes/DailySyncProcessor.cls --source-dir force-app/main/default/classes/DailySyncProcessor.cls-meta.xml --source-dir force-app/main/default/classes/DailySyncScheduler.cls --source-dir force-app/main/default/classes/DailySyncScheduler.cls-meta.xml --target-org MassiveUploadOrg
```

### 2. Schedule It (Runs Every Night at 2 AM)

```bash
sf apex run --file schedule_daily_sync.apex --target-org MassiveUploadOrg
```

**That's it!** The sync will run automatically every night at 2 AM.

---

## Manual Run (For Testing or Immediate Sync)

```bash
sf apex run --file run_daily_sync_now.apex --target-org MassiveUploadOrg
```

---

## How It Works

1. **Queries Data Cloud** - Gets all records from `ExtOpportunities__dlm`
2. **Processes 2,000 at a time** - Batches for performance
3. **Sends to Bulk API** - UPSERTs to Opportunities
4. **Self-schedules next batch** - Continues until all records processed
5. **Stops automatically** - When no more records found

**Performance:** ~2-4 hours for 2M records

---

## Monitoring

**Check progress:**
- Setup → Apex Jobs → Look for "DailySyncProcessor"

**Check Opportunity count:**
```bash
sf apex run -o MassiveUploadOrg --apex-code-file <(echo 'System.debug([SELECT COUNT() FROM Opportunity]);')
```

---

## Emergency Stop

```bash
sf apex run --file emergency_stop.apex --target-org MassiveUploadOrg
```

---

## Architecture

- **DailySyncProcessor** = Main batch class, processes all records
- **DailySyncScheduler** = Wrapper to schedule the batch
- **No partitions** = Simple, linear processing
- **No custom objects** = No state management needed
- **Self-scheduling** = Runs continuously until complete

---

## Why This Is Better

✅ **Simple** - One class, one purpose  
✅ **Repeatable** - Runs the same way every time  
✅ **Complete** - Processes ALL records, not fixed offsets  
✅ **Reliable** - Self-schedules, no external orchestration  
✅ **Fast enough** - Completes within 24 hours  
✅ **Clean** - No leftover state, starts fresh each time  

---

## Ready to Deploy?

Run the two commands above (Deploy + Schedule) and you're done!




