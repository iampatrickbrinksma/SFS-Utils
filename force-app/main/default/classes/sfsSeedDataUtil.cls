/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class which provides a set of methods to deal with Salesforce Field Service seed data
* like the Service Appointment status transitions and backing up and restoring scheduling policies
* including work rules and service objectives
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsSeedDataUtil {

    /*
     * Separator used to store several JSON strings in a single file
     */            
    private final static String fileSeparator = '\n|\n|\n';
    private final static String fileSeparatorRegExpr = '\n\\|\n\\|\n';

    /*
     * Reset the Service Appointment Status Transition values
     * to the default ones which come with the FSL Managed Package
     * It first backs up the current status transitions
     */            
    public static void resetServiceAppointmentStatusTransitions(){
        backupServiceAppointmentStatusTransitions();
        FSL.GlobalAPIS.ClearAllStatusTransitions();
        FSL.GlobalAPIS.addStatusTransition('None', 'Canceled');
        FSL.GlobalAPIS.addStatusTransition('None', 'Scheduled');
        FSL.GlobalAPIS.addStatusTransition('Scheduled', 'None');
        FSL.GlobalAPIS.addStatusTransition('Scheduled', 'Dispatched');
        FSL.GlobalAPIS.addStatusTransition('Scheduled', 'Canceled');
        FSL.GlobalAPIS.addStatusTransition('Dispatched', 'Canceled');
        FSL.GlobalAPIS.addStatusTransition('Dispatched', 'In Progress');
        FSL.GlobalAPIS.addStatusTransition('In Progress', 'Completed');
        FSL.GlobalAPIS.addStatusTransition('In Progress', 'Cannot Complete');
    }

    /*
     * Create a file to restore the current service appointment
     * status transitions. The content of the file can be run as
     * anonymous Apex to restore the values
     */            
    public static void backupServiceAppointmentStatusTransitions(){
        List<FSL.StatusTransition> l = FSL.GlobalAPIS.GetAllStatusTransitions();
        String output = 'FSL.GlobalAPIS.ClearAllStatusTransitions();\n';
        for (FSL.StatusTransition s : l){
            output = output + 'FSL.GlobalAPIS.addStatusTransition(\'' + s.FromStatus + '\', \'' + s.toStatus + '\');\n';
        }

        ContentVersion conVer = new ContentVersion(
            ContentLocation = 'S',
            PathOnClient = 'backupOfSAStatusTransitions' + System.now().format() + '.apex',
            Title = 'Backup of Field Service Service Appointment Status Transitions ' + System.now().format(),
            VersionData = Blob.valueOf(output)
        );
        insert conVer;              
    }

    /*
     * Deletes all Scheduling Policy records and optionally
     * all Work Rules and/or Service Objective records
     */
    public static void deleteAllSchedulingPolicies(Boolean deleteWorkRules, Boolean deleteServiceObjectives){
        List<SObject> objToDel = new List<SObject>();
        objToDel.addAll([select Id from FSL__Scheduling_Policy__c]);
        if (deleteWorkRules){
            objToDel.addAll([select Id from FSL__Work_Rule__c where Name not in ('Earliest Start Permitted', 'Due Date')]);
        }
        if (deleteServiceObjectives){
            objToDel.addAll([select Id from FSL__Service_Goal__c]);
        }        
        delete objToDel;
    }

    /*
     * Creates a backup of the current Scheduling Policies including
     * Work Rules, Service Objectives and the relationship between 
     * the policies and ruled and objectives
     * It saves the backup in a single file which consist of separated 
     * JSON strings
     */           
    public static void backupSchedulingPoliciesFull(){
        String fileContent = '';
        fileContent += backupSchedulingPolicies() + fileSeparator;
        fileContent += backupWorkRules() + fileSeparator;
        fileContent += backupServiceObjectives() + fileSeparator;
        fileContent += backupSchedulingPolicyWorkRules() + fileSeparator;
        fileContent += backupSchedulingPolicyServiceObjectives() + fileSeparator;

        ContentVersion conVer = new ContentVersion(
            ContentLocation = 'S',
            PathOnClient = 'backupOfSchedulingPolicies' + System.now().format() + '.json',
            Title = 'Backup of Field Service Scheduling Policies ' + System.now().format(),
            VersionData = Blob.valueOf(fileContent)
        );  
        insert conVer;      
    }

    /*
     * Creates a backup of the current Scheduling Policy records
     * Returns a JSON string
     */
    private static String backupSchedulingPolicies(){
        String query = sfsUtil.getAllFieldsQuery('FSL__Scheduling_Policy__c');
        List<FSL__Scheduling_Policy__c> policies = Database.query(query);
        return JSON.serialize(policies);
    }

    /*
     * Creates a backup of the current Work Rule records
     * Uses a custom class format so the record type developername 
     * is included to support cross org backup/restore
     * Returns a JSON string
     */    
    private static String backupWorkRules(){
        String query = sfsUtil.getAllFieldsQuery(
            'FSL__Work_Rule__c', 
            new List<String>{'RecordType.DeveloperName'}
        );
        List<FSL__Work_Rule__c> records = Database.query(query);
        List<String> fields = sfsUtil.getObjectNameAndCustomFields('FSL__Work_Rule__c');
        List<sfsSeedDataUtil.workRule> workRules = new List<sfsSeedDataUtil.workRule>();
        for (FSL__Work_Rule__c record : records){
            FSL__Work_Rule__c wr = new FSL__Work_Rule__c();    
            for (String field : fields){
                wr.put(field, record.get(field));
            }
            workRules.add(
                new sfsSeedDataUtil.workRule(record.RecordType.DeveloperName,wr)
            );
        }
        return JSON.serialize(workRules);
    }

    /*
     * Creates a backup of the current Service Objective records
     * Uses a custom class format so the record type developername 
     * is included to support cross org backup/restore
     * Returns a JSON string
     */        
    private static String backupServiceObjectives(){
        String query = sfsUtil.getAllFieldsQuery(
            'FSL__Service_Goal__c', 
            new List<String>{'RecordType.DeveloperName'}
        );
        List<FSL__Service_Goal__c> records = Database.query(query);
        List<String> fields = sfsUtil.getObjectNameAndCustomFields('FSL__Service_Goal__c');
        List<sfsSeedDataUtil.objective> objectives = new List<sfsSeedDataUtil.objective>();
        for (FSL__Service_Goal__c record : records){
            FSL__Service_Goal__c objective = new FSL__Service_Goal__c();    
            for (String field : fields){
                objective.put(field, record.get(field));
            }
            objectives.add(
                new sfsSeedDataUtil.objective(record.RecordType.DeveloperName, objective)
            );
        }
        return JSON.serialize(objectives);
    }

    /*
     * Creates a backup of the current Scheduling Policy Work Rule records
     * Uses a custom class format to support cross org backup/restore
     * Returns a JSON string
     */        
    private static String backupSchedulingPolicyWorkRules(){
        String query = sfsUtil.getAllFieldsQuery(
            'FSL__Scheduling_Policy_Work_Rule__c', 
            new List<String>{
                'FSL__Scheduling_Policy__r.Name',
                'FSL__Work_Rule__r.Name'
            },
            'FSL__Work_Rule__r.Name NOT IN (\'Earliest Start Permitted\', \'Due Date\')'
        );
        List<FSL__Scheduling_Policy_Work_Rule__c> records = Database.query(query);
        List<sfsSeedDataUtil.policyWorkRule> policyRules = new List<sfsSeedDataUtil.policyWorkRule>();
        for (FSL__Scheduling_Policy_Work_Rule__c record : records){
            policyRules.add(
                new sfsSeedDataUtil.policyWorkRule(
                    record.FSL__Scheduling_Policy__r.Name,
                    record.FSL__Work_Rule__r.Name
                )
            );
        }

        return JSON.serialize(policyRules);
    }   
    
    /*
     * Creates a backup of the current Scheduling Policy Service Objective records
     * Uses a custom class format to support cross org backup/restore
     * Returns a JSON string
     */    
    public static String backupSchedulingPolicyServiceObjectives(){
        String query = sfsUtil.getAllFieldsQuery(
            'FSL__Scheduling_Policy_Goal__c', 
            new List<String>{
                'FSL__Scheduling_Policy__r.Name',
                'FSL__Service_Goal__r.Name'
            }
        );
        List<FSL__Scheduling_Policy_Goal__c> records = Database.query(query);
        List<sfsSeedDataUtil.policyObjective> policyObjectives = new List<sfsSeedDataUtil.policyObjective>();
        for (FSL__Scheduling_Policy_Goal__c record : records){
            policyObjectives.add(
                new sfsSeedDataUtil.policyObjective(
                    record.FSL__Scheduling_Policy__r.Name,
                    record.FSL__Service_Goal__r.Name,
                    record.FSL__Weight__c
                )
            );
        }        
        return JSON.serialize(policyObjectives);
    }     

    /*
     * Restores the full scheduling policy records including
     * work rules and service objectives and the relationships
     * between them based on a backup file created with the method
     * backupSchedulingPoliciesFull
     * Takes a ContentDocumentId as input, and a boolean to validate if 
     * the restore would work. If true, it throws a custom exception
     */    
    public static void restoreSchedulingPoliciesFull(Id fileId, Boolean isValidation){
        Blob file = [select VersionData from ContentVersion where ContentDocumentId = :fileId order by lastmodifieddate desc limit 1].VersionData;
        String fileContent = file.toString();
        List<String> fileParts = fileContent.split(fileSeparatorRegExpr);
        List<FSL__Scheduling_Policy__c> policies = restoreSchedulingPolicies(fileParts[0]);
        List<FSL__Work_Rule__c> workrules = restoreWorkRules(fileParts[1]);
        List<FSL__Service_Goal__c> objectives = restoreServiceObjectives(fileParts[2]);
        List<sfsSeedDataUtil.policyWorkRule> policyRules = restoreSchedulingPolicyWorkRules(fileParts[3]);
        List<sfsSeedDataUtil.policyObjective> policyObjectives = restoreSchedulingPolicyObjectives(fileParts[4]);

        insert workrules;
        insert objectives;
        insert policies;

        Map<String, SObject> nameToPolicy = sfsUtil.convertObjectListToMap((List<SObject>)policies, 'Name');
        Map<String, SObject> nameToRule = sfsUtil.convertObjectListToMap((List<SObject>)workrules, 'Name');
        Map<String, SObject> nameToObjective = sfsUtil.convertObjectListToMap((List<SObject>)objectives, 'Name');

        List<FSL__Scheduling_Policy_Work_Rule__c> restoredPolicyRules = new List<FSL__Scheduling_Policy_Work_Rule__c>();
        for (sfsSeedDataUtil.policyWorkRule policyRule : policyRules){
            restoredPolicyRules.add(
                new FSL__Scheduling_Policy_Work_Rule__c(
                    FSL__Scheduling_Policy__c = (Id)nameToPolicy.get(policyRule.policyName).get('Id'),
                    FSL__Work_Rule__c = (Id)nameToRule.get(policyRule.ruleName).get('Id')
                )
            );
        }
        insert restoredPolicyRules;

        List<FSL__Scheduling_Policy_Goal__c> restoredPolicyObjectives = new List<FSL__Scheduling_Policy_Goal__c>();
        for (sfsSeedDataUtil.policyObjective policyObjective : policyObjectives){
            restoredPolicyObjectives.add(
                new FSL__Scheduling_Policy_Goal__c(
                    FSL__Scheduling_Policy__c = (Id)nameToPolicy.get(policyObjective.policyName).get('Id'),
                    FSL__Service_Goal__c = (Id)nameToObjective.get(policyObjective.objectiveName).get('Id'),
                    FSL__Weight__c = policyObjective.weight
                )
            );
        }
        insert restoredPolicyObjectives;  
        
        if (isValidation){
            throw new sfsSeedDataUtil.sfsException('Validation: Restore successfull but NOT committed to the database');
        }

    }

    public static void restoreSchedulingPoliciesFull(Id fileId){
        restoreSchedulingPoliciesFull(fileId, false);
    }

    /*
     * Restores Scheduling Policy records from 
     * a backup JSON string
     */    
    private static List<FSL__Scheduling_Policy__c> restoreSchedulingPolicies(String fileContent){
        List<FSL__Scheduling_Policy__c> policies = (List<FSL__Scheduling_Policy__c>)JSON.deserialize(fileContent, List<FSL__Scheduling_Policy__c>.class);
        List<FSL__Scheduling_Policy__c> restoredPolicies = sfsUtil.cloneRecords((List<SObject>)policies, null, null);
        return restoredPolicies;
    }

    /*
     * Restores Work Rule records from 
     * a backup JSON string and sets the
     * RecordTypeId accordingly
     */     
    private static List<FSL__Work_Rule__c> restoreWorkRules(String fileContent){
        List<sfsSeedDataUtil.workRule> workrules = (List<sfsSeedDataUtil.workRule>)JSON.deserialize(fileContent, List<sfsSeedDataUtil.workRule>.class);
        List<FSL__Work_Rule__c> restoredWorkRules = new List<FSL__Work_Rule__c>();
        List<FSL__Work_Rule__c> existingWorkRules = [select Name from FSL__Work_Rule__c where Name in ('Earliest Start Permitted', 'Due Date') and RecordType.DeveloperName = 'Time_Rule_Service'];
        Set<String> fixedTimeWorkRules = new Set<String>();
        if (!existingWorkRules.isEmpty()){
            fixedTimeWorkRules = sfsUtil.convertObjectListToMap((existingWorkRules), 'Name').keySet();  
        } 
        Schema.DescribeSObjectResult objDesc = Schema.SObjectType.FSL__Work_Rule__c;
        Map<String,Schema.RecordTypeInfo> rtMapByName = objDesc.getRecordTypeInfosByDeveloperName();
        for (sfsSeedDataUtil.workRule workrule : workrules){
            if (!fixedTimeWorkRules.isEmpty() && (fixedTimeWorkRules.contains('Earliest Start Permitted') && 
                workrule.workRule.Name == 'Earliest Start Permitted') || (fixedTimeWorkRules.contains('Due Date') && 
                workrule.workRule.Name == 'Due Date'))
            {
                    continue;
            }
            FSL__Work_Rule__c restoredWorkRule = workrule.workRule;
            System.debug(workrule.recordTypeDeveloperName);
            restoredWorkRule.RecordTypeId = rtMapByName.get(workrule.recordTypeDeveloperName).getRecordTypeId();
            restoredWorkRules.add(restoredWorkRule);
        }
        return restoredWorkRules;
    }    

    /*
     * Restores Service Objective records from 
     * a backup JSON string and sets the
     * RecordTypeId accordingly
     */    
    private static List<FSL__Service_Goal__c> restoreServiceObjectives(String fileContent){
        List<sfsSeedDataUtil.objective> objectives = (List<sfsSeedDataUtil.objective>)JSON.deserialize(fileContent, List<sfsSeedDataUtil.objective>.class);
        List<FSL__Service_Goal__c> restoredObjectives = new List<FSL__Service_Goal__c>();
        Schema.DescribeSObjectResult objDesc = Schema.SObjectType.FSL__Service_Goal__c;
        Map<String,Schema.RecordTypeInfo> rtMapByName = objDesc.getRecordTypeInfosByDeveloperName();
        for (sfsSeedDataUtil.objective objective : objectives){
            FSL__Service_Goal__c restoredObjective = objective.objective;
            restoredObjective.RecordTypeId = rtMapByName.get(objective.recordTypeDeveloperName).getRecordTypeId();
            restoredObjectives.add(restoredObjective);
        }        
        return restoredObjectives;
    }     

    /*
     * Restores Scheduling Policy Work Rules from 
     * a backup JSON string
     */    
    private static List<sfsSeedDataUtil.policyWorkRule> restoreSchedulingPolicyWorkRules(String fileContent){
        List<sfsSeedDataUtil.policyWorkRule> restoredPolicyRules = (List<sfsSeedDataUtil.policyWorkRule>)JSON.deserialize(fileContent, List<sfsSeedDataUtil.policyWorkRule>.class);
        return restoredPolicyRules;
    } 

    /*
     * Restores Scheduling Policy Service Objectives from 
     * a backup JSON string
     */     
    private static List<sfsSeedDataUtil.policyObjective> restoreSchedulingPolicyObjectives(String fileContent){
        List<sfsSeedDataUtil.policyObjective> restoredPolicyObjectives = (List<sfsSeedDataUtil.policyObjective>)JSON.deserialize(fileContent, List<sfsSeedDataUtil.policyObjective>.class);
        return restoredPolicyObjectives;
    }

    /*
     * Custom structure to backup and restore Work Rules
     * to be able to restore the correct RecordTypeId
     */
    public class workRule{
        String recordTypeDeveloperName;
        FSL__Work_Rule__c workRule;

        public workRule(String recordTypeDeveloperName, FSL__Work_Rule__c workRule){
            this.recordTypeDeveloperName = recordTypeDeveloperName;
            this.workRule = workRule;
        }
    }

    /*
     * Custom structure to backup and restore Service Objectives
     * to be able to restore the correct RecordTypeId
     */

    public class objective{
        String recordTypeDeveloperName;
        FSL__Service_Goal__c objective;

        public objective(String recordTypeDeveloperName, FSL__Service_Goal__c objective){
            this.recordTypeDeveloperName = recordTypeDeveloperName;
            this.objective = objective;
        }
    }    

    /*
     * Custom structure to backup and restore Scheduling Policy Work Rules
     * to be able to recreate the relationship
     */
    public class policyWorkRule{
        String policyName;
        String ruleName;

        policyWorkRule(String policyName, String ruleName){
            this.policyName = policyName;
            this.ruleName = ruleName;
        }
    }

    /*
     * Custom structure to backup and restore Scheduling Policy Service Objectives
     * to be able to recreate the relationship with the weigth
     */    
    public class policyObjective{
        String policyName;
        String objectiveName;
        Decimal weight;

        policyObjective(String policyName, String objectiveName, Decimal weight){
            this.policyName = policyName;
            this.objectiveName = objectiveName;
            this.weight = weight;
        }
    }    

    public class sfsException extends Exception{}

}