// List ALL fields with their exact API names
System.debug('All fields on DataCloudPartition__c:');
System.debug('═══════════════════════════════════════════════════════════════');

Schema.DescribeSObjectResult describe = DataCloudPartition__c.sObjectType.getDescribe();
Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();

for (String apiName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(apiName).getDescribe();
    System.debug(field.getLabel() + ' → ' + field.getName());
}




