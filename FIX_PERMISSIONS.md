# FIXING FIELD-LEVEL SECURITY PERMISSIONS

The fields exist but aren't accessible due to permissions. Here's how to fix it:

## Option 1: Grant Field Access via UI (FASTEST - 2 minutes)

### Step 1: Go to Field-Level Security
1. **Setup** → **Object Manager**
2. Click **Data Cloud Partition**
3. Click on each field name (one at a time):
   - Current Offset
   - Last Batch Started
   - Status
   - Total Bulk API Calls
   - Total Processed
   - (PartitionId is probably already accessible)

### Step 2: For each field:
1. Click **Set Field-Level Security**
2. Check the box for **System Administrator** (and any other profiles you use)
3. Check both **Visible** and **Editable**
4. Click **Save**

### Step 3: Verify
```bash
sf apex run --file test_soql_access.apex --target-org MassiveUploadOrg
```

Should show: `✅ SUCCESS! All fields are accessible`

---

## Option 2: Grant Access to All Fields at Once

1. **Setup** → **Users** → **Profiles**
2. Click on your profile (probably **System Administrator**)
3. Scroll down to **Custom Object Permissions**
4. Find **Data Cloud Partitions**
5. Click **Edit**
6. Under **Field Permissions**, check **Read** and **Edit** for all 6 fields
7. Click **Save**

---

## Option 3: Use Permission Set (if you prefer)

1. **Setup** → **Permission Sets** → **New**
2. Name: `Data Cloud Sync Access`
3. Save
4. Click **Object Settings** → **Data Cloud Partitions**
5. Click **Edit**
6. Enable all field permissions
7. Save
8. Assign the permission set to your user

---

## Quick Check Command

Run this after fixing permissions:
```bash
sf apex run --file test_soql_access.apex --target-org MassiveUploadOrg
```

Let me know once you've granted the permissions and the test passes!




