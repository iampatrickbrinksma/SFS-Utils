public with sharing class sfsSchedulingPolicyUtil {

    // Default clone settings
    private static Boolean preserveId = false;
    private static Boolean isDeepClone = true;
    private static Boolean preserveReadonlyTimestamps = false;
    private static Boolean preserveAutonumber = false;    

    @AuraEnabled(cacheable=false)
    public static Id clonePolicy(Id schedulingPolicyId, String policyName) {
        // Build SOQL query to query all 
        // fields from Scheduling Policy object
        String spQuery = getAllFieldsQuery(
            'FSL__Scheduling_Policy__c', 
            'Id = \'' + schedulingPolicyId + '\''
        );

        // Build SOQL query to query all 
        // fields from Scheduling Policy Work Rule junction object        
        String wrQuery = getAllFieldsQuery(
            'FSL__Scheduling_Policy_Work_Rule__c', 
            'FSL__Scheduling_Policy__c = \'' + schedulingPolicyId + '\' AND FSL__Work_Rule__r.Name NOT IN (\'Earliest Start Permitted\', \'Due Date\')'
        );

        // Build SOQL query to query all 
        // fields from Scheduling Policy Service Objective junction object                
        String soQuery = getAllFieldsQuery(
            'FSL__Scheduling_Policy_Goal__c', 
            'FSL__Scheduling_Policy__c = \'' + schedulingPolicyId + '\''
        );

        // Clone Scheduling Policy and use the new name
        FSL__Scheduling_Policy__c sp = Database.query(spQuery);
        FSL__Scheduling_Policy__c spNew = sp.clone(preserveId, isDeepClone, preserveReadonlyTimestamps, preserveAutonumber);
        spNew.Name = policyName;
        insert spNew;

        // Clone the Scheduling Policy Work Rule junction records
        List<FSL__Scheduling_Policy_Work_Rule__c> wrs = Database.query(wrQuery);
        if (!wrs.isEmpty()){
            List<FSL__Scheduling_Policy_Work_Rule__c> wrsNew = (List<FSL__Scheduling_Policy_Work_Rule__c>) cloneRecords(wrs, 'FSL__Scheduling_Policy__c', spNew.Id);
            insert wrsNew;
        }

        // Clone the Scheduling Policy Service Objectives junction records
        List<FSL__Scheduling_Policy_Goal__c> sos = Database.query(soQuery);
        if (!sos.isEmpty()){
            List<FSL__Scheduling_Policy_Goal__c> sosNew = (List<FSL__Scheduling_Policy_Goal__c>) cloneRecords(sos, 'FSL__Scheduling_Policy__c', spNew.Id);
            insert sosNew;
        }
        
        // Return record Id for navigation (LWC)
        return spNew.Id;
    }

    // Build query including all fields of an SObject
    private static String getAllFieldsQuery(String objectAPIName, String whereClause) {
        List<String> fields = new List<String>(Schema.getGlobalDescribe().get(objectAPIName).getDescribe().fields.getMap().keySet());
        return 'SELECT '+ String.join(fields, ',') + ' FROM ' + objectAPIName + ' WHERE ' + whereClause;
    }    

    // Clone a list of records 
    private static List<SObject> cloneRecords(List<SObject> objs, String parentAPIField, Id parentId){
        List<SObject> clonedRecords = new List<SObject>();
        for (SObject obj : objs){
            SObject clonedObj = obj.clone(preserveId, isDeepClone, preserveReadonlyTimestamps, preserveAutonumber);
            clonedObj.put(parentAPIField, parentId);
            clonedRecords.add(clonedObj);
        }
        return clonedRecords;
    }
    
}