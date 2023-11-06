# Salesforce Field Service Utils #

A collection of useful code snippets to use in your Salesforce Field Service implementation and projects

# What's Included? #
* Polygon Utils
* Seed Data Utils
* Create Data Utils
* Scheduling Utils
* Appointment Bundling Utils
* Custom Gantt Action for Optimization

## Polygon Utils ##
The Apex class sfsPolygonUtil provides the following methods:
* getServiceTerritoryByGeolocation - returns a Service Territory record based on a geolocation (latitude / longitude)
* getServiceTerritoriesByGeolocation - returns a list of Service Territory records based on a geolocation (latitude / longitude) (Support from Summer '23 onwards)
* getMapPolygonsByServiceTerritoryId - returns a list of Map Polygon records to which the Service Territory is mapped to
* getMapPolygonsByServiceTerritoryIds - returns a map of Service Territory Id to the list of Map Polygon records it is mapped to

## Seed Data Utils ##
The Apex class sfsSeedDataUtil provides the following methods:
* resetServiceAppointmentStatusTransitions - resets the Service Appointment status transitions to the default ones provided that the default status values exist
* backupServiceAppointmentStatusTransitions - creates a backup file for the current Service Appointment status transitions and saves it as a File (ContentDocument) in an anonymous Apex code block so you can restore the status transitions by running it as anonymous Apex
* deleteAllSchedulingPolicies - deletes all the Scheduling Policy records and optionally all Work Rule and/or Service Objective records. Exception: The Work Rule records "Earliest Start Permitted" and "Due Date" cannot be deleted
* backupSchedulingPoliciesFull - creates a backup file for all Scheduling Policy, Work Rules, Service Objective records and the relationship between them and saves it as a File (ContentDocument)
* restoreSchedulingPoliciesFull - restores all Scheduling Policy, Work Rules, Service Objective records from the file created with the backupSchedulingPoliciesFull method

## Create Data Utils ##
The Apex class sfsCreateUtil provides the following methods:
* createTechnicianUsers - creates users to be used as Service Resources (Technicians)
* assignPermSetsToTechnicianUsers - assigns the permission sets Field Service Resource Permissions and Field Service Resource License to the users
* assignPermSetsToUsers - assigns a list of permission sets to a list of users
* createServiceTerritoryWithMembers - creates a service territory, service resources and associates these resources to the territory as service territory members based on a geolocaiton and provided radius in meters
* createWorkOrdersAndServiceAppointments - creates work orders and service appoontments based on a geolocation and provided radius in meters and a random duration based on the provided minimum and maximum length

## Scheduling Utils ##
The class sfsSchedulingUtil provides an abstract layer on top of the methods that retrieve available time slots and schedule appointments as described [here](https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_namespace_FSL.htm). 

How to use:

### Get arrival windows based on candidates ###
This method first retrieves available time slots for candidates and then validates the slots against arrival windows, so you are able to filter on resources with custom logic, and the returned slots provide the grade per resource. You can sort by Grade (grade) and Start Time (starttime) of the slot.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where Name = 'SA-1001'].Id;
Id operatingHoursId = [select Id from OperatingHours where Name = 'Gold Appointments Calendar'].Id;
List<sfsTimeSlot> slots = sfsSchedulingUtil.getCandidateSlotsWithArrivalWindow(schedulingPolicyId, serviceAppointmentId, operatingHoursId, 'grade');
```

### Get candidates ###
This method first retrieves available time slots for candidates as the global action "Candidates", using the FSL.GradeSlotsServicegetGradedMatrix method. You can sort by Grade (grade) and Start Time (starttime) of the slot.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where Name = 'SA-1001'].Id;
List<sfsTimeSlot> slots = sfsSchedulingUtil.getGradedMatrixSlots(schedulingPolicyId, serviceAppointmentId, 'grade');
```

### Get book appointment slots ###
This method retrieves the available slots represented as arrival window slots during which the resource will arrive on site as the global action "Book Appointment" using the FSL.AppointmentBookingService.getSlots method. You can sort by Grade (grade) and Start Time (starttime) of the slot.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
ServiceAppointment sa = [select Id, ServiceTerritory.OperatingHours.TimeZone from ServiceAppointment where Name = 'SA-1001'].Id;
Id serviceAppointmentId = sa.Id;
TimeZone serviceTerritoryTimeZone = TimeZone.getTimeZone(sa.ServiceTerritory.OperatingHours.TimeZone);
Id operatingHoursId = [select Id from OperatingHours where Name = 'Gold Appointments Calendar'].Id;
List<sfsTimeSlot> slots = sfsSchedulingUtil.getAppointmentBookingSlots(serviceAppointmentId, Id schedulingPolicyId, Id operatingHoursId, TimeZone serviceTerritoryTimeZone, Boolean exactAppointments, 'grade');
```

### Schedule Appointment ###
This method schedule an appointment using the FSL.ScheduleService.schedule method.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where Name = 'SA-1001'].Id;
FSL.ScheduleResult scheduleResult = sfsSchedulingUtil.scheduleAppointment(serviceAppointmentId, schedulingPolicyId);
```

### Schedule Complex Work ###
This method schedule appointments that related to each other via complex work using the FSL.ScheduleService.scheduleExtended method. Use this method only when ES&O is enabled, as it assumes it runs synchronously.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where Name = 'SA-1001'].Id;
List<FSL.ScheduleResult> scheduleResults = sfsSchedulingUtil.scheduleAppointmentChain(serviceAppointmentId, schedulingPolicyId);
```

## Appointment Bundling Utils ## 
The class sfsAppointmentBundlingAPI provides an abstract layer on top of the [Field Service Appointment Bundling REST APIs](https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/fsl_rest_sabundling.htm). 

> Please review and be aware of the API limitations as described in the help documentation

How to use:

**Automatic Bundling**
```
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.AUTOMATIC_BUNDLING);
sfsAppointmentBundlingAPI.automaticBundlingResponse res = (sfsAppointmentBundlingAPI.automaticBundlingResponse)bApi.run();
```

**Create a bundle**
```
Id bundlePolicyId = [select Id from ApptBundlePolicy where Name = '<Appointment Bundling Policy Name>'].Id;
List<Id> saIds = new List<Id>{'08p060000003FeHAAU','08p060000003FeIAAU','08p060000003FeJAAU','08p060000003FeKAAU'};
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.BUNDLE, bundlePolicyId, saIds);  
sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();
```
        
**Remove bundle members**
```
List<Id> saIds = new List<Id>{'08p060000003FgCAAU','08p060000003FeAAAU'};
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.REMOVE_BUNDLE_MEMBERS, saIds);
sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();
```

**Unbundle single bundle**
```
Id bundleId = '08p060000003KipAAE';
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.UNBUNDLE, bundleId);
sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();
```

**Unbundling multiple bundles**
```
// Unbundling multiple bundles
List<Id> saIds = new List<Id>{'08p060000003KkPAAU','08p060000003KkKAAU','08p060000003KkFAAU'};
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.UNBUNDLE_MULTIPLE, saIds);
sfsAppointmentBundlingAPI.multipleUnbundleResponse res = (sfsAppointmentBundlingAPI.multipleUnbundleResponse)bApi.run();
List<sfsAppointmentBundlingAPI.multipleUnbundleResponsePayload> innerRes = bApi.getMultipleUnbundleResponsePayloadList(res);
```

**Update existing bundle (add members)**
```
Id bundleId = '08p060000003KipAAE';
List<Id> saIds = new List<Id>{'08p060000003FgCAAU','08p060000003FeAAAU'};
sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.UPDATE_BUNDLE, bundleId, saIds);
sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();
```

> Review the class and help documentation to understand the structure of the response 

## Start Optimization once Automatic Bundling is complete ##
Automatic bundling can be scheduled or started on demand using the REST API (see Appointment Bundling Utils). In some scenarios it would be great if optimization would start automatically once automatic bundling is completed. The following components are included to make this possible:
* Apex Class: sfsAppointmentBundlingAPI - provides a way to start automatic bundling on demand
* Apex Class: sfsOptimizationRequestUtil - processes updated Optimization Request records and validates if automatic bundling has completed and queues optimization
* Apex Class sfsOptimizationRequestUtilQueueable - Queueable class to request optimization to start
* Apex Trigger: OptimizationRequestTrigger - Detect updates on the Optimization Request object
* Custom Setting: Automatic Bundling Config - Settings for automatic bundling and starting optimization

## Prepare and Create Appointment Bundles Util ##
If automatic bundling doesn't entirely fit your scenario, and you want more control over the bundling process, the Apex class sfsCreateBundleUtil can prepare bundles based on a provided set of service appointment records and a bundling policy. With the bundles prepared (in memory) the Apex class sfsOptimizationRequestUtilQueueable can be used to actually create the bundles (using the Apex class sfsAppointmentBundlingAPI) and optionally start optimization once all bundles have been created.

Example code snippet to run the entire process:
```
// Bundle policy to use
String bundlePolicyName = 'Appointment Bundle Policy CDO';

// Set a max nr of bundle creations per queueable, so there is less chance of running into governor limits
Integer maxBundlesPerQueueable = 20;

// Service Territory for filtering appointments
Id serviceTerritoryId = [select Id from ServiceTerritory where Name = 'Madrid'].Id;

// Retrieve appointments to bundle, make sure the DurationInMinites field is included
// and additionally the fields listed in the Appointment Bundling Restriction Policies related
// to the Appointment Bundling Polciy, in this case: City, PostalCode and Street
List<ServiceAppointment> sas = [
    select 
        Id, City, PostalCode, Street, DurationInMinutes
    from 
        ServiceAppointment 
    where 
        ServiceTerritoryId = :serviceTerritoryId and
        IsBundle = false and
        IsBundleMember = false and
        Apartment__c != null and 
        Floor__c != null
    order by 
        City ASC, 
        PostalCode ASC, 
        Street ASC, 
        Floor__c ASC, 
        Apartment__c ASC
    limit 20
];  

// Prepare the bundles by grouping them
Map<Integer, List<Id>> bundles = sfsCreateBundleUtil.prepareBundles(sas, bundlePolicyName);

// Get bundle policy Id
Id bundlePolicyId = [select Id from ApptBundlePolicy where Name = :bundlePolicyName].Id;

// Details for optimization that is initiated after bundles are created
String schedulingPolicyName = 'Customer First';
Date optHorizonStartDate = System.today().addDays(1);
Integer optHorizonLengthInDays = 28;
Boolean optAllTasksMode = false;
String filterByFieldApiName = 'Include_In_Optimization__c';

// Start creating bundles
sfsCreateBundleQueueable q = new sfsCreateBundleQueueable(
    bundles, 
    bundlePolicyId, 
    maxBundlesPerQueueable,
    [select Id from FSL__Scheduling_Policy__c where Name = :schedulingPolicyName].Id,
    new List<Id>{serviceTerritoryId},
    optHorizonStartDate,
    optHorizonLengthInDays,
    optAllTasksMode,
    filterByFieldApiName
);
System.enqueueJob(q);
```
## Custom Gantt Action for Optimization ##
A custom gantt action for optimization to be used in the Dispatcher Console, which includes the following components:
* Aura App: sfsCustomGanttActionOptimizeApp
* Custom Permission: Custom Gantt Action - Optimize
* Custom Setting: sfsCustomGanttActionOptimizeSettings__c
* Apex Class: sfsCustomGanttActionOptimize
* Custom Labels to support translations
* Lightning Web Components: sfsCustomGanttActionOptimize *ldsUtil and errorPanel are included which originate from the LWC-Recipes)
* Visualforce Page: sfsCustomGanttActionOptimize

How to use:
### Deploy ###
1. Deploy the metadata
2. Provide the right permissions

### Create Custom Gantt Action ###
1. Navigate to the Field Service Settings (tab) -> Dispatcher Console UI -> Custom Actions
2. Add a new Custom Action in the "Mass Actions" section
3. Give it a name
4. Select "Visualforce" as Action Type
5. Select the "sfsCustomGanttActionOptimize" Visualforce Page
6. Select the "Custom Gantt Action - Optimize" custom permission as Required Custom Permission
7. Select an icon
8. Hit Save

Reload the Dispatcher Console, and the custom action can be used.
Example screenshot:
![image](https://github.com/iampatrickbrinksma/SFS-Utils/assets/78381570/73188f1d-ac3e-4fa8-992e-ae44c17d0ebc)

### Configuration ###
You can configure the behavior of this custom gantt action by populating the Custom Setting "Custom Gantt Action Optimize Settings":
* If you populate the field "Default Scheduling Policy" with a policy name, the user cannot select another policy, and this policy will be used for optimization
* If you check the "Disable All Task Mode" field, the All Task Mode selection (All or Unscheduled) will default to All, and cannot be changed
* If you populate the "Filter By Field API Name" field with the API name of a checkbox field on the Service Appointment object, only records with this field checked will be optimized. A message will be displayed in the custom gantt action


  
