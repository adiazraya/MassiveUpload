// Get more details on the duplicate accounts
System.debug('════════════════════════════════════════════════════════════════');
System.debug('🔍 DETAILED ANALYSIS OF DUPLICATE ACCOUNTS');
System.debug('════════════════════════════════════════════════════════════════');

// Get the 10 accounts with duplicates
AggregateResult[] duplicateAccounts = [
    SELECT AccountId, COUNT(Id) oppCount
    FROM Opportunity
    WHERE AccountId != null
    GROUP BY AccountId
    HAVING COUNT(Id) > 1
    ORDER BY COUNT(Id) DESC
    LIMIT 10
];

System.debug('');
System.debug('Top 10 Accounts with Multiple Opportunities:');
for (AggregateResult ar : duplicateAccounts) {
    String accountId = (String) ar.get('AccountId');
    Integer count = (Integer) ar.get('oppCount');
    
    // Get the account name
    Account acc = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
    
    System.debug('  ' + acc.Name + ' (' + accountId + '): ' + count + ' opportunities');
    
    // Get sample opportunities for this account
    List<Opportunity> opps = [
        SELECT External_ID__c, StageName 
        FROM Opportunity 
        WHERE AccountId = :accountId 
        LIMIT 3
    ];
    
    for (Opportunity opp : opps) {
        System.debug('    - ' + opp.External_ID__c + ' (Stage: ' + opp.StageName + ')');
    }
}

System.debug('');
System.debug('════════════════════════════════════════════════════════════════');




