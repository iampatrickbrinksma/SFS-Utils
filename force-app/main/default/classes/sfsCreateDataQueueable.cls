public with sharing class sfsCreateDataQueueable implements Queueable, Database.AllowsCallouts {
    
    private Integer nrOfTechsPerServiceTerritory;
    private Id templateUserId;
    private String technicianUserProfileName;
    private String userEmail;
    private String userLastName;
    private String userNamePrefix;
    private String userNameSuffix;
    private Map<String, List<Decimal>> serviceTerritoryNameToCenterLocation;    
    private String operatingHoursName;
    private Integer radiusOfTerritoryMembersInMeters;
    private Integer nrOfWorkOrderRecords;
    private Integer radiusOfWorkOrderInMeters;
    private String workOrderSubject;
    private Integer minimumAppointmentDuration = 30;
    private Integer maximumAppointmentDuration = 90;   
    private String priorityFieldApiName; 

    public String operationStep = 'CreateTechnicianUsers';
    public Integer stNumber = 0;

    public sfsCreateDataQueueable(
        Integer nrOfTechsPerServiceTerritory,
        Id templateUserId,
        String technicianUserProfileName,
        String userEmail,
        String userLastName,
        String userNamePrefix,
        String userNameSuffix,
        Map<String, List<Decimal>> serviceTerritoryNameToCenterLocation,    
        String operatingHoursName,
        Integer radiusOfTerritoryMembersInMeters,
        Integer nrOfWorkOrderRecords,
        Integer radiusOfWorkOrderInMeters,
        String workOrderSubject,
        Integer minimumAppointmentDuration,
        Integer maximumAppointmentDuration,
        String priorityFieldApiName
    ) {
        this.nrOfTechsPerServiceTerritory= nrOfTechsPerServiceTerritory;
        this.templateUserId = templateUserId;
        this.technicianUserProfileName = technicianUserProfileName;
        this.userEmail = userEmail;
        this.userLastName = userLastName;
        this.userNamePrefix = userNamePrefix;
        this.userNameSuffix = userNameSuffix;
        this.serviceTerritoryNameToCenterLocation = serviceTerritoryNameToCenterLocation;    
        this.operatingHoursName = operatingHoursName;
        this.radiusOfTerritoryMembersInMeters = radiusOfTerritoryMembersInMeters;
        this.nrOfWorkOrderRecords = nrOfWorkOrderRecords;
        this.radiusOfWorkOrderInMeters = radiusOfWorkOrderInMeters;
        this.workOrderSubject = workOrderSubject;
        this.minimumAppointmentDuration = minimumAppointmentDuration;
        this.maximumAppointmentDuration = maximumAppointmentDuration;
        this.priorityFieldApiName = priorityFieldApiName;
    }

    public void execute(QueueableContext ctx){
        String stName = new List<String>(serviceTerritoryNameToCenterLocation.keySet())[stNumber];
        switch on operationStep {
            when 'CreateTechnicianUsers' {
                List<User> techUsers = sfsCreateDataUtil.createTechnicianUsers(
                    templateUserId, 
                    nrOfTechsPerServiceTerritory, 
                    technicianUserProfileName, 
                    userEmail, 
                    stName, 
                    userLastName, 
                    userNamePrefix, 
                    userNameSuffix
                );
                sfsCreateDataUtil.assignPermSetsToTechnicianUsers(techUsers);  
            }            
            when 'CreateServiceTerritoryAndMembers' {
                List<Decimal> coordinates = serviceTerritoryNameToCenterLocation.get(stName);
                System.Location stCenter = System.Location.newInstance(coordinates[0], coordinates[1]);
                String searchString = userNamePrefix + stName + '%' + userNameSuffix;
                List<User> techUsers = [select Id, FirstName, LastName from User where UserName LIKE :searchString];
                sfsCreateDataUtil.createServiceTerritoryWithMembers(
                    stName, 
                    true, 
                    operatingHoursName, 
                    stCenter, 
                    radiusOfTerritoryMembersInMeters, 
                    techUsers, 
                    System.now().addDays(-10), 
                    null
                );
            }
            when 'CreateWorkOrdersAndServiceAppointments' {
                List<WorkOrder> wos = sfsCreateDataUtil.createWorkOrdersAndServiceAppointments(
                    [select Id from ServiceTerritory where Name = :stName].Id,
                    radiusOfWorkOrderInMeters,
                    nrOfWorkOrderRecords,
                    null,
                    workOrderSubject,
                    System.now().addDays(-1),
                    System.now().addDays(180),
                    minimumAppointmentDuration,
                    maximumAppointmentDuration,
                    priorityFieldApiName
                );
            }
        }
        doNextStep();
    }

    private void doNextStep(){
        if (operationStep == 'CreateTechnicianUsers'){
            operationStep = 'CreateServiceTerritoryAndMembers';
        } else if (operationStep == 'CreateServiceTerritoryAndMembers') {
            operationStep = 'CreateWorkOrdersAndServiceAppointments';
        } else if (operationStep == 'CreateWorkOrdersAndServiceAppointments'){
            operationStep = 'CreateTechnicianUsers';
            stNumber++;
        }

        if (stNumber <= serviceTerritoryNameToCenterLocation.size() - 1){
            sfsCreateDataQueueable q = new sfsCreateDataQueueable(
                nrOfTechsPerServiceTerritory,
                templateUserId,
                technicianUserProfileName,
                userEmail,
                userLastName,
                userNamePrefix,
                userNameSuffix,
                serviceTerritoryNameToCenterLocation,    
                operatingHoursName,
                radiusOfTerritoryMembersInMeters,
                nrOfWorkOrderRecords,
                radiusOfWorkOrderInMeters,
                workOrderSubject,
                minimumAppointmentDuration,
                maximumAppointmentDuration,
                priorityFieldApiName
            );
            q.operationStep = operationStep;
            q.stNumber = stNumber;
            System.enqueueJob(q);
        }        
    }

}