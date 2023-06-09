public with sharing class sfsCreateUtil {

    public static List<User> createTechnicianUsers(Id templateUserId, Integer nrOfUsers, String profileName, String userEmail,
                                            String firstName, String lastName, String userNamePrefix, String userNameSuffix)
    {
        Id profileId = [select Id from Profile where Name = :profileName].Id;
        User templateUser = [
            SELECT
                Id,
                EmailEncodingKey,
                LanguageLocaleKey,
                LocaleSidKey,
                TimeZoneSidKey
            FROM 
                User 
            WHERE 
                Id = :templateUserId
        ];

        List<User> techUsers = new List<User>();
        for (Integer i=1; i<=nrOfUsers; i++){
            techUsers.add(
                new User(
                    ProfileId = profileId,
                    FirstName = firstName,
                    LastName = lastName + String.valueOf(i).leftPad(String.valueOf(nrOfUsers).length(), '0'), 
                    UserName = userNamePrefix + i + System.now().getTime() + '@' + userNameSuffix,
                    Email = userEmail,
                    EmailEncodingKey = templateUser.EmailEncodingKey,
                    LanguageLocaleKey = templateUser.LanguageLocaleKey,
                    LocaleSidKey = templateUser.LocaleSidKey,
                    TimeZoneSidKey = templateUser.TimeZoneSidKey,
                    UserPermissionsSupportUser = true
                )
            );
        }
        insert techUsers;
        return techUsers;
    }

    public static void assignPermSetsToTechnicianUsers(List<User> users){
        assignPermSetsToUsers(users, new List<String>{'FSL_Resource_License', 'FSL_Resource_Permissions'});
    }

    public static void assignPermSetsToUsers(List<User> users, List<String> permSetNames){
        List<PermissionSet> permSets = [select Id from PermissionSet where Name = :permSetNames];
        List<PermissionSetAssignment> permSetsAssigns = new List<PermissionSetAssignment>();
        for (User user : users){
            for (PermissionSet permSet : permSets){
                permSetsAssigns.add(
                    new PermissionSetAssignment(
                        AssigneeId = user.Id,
                        PermissionSetId = permSet.Id
                    )
                );
            }
        }
        insert permSetsAssigns;    
    }

    public static void createServiceTerritoryWithMembers(String stName, Boolean useESO, String stOperatingHours,
                                                        Location stCenter, Double radiusInMeters,
                                                        List<User> techUsers, Datetime startDate, Datetime endDate)
    {
        ServiceTerritory st = new ServiceTerritory(
            Name = stName,
            isActive = true,
            OperatingHoursId = [select Id from OperatingHours where Name = :stOperatingHours].Id,
            FSL__O2_Enabled__c = useESO,
            Latitude = stCenter.getLatitude(),
            Longitude = stCenter.getLongitude()
        );
        insert st;  
        
        List<ServiceResource> srs = new List<ServiceResource>();
        for (User techUser : techUsers){
            srs.add(
                new ServiceResource(
                    IsActive = true,
                    IsOptimizationCapable = true,
                    Name = techUser.FirstName + ' ' + techUser.LastName,
                    RelatedRecordId = techUser.Id,
                    ResourceType = 'T'
                )
            );
        }
        insert srs;   
        
        List<ServiceTerritoryMember> stms = new List<ServiceTerritoryMember>();
        for (ServiceResource sr : srs){
            Location homeBase = sfsUtil.getRandomPointInCircle(stCenter, radiusInMeters);
            stms.add(
                new ServiceTerritoryMember(
                    ServiceTerritoryId = st.Id,
                    ServiceResourceId = sr.Id,
                    TerritoryType = 'P',
                    EffectiveStartDate = startDate,
                    EffectiveEndDate = endDate,
                    Latitude = homeBase.getLatitude(),
                    Longitude = homeBase.getLongitude()                       
                )
            );
        }
        insert stms;          
    }

    public static List<WorkOrder> createWorkOrdersAndServiceAppointments(Id stId, Double radiusInMeters, Integer nrOfRecords, 
                                                                        Id workTypeId, String woSubject, Datetime esp, Datetime dd,
                                                                        Integer minDuration, Integer maxDuration)
    {
        ServiceTerritory st = [
            SELECT
                Id,
                Name,
                Latitude,
                Longitude
            FROM 
                ServiceTerritory 
            WHERE 
                Id = :stId
        ];

        Location stCenter = Location.newInstance(Double.valueOf(st.latitude), Double.valueOf(st.longitude));

        List<Location> woLocations = new List<Location>();
        for (Integer i = 0; i < nrOfRecords; i++) {
            woLocations.add(
                sfsUtil.getRandomPointInCircle(stCenter, radiusInMeters)
            );
        }

        List<WorkOrder> wos = new List<WorkOrder>();
        for (Integer i=0; i<nrOfRecords; i++) {
            wos.add(
                new WorkOrder(
                    ServiceTerritoryId = stId,    
                    WorkTypeId = workTypeId,
                    Subject = woSubject + ' ' + String.valueOf(i).leftPad(String.valueOf(nrOfRecords).length(), '0'),
                    StartDate = esp,
                    EndDate = dd
                )
            );
        }
        insert wos;  
        
        Boolean createSAs = false;
        if (workTypeId != null){
            createSAs = [
                SELECT 
                    ShouldAutoCreateSvcAppt
                FROM 
                    WorkType 
                WHERE 
                    Id = :workTypeId
            ].ShouldAutoCreateSvcAppt;
        }

        if (createSAs){
            List<ServiceAppointment> sas = new List<ServiceAppointment>();
            for (Integer i=0; i<nrOfRecords; i++) {
                sas.add(
                    new ServiceAppointment(
                        ServiceTerritoryId = stId,
                        ParentRecordId = wos[i].Id,
                        Latitude = wos[i].Latitude,
                        Longitude = wos[i].Longitude,
                        EarliestStartTime = esp,
                        DueDate = dd,
                        Duration = sfsUtil.getRandomInteger(minDuration, maxDuration),
                        DurationType = 'Minutes'
                    )
                );
            }
            insert sas;           
        }

        return wos;
        
    }

}