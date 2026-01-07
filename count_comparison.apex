// Check Data Cloud count
ConnectApi.CdpQueryInput input = new ConnectApi.CdpQueryInput();
input.sql = 'SELECT COUNT(*) as total FROM "ExtOpportunities__dlm"';
ConnectApi.CdpQueryOutputV2 output = ConnectApi.CdpQuery.queryAnsiSqlV2(input);

List<Object> row = (List<Object>) JSON.deserializeUntyped(JSON.serialize(output.data[0]));
Integer dcCount = Integer.valueOf(String.valueOf(row[0]));

Integer sfCount = [SELECT COUNT() FROM Opportunity];

System.debug('Data Cloud: ' + dcCount);
System.debug('Salesforce: ' + sfCount);
System.debug('Gap: ' + (dcCount - sfCount));

if (sfCount >= dcCount) {
    System.debug('✅ COMPLETE - All records synced!');
} else {
    System.debug('⚠️ Missing ' + (dcCount - sfCount) + ' records');
}




