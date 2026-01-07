import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# 1. Load your uploaded CSV file
# Ensure this file is in the same directory where you run the script
input_filename = 'Accounts.csv'
df_accounts = pd.read_csv(input_filename)
account_ids = df_accounts['Id'].unique()

# Number of records
num_opportunities = 2000000

# 2. Generate Data
# Account ID
random_account_ids = np.random.choice(account_ids, size=num_opportunities)

# ExternalId & Name
ids = np.arange(1, num_opportunities + 1)
external_ids = [f"externalOpp{i:07d}" for i in ids]
names = [f"name_{eid}" for eid in external_ids]

# Amount
amounts = np.round(np.random.uniform(1, 1000, size=num_opportunities), 2)

# StageName & ForecastCategory
stage_names = ["Discovery"] * num_opportunities
forecast_categories = ["Pipeline"] * num_opportunities

# CloseDate (European Format)
start_date = datetime.today()
days_offset = np.random.randint(0, 91, size=num_opportunities) # 0 to 90 days
dates = pd.Timestamp(start_date) + pd.to_timedelta(days_offset, unit='D')
close_dates = dates.strftime('%d/%m/%Y')

# 3. Create DataFrame
df_enhanced = pd.DataFrame({
    'ExternalId': external_ids,
    'Name': names,
    'Account': random_account_ids,
    'Amount': amounts,
    'StageName': stage_names,
    'ForecastCategory': forecast_categories,
    'CloseDate': close_dates
})

# 4. Save to CSV
output_filename = 'generated_opportunities_enhanced.csv'
df_enhanced.to_csv(output_filename, index=False)

print(f"File {output_filename} created successfully.")