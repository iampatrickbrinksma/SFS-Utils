# Salesforce Field Service Utils #

A collection of useful code snippets to use in your Salesforce Field Service implementation and projects

## Disclaimer
This repository contains code intended to help Salesforce Field Service customers and partners accelerate their implementations. Please note the following:
* This code is not an official Salesforce product.
* It is not officially supported by Salesforce.
* The code serves as an example of how to implement specific functionality or make use of certain features.

Before using this code in a production environment, it is crucial that you:
* Adopt the code to fit your specific needs.
* Test thoroughly to ensure it works as expected in your environment.
* Consider the code to be your own and take full responsibility for its use.

By using this code, you acknowledge that Salesforce is not liable for any issues that may arise from its use.

# What's Included? #
* Polygon Utils
* Seed Data Utils
* Create Data Utils
* Scheduling Utils
* Invocable methods for appointment booking and scheduling
* Appointment Bundling Utils
* Start Optimization once Automatic Bundling is complete
* Prepare and Create Appointment Bundles Util
* Embed Standard Field Service Global Actions in Flow
* Custom Gantt Action for Optimization
* Create Service Documents via REST API (Document Builder)

## Polygon Utils ##
The Apex class `sfsPolygonUtil` provides the following methods:
* `getServiceTerritoryByGeolocation` - returns a Service Territory record based on a geolocation (latitude / longitude)
* `getServiceTerritoriesByGeolocation` - returns a list of Service Territory records based on a geolocation (latitude / longitude) (Support from Summer '23 onwards)
* `getMapPolygonsByServiceTerritoryId` - returns a list of Map Polygon records to which the Service Territory is mapped to
* `getMapPolygonsByServiceTerritoryIds` - returns a map of Service Territory Id to the list of Map Polygon records it is mapped to

## Seed Data Utils ##
The Apex class `sfsSeedDataUtil` provides the following methods:
* `resetServiceAppointmentStatusTransitions` - resets the Service Appointment status transitions to the default ones provided that the default status values exist
* `backupServiceAppointmentStatusTransitions` - creates a backup file for the current Service Appointment status transitions and saves it as a File (ContentDocument) in an anonymous Apex code block so you can restore the status transitions by running it as anonymous Apex
* `deleteAllSchedulingPolicies` - deletes all the Scheduling Policy records and optionally all Work Rule and/or Service Objective records. Exception: The Work Rule records "Earliest Start Permitted" and "Due Date" cannot be deleted
* `backupSchedulingPoliciesFull` - creates a backup file for all Scheduling Policy, Work Rules, Service Objective records and the relationship between them and saves it as a File (ContentDocument)
* `restoreSchedulingPoliciesFull` - restores all Scheduling Policy, Work Rules, Service Objective records from the file created with the backupSchedulingPoliciesFull method

## Create Data Utils ##
The Apex class `sfsCreateUtil` provides the following methods:
* `createTechnicianUsers` - creates users to be used as Service Resources (Technicians)
* `assignPermSetsToTechnicianUsers` - assigns the permission sets Field Service Resource Permissions and Field Service Resource License to the users
* `assignPermSetsToUsers` - assigns a list of permission sets to a list of users
* `createServiceTerritoryWithMembers` - creates a service territory, service resources and associates these resources to the territory as service territory members based on a geolocaiton and provided radius in meters
* `createWorkOrdersAndServiceAppointments` - creates work orders and service appoontments based on a geolocation and provided radius in meters and a random duration based on the provided minimum and maximum length

The Apex class `sfsCreateDataQueueable` can be used to create more data in bulk chaining queueable jobs to avoid governor limits. Below is an example of how to use this queueable to create technician users, assign the permission sets, create service territory and member records and create work orders and service appointments for set of service territories at once:

```
Integer nrOfTechsPerServiceTerritory = 10;
Id templateUserId = <Id of the user to use as a template to copy settings like language, timezone, etc.>;
String technicianUserProfileName = <Profile Name>;
String userEmail = <User email address>;
String userLastName = 'Technician';
String userNamePrefix = 'ftech';
String userNameSuffix = <Part of the user name after the @>;
Integer radiusOfTerritoryMembersInMeters = <Radius in meters to randomly generate a homebase location for each technician>;
String operatingHoursName = <Name of the Operating Hours for availability>;
Integer nrOfWorkOrderRecords = <Number of Work Order and Service Appointment records to be created>;
Integer radiusOfWorkOrderInMeters = <Radius in meters to generate random locations for the jobs>;
String workOrderSubject = 'Work Order';
Integer minimumAppointmentDuration = 30;
Integer maximumAppointmentDuration = 90;
String priorityFieldApiName = <API name of custom numeric field on Work Order to store random priority between 1 and 10>;

// Map of Service Territory Names with their center location
Map<String, List<Decimal>> serviceTerritoryNameToCenterLocation = new Map<String, List<Decimal>>{
    'Alicante' => new List<Decimal>{38.37649843319099, -0.5066871658079017},
    'Barcelona' => new List<Decimal>{41.38684963640192, 2.163876087816992},
    'Madrid' => new List<Decimal>{40.424916, -3.687685},
    'Murcia' => new List<Decimal>{37.976295486020014, -1.1347487979345818},
    'Sevilla' => new List<Decimal>{37.382504519503016, -5.973121653944733},
    'Valencia' => new List<Decimal>{39.496293960005936, -0.39766904694446614}
};

// Initiate queueable
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
    null
);
q.operationStep = 'CreateTechnicianUsers';
q.stNumber = 0;
System.enqueueJob(q);
```

## Scheduling Utils ##
The class sfsScheduling provides an abstract layer on top of the methods that retrieve available time slots and schedule appointments as described [here](https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/apex_namespace_FSL.htm). 

How to use:

### Get arrival windows based on candidates ###
This method first retrieves available time slots for candidates and then validates the slots against arrival windows, so you are able to filter on resources with custom logic, and the returned slots provide the grade per resource. You can sort by Grade (grade) and Start Time (starttime) of the slot.

**IMPORTANT**: Because the ```getGradedMatrix``` method of the ```FSL.GradeSlotsService Apex``` class does return all possible slots, some possible arrival windows might be missing from the resulting slots. For example, if a candidate doesn't have anything scheduled for a day, for that day typically 2 slots are returned. One for the start of the day, and one for after the break (if that is used). 

```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
Id operatingHoursId = [select Id from OperatingHours where Name = 'Gold Appointments Calendar'].Id;
Boolean exactAppointments = false;
String sortBy = 'grade';
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId,
    exactAppointments,
    sortBy
);
List<sfsTimeSlot> slots = scheduling.getCandidateSlotsWithArrivalWindow();
```

### Get candidates ###
This method first retrieves available time slots for candidates as the global action "Candidates", using the FSL.GradeSlotsServicegetGradedMatrix method. You can sort by Grade (grade) and Start Time (starttime) of the slot.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
String sortBy = 'grade';
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId,
    sortBy
);
List<sfsTimeSlot> slots = sfsSchedulingUtil.getGradedMatrixSlots();
```

The method ```getGradedMatrixSlotsWithResourceName``` adds the service resource name to the output, which might be useful when displaying this information to users.

### Get book appointment slots ###
This method retrieves the available slots represented as arrival window slots during which the resource will arrive on site as the global action "Book Appointment" using the FSL.AppointmentBookingService.getSlots method. You can sort by Grade (grade) and Start Time (starttime) of the slot.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
Id operatingHoursId = [select Id from OperatingHours where Name = 'Gold Appointments Calendar'].Id;
Boolean exactAppointments = false;
String sortBy = 'grade';
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId,
    exactAppointments,
    sortBy
);
List<sfsTimeSlot> slots = scheduling.getAppointmentBookingSlots();
```

### Schedule Appointment ###
This method schedule an appointment using the FSL.ScheduleService.schedule method.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId
);
FSL.ScheduleResult scheduleResult = scheduling.scheduleAppointment();
```

### Schedule Complex Work ###
This method schedule appointments that related to each other via complex work using the FSL.ScheduleService.scheduleExtended method. Use this method only when ES&O is enabled, as it assumes it runs synchronously.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId
);
List<FSL.ScheduleResult> scheduleResults = scheduling.scheduleAppointmentChain();
```

### Get Appointment Insights ###
This method gets information why a service appointment cannot be scheduled using the FSl.ScheduleService.getAppointmentInsights method.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-0397'].Id;
sfsScheduling scheduling = new sfsScheduling(
    serviceAppointmentId, 
    schedulingPolicyId
);
sfsScheduling.sfsAppointmentInsights insights = scheduling.getAppointmentInsights();
```

## Invocable methods for appointment booking, candidates, scheduling and appointment insights ##
These invocable methods can be used for example in Flow, or to define an Agent Action for Agentforce agents.

### Get book appointment slots (Invocable) ###
This method allows retrieving slots as an invocable method, so it can be used in Flows, but also to create an Agentforce action.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
Id operatingHoursId = [select Id from OperatingHours where Name = 'Gold Appointments Calendar'].Id;
Boolean exactAppointments = false;
String sortBy = 'grade';
sfsGetSlotsInvocable.Inputs inputs = new sfsGetSlotsInvocable.Inputs();
inputs.schedulingPolicyId = schedulingPolicyId;
inputs.serviceAppointmentId = serviceAppointmentId;
inputs.operatingHoursId = operatingHoursId;
inputs.exactAppointments = exactAppointments;
inputs.sortBy = sortBy;
List<sfsGetSlotsInvocable.Outputs> outputs = sfsGetSlotsInvocable.getAppointmentBookingSlots(new List<sfsGetSlotsInvocable.Inputs>{inputs});
```
Optionally, if the ```originalArrivalWindowStart``` and ```originalArrivalWindowEnd``` input properties are provided, the method updates the service appointment arrival window with these values.

### Get Candidates (Invocable) ###
This method allows retrieving candidates an invocable method, so it can be used in Flows, but also to create an Agentforce action.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
String sortBy = 'grade';
sfsGetCandidatesInvocable.Inputs inputs = new sfsGetCandidatesInvocable.Inputs();
inputs.schedulingPolicyId = schedulingPolicyId;
inputs.serviceAppointmentId = serviceAppointmentId;
inputs.sortBy = sortBy;
List<sfsGetCandidatesInvocable.Outputs> outputs = sfsGetCandidatesInvocable.getCandidates(new List<sfsGetCandidatesInvocable.Inputs>{inputs});
```
Optionally, if the ```originalArrivalWindowStart``` and ```originalArrivalWindowEnd``` input properties are provided, the method updates the service appointment arrival window with these values.

### Schedule Appointment (Invocable) ###
This method allows scheduling an appointment as an invocable method, so it can be used in Flows, but also to create an Agentforce action.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-1001'].Id;
sfsScheduleInvocable.Inputs inputs = new sfsScheduleInvocable.Inputs();
inputs.schedulingPolicyId = schedulingPolicyId;
inputs.serviceAppointmentId = serviceAppointmentId;
List<sfsScheduleInvocable.Outputs> outputs = sfsScheduleInvocable.getCandidates(new List<sfsScheduleInvocable.Inputs>{inputs});
```

### Appointment Insights (Invocable) ###
This method gets appointment insights for a service appointment as an invocable method, so it can be used in Flows, but also to create an Agentforce action.
```
Id schedulingPolicyId = [select Id from FSL__Scheduling_Policy__c where Name = 'Customer First'].Id;
Id serviceAppointmentId = [select Id from ServiceAppointment where AppointmentNumber = 'SA-0397'].Id;
sfsAppointmentInsightsInvocable.Inputs inputs = new sfsAppointmentInsightsInvocable.Inputs();
inputs.schedulingPolicyId = schedulingPolicyId;
inputs.serviceAppointmentId = serviceAppointmentId;
List<sfsAppointmentInsightsInvocable.Outputs> outputs = sfsAppointmentInsightsInvocable.getAppointmentInsights(new List<sfsAppointmentInsightsInvocable.Inputs>{inputs});
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
    order by 
        City ASC, 
        PostalCode ASC, 
        Street ASC, 
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

## Embed Standard Field Service Global Actions in Flow ##
Embedding the standard Field Service Global Actions - Appointment Booking, Candidates and Emergency - in a screen flow provides a way to guide users through the process of creating the right data set in order to schedule an appointment. To embed these actions in a screen flow a Lightning Web Component is provided which loads the appropriate action into an iframe. The following components are included:
* Lightning Web Component: sfsActionInFlow
* Flow: Field_Service_Action_Embedded
* Quick Action: ServiceAppointment.Field_Service_Global_Action

Deploy these components, activate the Flow and add the Quick Action to the appropriate Service Appointment Page Layout. 

## Custom Gantt Action for Optimization ##
A custom gantt action for optimization to be used in the Dispatcher Console, which includes the following components:
* Aura App: sfsCustomGanttActionOptimizeApp
* Custom Permission: Custom Gantt Action - Optimize
* Custom Setting: sfsCustomGanttActionOptimizeSettings__c
* Apex Class: sfsCustomGanttActionOptimize
* Custom Labels to support translations
* Lightning Web Components: sfsCustomGanttActionOptimize *ldsUtil and errorPanel are included which originate from the LWC-Recipes)
* Visualforce Page: sfsCustomGanttActionOptimize

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
* If you populate the "Filter By Fields API Names" field with a comma-separated list of the API name of checkbox fields on the Service Appointment object, the user can select the checkbox field which will be used for filtering. If the "Filter By Field API Name" field is populated, this field is ignored

## Service Document Utils ##
The Apex class sfsServiceDocumentUtil provides the following methods:
* createDocumentAsync - Create service document async (future) via REST API
* createDocument - Create service document sync via REST API

How to use:
```
Id pdfReportId = sfsServiceDocumentUtil.createDocument(
    '0WOWy000000956vOAA',   // Record Id for the record from which the service document is generated. Needs to match the object the template.
    '0M0QJ000000Orxd0AC',   // Id of the service document template
    'Updated now 2',        // Optional: Value will be set as Label in the Service Report record
    'en_US',                // Optional: Language for the report. 
    null                    // Optional: Id of the PDF report
));
```
Important: To have the Service Document generated in the correct language, set the "Service Report Language" picklist field to the right value on the record. The API values in this picklist are the values that are supported to provide in the ```locale``` attribute!
  
