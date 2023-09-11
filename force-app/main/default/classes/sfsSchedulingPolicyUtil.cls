/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class which provides a set of methods to clone a scheduling policies including 
* the work rules and service objective with their respective settings
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsSchedulingPolicyUtil {

    @AuraEnabled(cacheable=false)
    public static Id clonePolicy(Id schedulingPolicyId, String policyName) {
        // Build SOQL query to query all 
        // fields from Scheduling Policy object
        String spQuery = sfsUtil.getAllFieldsQuery(
            'FSL__Scheduling_Policy__c', 
            'Id = \'' + schedulingPolicyId + '\''
        );

        // Build SOQL query to query all 
        // fields from Scheduling Policy Work Rule junction object        
        String wrQuery = sfsUtil.getAllFieldsQuery(
            'FSL__Scheduling_Policy_Work_Rule__c', 
            'FSL__Scheduling_Policy__c = \'' + schedulingPolicyId + '\' AND FSL__Work_Rule__r.Name NOT IN (\'Earliest Start Permitted\', \'Due Date\')'
        );

        // Build SOQL query to query all 
        // fields from Scheduling Policy Service Objective junction object                
        String soQuery = sfsUtil.getAllFieldsQuery(
            'FSL__Scheduling_Policy_Goal__c', 
            'FSL__Scheduling_Policy__c = \'' + schedulingPolicyId + '\''
        );

        // Clone Scheduling Policy and use the new name
        FSL__Scheduling_Policy__c sp = Database.query(spQuery);
        FSL__Scheduling_Policy__c spNew = (FSL__Scheduling_Policy__c) sfsUtil.cloneRecord(sp, null, null);
        spNew.Name = policyName;
        insert spNew;

        // Clone the Scheduling Policy Work Rule junction records
        List<FSL__Scheduling_Policy_Work_Rule__c> wrs = Database.query(wrQuery);
        if (!wrs.isEmpty()){
            List<FSL__Scheduling_Policy_Work_Rule__c> wrsNew = (List<FSL__Scheduling_Policy_Work_Rule__c>) sfsUtil.cloneRecords(wrs, 'FSL__Scheduling_Policy__c', spNew.Id);
            insert wrsNew;
        }

        // Clone the Scheduling Policy Service Objectives junction records
        List<FSL__Scheduling_Policy_Goal__c> sos = Database.query(soQuery);
        if (!sos.isEmpty()){
            List<FSL__Scheduling_Policy_Goal__c> sosNew = (List<FSL__Scheduling_Policy_Goal__c>) sfsUtil.cloneRecords(sos, 'FSL__Scheduling_Policy__c', spNew.Id);
            insert sosNew;
        }
        
        // Return record Id for navigation (LWC)
        return spNew.Id;
    }
    
}