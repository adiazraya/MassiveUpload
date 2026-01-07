## 🔍 **LOCKING ISSUE - ROOT CAUSE & FIX**

### 📊 **The Problem:**

- **Expected:** 2,000,000 opportunities
- **Processed:** 1,250,000 (5 partitions × 250,000 each)
- **Actually Created:** 1,114,200
- **Failed:** ~136,000 (**~11% failure rate**)

**Error:** `UNABLE_TO_LOCK_ROW: unable to obtain exclusive access to this record or 200 records`

---

## 🎯 **Root Cause:**

### **Account Locking Conflicts**

Your data has:
- **200,000 Accounts**
- **2,000,000 Opportunities**
- **~10 opportunities per account**

### **What Happens in Each Batch:**

1. Bulk API selects 500 random opportunities from Data Cloud
2. Many of these opportunities belong to the **same accounts**
3. Bulk API **Parallel mode** processes records simultaneously
4. Multiple threads try to lock the same Account record
5. Result: **"UNABLE_TO_LOCK_ROW"** for ~half the batch

### **Example from your logs:**
```
001KZ00000LBSvYYAX  ← Same account
001KZ00000LBNvYYA5  ← appears multiple times
001KZ00000LBSoWYAX  ← in same batch
```

All opportunities for these accounts tried to update in parallel → **Locking conflict!**

---

## ✅ **THE FIX - Serial Concurrency Mode**

### **What Changed:**

```apex
// BEFORE (Parallel mode - default):
{"object":"Opportunity",...,"operation":"upsert","lineEnding":"LF"}

// AFTER (Serial mode):
{"object":"Opportunity",...,"operation":"upsert","lineEnding":"LF","concurrencyMode":"Serial"}
```

### **How Serial Mode Helps:**

1. ✅ **Processes records ONE AT A TIME** within a batch
2. ✅ **No parallel locking conflicts**
3. ✅ **Prevents "UNABLE_TO_LOCK_ROW" errors**
4. ⏱️ **Slightly slower**, but **much higher success rate** (95%+)

---

## 📋 **Next Steps:**

### **1. Clean up Test4 data:**
```bash
sf apex run --file cleanup_test4.apex --target-org MassiveUploadOrg
```

### **2. Wait ~5 minutes** for deletion to complete

### **3. Run Test5** with Serial mode:
```bash
sf apex run --file start_staggered.apex --target-org MassiveUploadOrg
```

---

## 🎯 **Expected Results for Test5:**

| Metric | Test4 (Parallel) | Test5 (Serial) |
|--------|------------------|----------------|
| Mode | Parallel | **Serial** ✅ |
| Records Processed | 1,250,000 | 2,000,000 |
| Records Created | 1,114,200 (89%) | **1,900,000+ (95%+)** ✅ |
| Locking Errors | ~11% ❌ | **<5%** ✅ |
| Processing Time | ~5 hours | **~8-10 hours** (slower but reliable) |

---

**Serial mode trades speed for reliability - perfect for this use case!** 🎯


