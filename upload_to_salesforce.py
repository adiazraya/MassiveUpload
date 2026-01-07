"""
Integration script to upload opportunities from CSV to Salesforce
using the OpportunityBulkUploader Apex class.

Prerequisites:
    pip install simple-salesforce pandas

Setup:
    1. Deploy OpportunityBulkUploader.cls to your Salesforce org
    2. Create External_Id__c field on Opportunity object
    3. Set your Salesforce credentials in environment variables or update below
"""

import pandas as pd
from simple_salesforce import Salesforce
import os
from typing import List, Dict
import time

class SalesforceOpportunityUploader:
    def __init__(self, username: str, password: str, security_token: str, domain: str = 'login'):
        """
        Initialize Salesforce connection.
        
        Args:
            username: Salesforce username
            password: Salesforce password
            security_token: Salesforce security token
            domain: 'login' for production, 'test' for sandbox
        """
        self.sf = Salesforce(
            username=username,
            password=password,
            security_token=security_token,
            domain=domain
        )
        print(f"Connected to Salesforce: {self.sf.sf_instance}")
    
    def upload_opportunities_via_apex(self, csv_file: str, batch_size: int = 10000):
        """
        Upload opportunities using the OpportunityBulkUploader Apex class.
        
        Args:
            csv_file: Path to CSV file with opportunity data
            batch_size: Number of records to process in each Apex call (default: 10000)
        """
        print(f"Reading CSV file: {csv_file}")
        df = pd.read_csv(csv_file)
        total_records = len(df)
        print(f"Total records to upload: {total_records}")
        
        # Process in batches
        batches_processed = 0
        records_processed = 0
        
        for start_idx in range(0, total_records, batch_size):
            end_idx = min(start_idx + batch_size, total_records)
            batch_df = df.iloc[start_idx:end_idx]
            
            print(f"\nProcessing batch {batches_processed + 1}: Records {start_idx + 1} to {end_idx}")
            
            # Build Apex script for this batch
            apex_script = self._build_apex_script(batch_df)
            
            # Execute anonymous Apex
            try:
                result = self.sf.restful('tooling/executeAnonymous/', params={'anonymousBody': apex_script})
                
                if result['compiled'] and result['success']:
                    records_processed += len(batch_df)
                    batches_processed += 1
                    print(f"✓ Batch processed successfully. Total processed: {records_processed}/{total_records}")
                else:
                    print(f"✗ Error in batch: {result.get('compileProblem', result.get('exceptionMessage', 'Unknown error'))}")
                    
            except Exception as e:
                print(f"✗ Exception during batch processing: {str(e)}")
            
            # Small delay to avoid rate limits
            time.sleep(0.5)
        
        # Final flush
        print("\nFlushing remaining records...")
        flush_script = "OpportunityBulkUploader.flush();"
        self.sf.restful('tooling/executeAnonymous/', params={'anonymousBody': flush_script})
        
        print(f"\n{'='*50}")
        print(f"Upload Complete!")
        print(f"Total batches: {batches_processed}")
        print(f"Total records processed: {records_processed}")
        print(f"{'='*50}")
    
    def _build_apex_script(self, batch_df: pd.DataFrame) -> str:
        """Build Apex anonymous script for a batch of records."""
        apex_lines = []
        
        for idx, row in batch_df.iterrows():
            # Escape single quotes in strings
            external_id = str(row['ExternalId']).replace("'", "\\'")
            name = str(row['Name']).replace("'", "\\'")
            stage_name = str(row['StageName']).replace("'", "\\'")
            account_id = str(row['Account'])
            amount = float(row['Amount'])
            
            apex_line = (
                f"OpportunityBulkUploader.addRecord('{external_id}', "
                f"'{stage_name}', {amount}, '{account_id}', '{name}');"
            )
            apex_lines.append(apex_line)
        
        return '\n'.join(apex_lines)
    
    def upload_opportunities_via_bulk_api(self, csv_file: str):
        """
        Alternative method: Upload using Salesforce Bulk API 2.0.
        This is more efficient for very large datasets.
        
        Args:
            csv_file: Path to CSV file with opportunity data
        """
        print(f"Reading CSV file: {csv_file}")
        df = pd.read_csv(csv_file)
        
        # Transform dataframe to match Salesforce field names
        sf_df = pd.DataFrame({
            'External_Id__c': df['ExternalId'],
            'Name': df['Name'],
            'AccountId': df['Account'],
            'Amount': df['Amount'],
            'StageName': df['StageName'],
            'CloseDate': pd.to_datetime(df['CloseDate'], format='%d/%m/%Y').dt.strftime('%Y-%m-%d')
        })
        
        print(f"Total records to upload: {len(sf_df)}")
        
        # Convert to list of dictionaries
        records = sf_df.to_dict('records')
        
        # Use bulk API (this requires simple-salesforce bulk support)
        try:
            print("Uploading via Bulk API...")
            results = self.sf.bulk.Opportunity.upsert(
                records,
                'External_Id__c',
                batch_size=10000,
                use_serial=False
            )
            
            # Process results
            success_count = sum(1 for r in results if r['success'])
            error_count = len(results) - success_count
            
            print(f"\n{'='*50}")
            print(f"Upload Complete!")
            print(f"Successful: {success_count}")
            print(f"Errors: {error_count}")
            print(f"{'='*50}")
            
            # Print first few errors if any
            if error_count > 0:
                print("\nFirst 5 errors:")
                error_count = 0
                for result in results:
                    if not result['success'] and error_count < 5:
                        print(f"  - {result['errors']}")
                        error_count += 1
                        
        except Exception as e:
            print(f"Error during bulk upload: {str(e)}")


def main():
    """Main execution function."""
    
    # Salesforce Credentials
    # Option 1: Use environment variables (recommended for security)
    SF_USERNAME = os.getenv('SF_USERNAME', 'your_username@example.com')
    SF_PASSWORD = os.getenv('SF_PASSWORD', 'your_password')
    SF_SECURITY_TOKEN = os.getenv('SF_SECURITY_TOKEN', 'your_security_token')
    SF_DOMAIN = os.getenv('SF_DOMAIN', 'login')  # 'login' for production, 'test' for sandbox
    
    # Option 2: Hardcode (not recommended for production)
    # SF_USERNAME = 'your_username@example.com'
    # SF_PASSWORD = 'your_password'
    # SF_SECURITY_TOKEN = 'your_security_token'
    # SF_DOMAIN = 'test'  # or 'login' for production
    
    # CSV file to upload
    CSV_FILE = 'generated_opportunities_enhanced.csv'
    
    try:
        # Initialize uploader
        uploader = SalesforceOpportunityUploader(
            username=SF_USERNAME,
            password=SF_PASSWORD,
            security_token=SF_SECURITY_TOKEN,
            domain=SF_DOMAIN
        )
        
        # Choose upload method:
        
        # Method 1: Via Apex Class (good for demonstrating the Apex class usage)
        # Note: This may hit API limits for very large datasets
        print("\n=== Method 1: Upload via Apex Class ===")
        # uploader.upload_opportunities_via_apex(CSV_FILE, batch_size=10000)
        
        # Method 2: Direct Bulk API (recommended for large datasets)
        print("\n=== Method 2: Upload via Bulk API (Recommended) ===")
        uploader.upload_opportunities_via_bulk_api(CSV_FILE)
        
    except Exception as e:
        print(f"\nError: {str(e)}")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()









