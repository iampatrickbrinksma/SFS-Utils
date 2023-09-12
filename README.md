# Salesforce Field Service Utils

A collection of useful code snippets to use in your Salesforce Field Service implementation and projects

# What's Included?

## Polygon Utils
The Apex class sfsPolygonUtil provides the following methods:
** getServiceTerritoryByGeolocation - returns a Service Territory record based on a geolocation (latitude / longitude)
** getServiceTerritoriesByGeolocation - returns a list of Service Territory records based on a geolocation (latitude / longitude) (Support from Summer '23 onwards)
** getMapPolygonsByServiceTerritoryId - returns a list of Map Polygon records to which the Service Territory is mapped to
** getMapPolygonsByServiceTerritoryIds - returns a map of Service Territory Id to the list of Map Polygon records it is mapped to

## Seed Data Utils
The Apex class sfsSeedDataUtil provides the following methods:
** resetServiceAppointmentStatusTransitions - resets the Service Appointment status transitions to the default ones provided that the default status values exist
** backupServiceAppointmentStatusTransitions - creates a backup file for the current Service Appointment status transitions and saves it as a File (ContentDocument) in an anonymous Apex code block so you can restore the status transitions by running it as anonymous Apex
** deleteAllSchedulingPolicies - deletes all the Scheduling Policy records and optionally all Work Rule and/or Service Objective records. Exception: The Work Rule records "Earliest Start Permitted" and "Due Date" cannot be deleted
** backupSchedulingPoliciesFull - creates a backup file for all Scheduling Policy, Work Rules, Service Objective records and the relationship between them and saves it as a File (ContentDocument)
** restoreSchedulingPoliciesFull - restores all Scheduling Policy, Work Rules, Service Objective records from the file created with the backupSchedulingPoliciesFull method

## Create Data Util
The Apex class sfsCreateUtil provides the following methods:
** createTechnicianUsers - creates users to be used as Service Resources (Technicians)
** assignPermSetsToTechnicianUsers - assigns the permission sets Field Service Resource Permissions and Field Service Resource License to the users
** assignPermSetsToUsers - assigns a list of permission sets to a list of users
** createServiceTerritoryWithMembers - creates a service territory, service resources and associates these resources to the territory as service territory members based on a geolocaiton and provided radius in meters
** createWorkOrdersAndServiceAppointments - creates work orders and service appoontments based on a geolocation and provided radius in meters and a random duration based on the provided minimum and maximum length

## Appointment Bundling Utils
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

## Start Optimization once Automatic Bundling is complete
Automatic bundling can be scheduled or started on demand using the REST API (see Appointment Bundling Utils). In some scenarios it would be great if optimization would start automatically once automatic bundling is completed. The following components are included to make this possible:
* Apex Class: sfsAppointmentBundlingAPI - provides a way to start automatic bundling on demand
* Apex Class: sfsOptimizationRequestUtil - processes updated Optimization Request records and validates if automatic bundling has completed and queues optimization
* Apex Class sfsOptimizationRequestUtilQueueable - Queueable class to request optimization to start
* Apex Trigger: OptimizationRequestTrigger - Detect updates on the Optimization Request object
* Custom Setting: Automatic Bundling Config - Settings for automatic bundling and starting optimization

## Prepare and Create Appointment Bundles Util
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