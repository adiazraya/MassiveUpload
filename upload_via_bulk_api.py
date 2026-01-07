"""
Upload opportunities to Salesforce using the OpportunityBulkAPIUploader Apex class
Handles 2 million records by sending them to Apex, which makes Bulk API calls

Prerequisites:
    pip install simple-salesforce pandas requests

Setup:
    1. Deploy OpportunityBulkAPIUploader.cls to Salesforce
    2. Create External_Id__c field on Opportunity
    3. Configure Remote Site Settings in Salesforce
    4. Deploy the REST API endpoint (included below)
"""

import pandas as pd
import requests
from simple_salesforce import Salesforce
import os
import time
from typing import List, Dict
import json

class BulkAPIUploader:
    def __init__(self, username: str, password: str, security_token: str, domain: str = 'login'):
        """Initialize Salesforce connection."""
        self.sf = Salesforce(
            username=username,
            password=password,
            security_token=security_token,
            domain=domain
        )
        self.instance_url = f"https://{self.sf.sf_instance}"
        self.session_id = self.sf.session_id
        print(f"Connected to Salesforce: {self.instance_url}")
    
    def deploy_rest_endpoint(self):
        """
        Deploy the REST API endpoint to receive bulk uploads.
        This creates an Apex REST class that uses OpportunityBulkAPIUploader.
        """
        apex_code = '''@RestResource(urlMapping='/api/opportunity/bulk/*')
global class OpportunityBulkRestAPI {
    
    @HttpPost
    global static Response uploadOpportunities(List<OppRecord> records) {
        try {
            OpportunityBulkAPIUploader uploader = new OpportunityBulkAPIUploader();
            
            for (OppRecord rec : records) {
                uploader.addRecord(
                    rec.externalId,
                    rec.stageName,
                    rec.amount,
                    rec.accountId,
                    rec.name
                );
            }
            
            Id jobId = uploader.executeUpload();
            
            return new Response(
                true, 
                'Success', 
                records.size(),
                jobId != null ? String.valueOf(jobId) : null
            );
            
        } catch (Exception e) {
            return new Response(false, e.getMessage(), 0, null);
        }
    }
    
    global class OppRecord {
        global String externalId;
        global String stageName;
        global Decimal amount;
        global String accountId;
        global String name;
    }
    
    global class Response {
        global Boolean success;
        global String message;
        global Integer recordCount;
        global String batchJobId;
        
        global Response(Boolean success, String message, Integer count, String jobId) {
            this.success = success;
            this.message = message;
            this.recordCount = count;
            this.batchJobId = jobId;
        }
    }
}'''
        
        print("\n" + "="*60)
        print("IMPORTANT: Deploy this Apex REST class to Salesforce")
        print("="*60)
        print("\n1. Go to Setup → Apex Classes → New")
        print("2. Copy and paste the following code:")
        print("\n" + "-"*60)
        print(apex_code)
        print("-"*60)
        print("\n3. Click Save")
        print("4. Then run this script again\n")
    
    def upload_csv_via_bulk_api(self, csv_file: str, chunk_size: int = 50000):
        """
        Upload CSV file by sending chunks to Apex REST endpoint.
        Apex will handle Bulk API calls internally.
        
        Args:
            csv_file: Path to CSV file
            chunk_size: Number of records per chunk (50K = 5 API calls in Apex)
        """
        print(f"\n{'='*60}")
        print(f"Starting upload via Bulk API Uploader")
        print(f"{'='*60}\n")
        
        # Read CSV
        print(f"Reading CSV: {csv_file}")
        df = pd.read_csv(csv_file)
        total_records = len(df)
        print(f"Total records: {total_records:,}")
        
        # Calculate chunks
        num_chunks = (total_records + chunk_size - 1) // chunk_size
        print(f"Will process in {num_chunks} chunks of up to {chunk_size:,} records")
        
        # REST API endpoint
        endpoint = f"{self.instance_url}/services/apexrest/api/opportunity/bulk"
        headers = {
            'Authorization': f'Bearer {self.session_id}',
            'Content-Type': 'application/json'
        }
        
        # Process chunks
        chunks_processed = 0
        records_processed = 0
        batch_job_ids = []
        
        for i in range(0, total_records, chunk_size):
            chunk_num = i // chunk_size + 1
            end_idx = min(i + chunk_size, total_records)
            chunk_df = df.iloc[i:end_idx]
            
            print(f"\n[Chunk {chunk_num}/{num_chunks}] Processing records {i+1:,} to {end_idx:,}")
            
            # Prepare records for this chunk
            records = []
            for _, row in chunk_df.iterrows():
                records.append({
                    'externalId': str(row['ExternalId']),
                    'stageName': str(row['StageName']),
                    'amount': float(row['Amount']),
                    'accountId': str(row['Account']),
                    'name': str(row['Name'])
                })
            
            # Send to Apex REST API
            try:
                print(f"  → Sending {len(records):,} records to Salesforce...")
                response = requests.post(
                    endpoint,
                    headers=headers,
                    json=records,
                    timeout=300  # 5 minute timeout
                )
                
                if response.status_code == 200:
                    result = response.json()
                    
                    if result.get('success'):
                        chunks_processed += 1
                        records_processed += result.get('recordCount', 0)
                        
                        job_id = result.get('batchJobId')
                        if job_id:
                            batch_job_ids.append(job_id)
                        
                        print(f"  ✓ Success! Batch Job ID: {job_id if job_id else 'N/A'}")
                        print(f"  ✓ Records processed: {result.get('recordCount', 0):,}")
                    else:
                        print(f"  ✗ Error: {result.get('message', 'Unknown error')}")
                else:
                    print(f"  ✗ HTTP Error {response.status_code}: {response.text}")
                    
            except Exception as e:
                print(f"  ✗ Exception: {str(e)}")
            
            # Small delay between chunks
            if chunk_num < num_chunks:
                time.sleep(2)
        
        # Summary
        print(f"\n{'='*60}")
        print(f"Upload Complete!")
        print(f"{'='*60}")
        print(f"Total chunks sent: {chunks_processed}/{num_chunks}")
        print(f"Total records sent: {records_processed:,}/{total_records:,}")
        print(f"Batch jobs created: {len(batch_job_ids)}")
        
        if batch_job_ids:
            print(f"\nBatch Job IDs:")
            for idx, job_id in enumerate(batch_job_ids, 1):
                print(f"  {idx}. {job_id}")
        
        print(f"\n{'='*60}")
        print(f"Monitor Progress:")
        print(f"{'='*60}")
        print(f"1. Check batch jobs: Setup → Apex Jobs")
        print(f"2. Check bulk API jobs: Setup → Bulk Data Load Jobs")
        print(f"3. Query opportunities: Execute Anonymous")
        print(f"   System.debug([SELECT COUNT() FROM Opportunity WHERE External_Id__c != null]);")
        print(f"\nProcessing Time: ~60-90 minutes for 2M records")
        print(f"{'='*60}\n")
    
    def monitor_batch_jobs(self):
        """Query and display batch job status."""
        query = """
            SELECT Id, ApexClass.Name, Status, NumberOfErrors, 
                   JobItemsProcessed, TotalJobItems, CreatedDate
            FROM AsyncApexJob 
            WHERE ApexClass.Name = 'OpportunityBulkAPIBatch'
            ORDER BY CreatedDate DESC
            LIMIT 10
        """
        
        print(f"\n{'='*60}")
        print("Recent Batch Jobs")
        print(f"{'='*60}\n")
        
        try:
            results = self.sf.query(query)
            
            if results['totalSize'] == 0:
                print("No batch jobs found")
            else:
                for record in results['records']:
                    print(f"Job ID: {record['Id']}")
                    print(f"  Status: {record['Status']}")
                    print(f"  Progress: {record['JobItemsProcessed']}/{record['TotalJobItems']}")
                    print(f"  Errors: {record['NumberOfErrors']}")
                    print(f"  Created: {record['CreatedDate']}")
                    print()
                    
        except Exception as e:
            print(f"Error querying jobs: {str(e)}")
    
    def check_upload_progress(self):
        """Check how many opportunities have been created."""
        try:
            # Count opportunities with External_Id__c
            query = "SELECT COUNT() FROM Opportunity WHERE External_Id__c != null"
            result = self.sf.query(query)
            count = result['totalSize']
            
            print(f"\n{'='*60}")
            print(f"Opportunities with External ID: {count:,}")
            print(f"{'='*60}\n")
            
            return count
            
        except Exception as e:
            print(f"Error checking progress: {str(e)}")
            return 0


def main():
    """Main execution."""
    
    # Configuration
    SF_USERNAME = os.getenv('SF_USERNAME', 'your_username@example.com')
    SF_PASSWORD = os.getenv('SF_PASSWORD', 'your_password')
    SF_SECURITY_TOKEN = os.getenv('SF_SECURITY_TOKEN', 'your_token')
    SF_DOMAIN = os.getenv('SF_DOMAIN', 'test')  # 'test' for sandbox, 'login' for production
    
    CSV_FILE = 'generated_opportunities_enhanced.csv'
    CHUNK_SIZE = 50000  # 50K records per chunk = 5 Bulk API calls per batch
    
    print("""
╔══════════════════════════════════════════════════════════════╗
║     Salesforce Opportunity Bulk API Uploader                 ║
║     Handles 2M+ records with 200 API calls                   ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    # Connect to Salesforce
    try:
        uploader = BulkAPIUploader(
            username=SF_USERNAME,
            password=SF_PASSWORD,
            security_token=SF_SECURITY_TOKEN,
            domain=SF_DOMAIN
        )
    except Exception as e:
        print(f"\n✗ Connection failed: {str(e)}")
        print("\nPlease set these environment variables:")
        print("  export SF_USERNAME='your_username@example.com'")
        print("  export SF_PASSWORD='your_password'")
        print("  export SF_SECURITY_TOKEN='your_token'")
        print("  export SF_DOMAIN='test'  # or 'login' for production")
        return
    
    # Menu
    while True:
        print("\nWhat would you like to do?")
        print("1. Show REST API code to deploy")
        print("2. Upload CSV file (2M records)")
        print("3. Check batch job status")
        print("4. Check upload progress")
        print("5. Exit")
        
        choice = input("\nEnter choice (1-5): ").strip()
        
        if choice == '1':
            uploader.deploy_rest_endpoint()
        
        elif choice == '2':
            if not os.path.exists(CSV_FILE):
                print(f"\n✗ CSV file not found: {CSV_FILE}")
                CSV_FILE = input("Enter CSV file path: ").strip()
            
            confirm = input(f"\nUpload {CSV_FILE}? This will process all records. (yes/no): ")
            if confirm.lower() == 'yes':
                uploader.upload_csv_via_bulk_api(CSV_FILE, CHUNK_SIZE)
        
        elif choice == '3':
            uploader.monitor_batch_jobs()
        
        elif choice == '4':
            uploader.check_upload_progress()
        
        elif choice == '5':
            print("\nGoodbye!")
            break
        
        else:
            print("\n✗ Invalid choice")


if __name__ == '__main__':
    main()









