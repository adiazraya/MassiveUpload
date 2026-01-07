## 🔍 **Root Cause Analysis: Locking Errors**

### ❌ **The Problem:**

**Actual:** 1,114,200 opportunities created
**Expected:** 2,000,000 opportunities
**Missing:** ~886,000 (44% failure rate)

**Error:** `UNABLE_TO_LOCK_ROW: unable to obtain exclusive access to this record or 200 records`

---

## 🎯 **Why This Happens:**

### The Account Locking Issue:

1. **Your data structure:**
   - 200,000 Accounts
   - 2,000,000 Opportunities
   - **10 opportunities per account on average**

2. **What's happening in each 500-record batch:**
   - Random 500 opportunities are selected
   - Many belong to the SAME accounts (e.g., 001KZ00000LBSvYYAX)
   - All 10 opps for an account try to update in parallel
   - Account record gets LOCKED → **Half the batch fails!**

3. **Bulk API Parallel Processing:**
   - Within a batch, Bulk API processes records in **parallel**
   - Multiple threads try to lock the same Account
   - Result: "UNABLE_TO_LOCK_ROW"

---

## 🛠️ **Solutions (in order of effectiveness):**

### **Option 1: Sort by AccountId Before Batching** ⭐ BEST
- Group all opportunities for the same account together
- Each batch has opps from different accounts
- Eliminates intra-batch locking

### **Option 2: Use Bulk API Serial Mode**
- Process records one-by-one within a batch
- Slower, but no parallel locking
- Simple flag: `Concurrency = Serial`

### **Option 3: Smaller Batches (200 records)**
- Reduces probability of account collisions
- Still doesn't guarantee no duplicates

### **Option 4: Add delays between batches**
- Already doing this, but still conflicts within batch

---

## 💡 **Recommended Fix:**

**Combine Option 1 + Option 2:**
1. **Sort by AccountId** when querying from Data Cloud
2. **Use Serial mode** in Bulk API
3. Keep 500-record batches (serial mode will be slower, so this is fine)

This should get success rate to **95%+**!

---

Want me to implement this fix?


