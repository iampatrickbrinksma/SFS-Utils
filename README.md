# Salesforce Field Service Utils

A collection of useful code snippets to use in your Salesforce Field Service implementation and projects

# What's Included?

## Clone Scheduling Policy
The ability to clone a scheduling policy including the association to work rules and service objectives with their weight value.

### Components
* Apex Class: sfsSchedulingPolicyUtil
* LWC: sfsCloneSchedulingPolicy
* QuickAction: FSL__Scheduling_Policy__c.Clone_Scheduling_Policy

### How To Use
* Deploy the components
* Add the Quick Action to the Mobile & Lightning Actions section of the Scheduling Policy page layout
* Open the detail page of the scheduling policy you want to clone
* Hit the "Clone Scheduling Policy"

## Polygon Utils
A number of Apex class methods to provide the ability to:
* Determine which service territory a geolocation belongs to
* Determine which service territories a geolocation belongs to in case of overlapping territories
* Determine which map polygons are associated to a service territory

### Components
The class sfsPolygonUtil provides the following methods:
* getServiceTerritoryByGeolocation - returns a Service Territory record based on a geolocation (latitude / longitude)
* getServiceTerritoriesByGeolocation - returns a list of Service Territory records based on a geolocation (latitude / longitude) (Support from Summer '23 onwards)
* getMapPolygonsByServiceTerritoryId - returns a list of Map Polygon records to which the Service Territory is mapped to
* getMapPolygonsByServiceTerritoryIds - returns a map of Service Territory Id to the list of Map Polygon records it is mapped to

## Seed Data Utils
A number of Apex class methods to provide the ability to:
* Reset the Service Appointment Status Transitions to the default values
* Create a backup of the current Service Appointment Status Transitions, which can be used to restore these transitions
* Delete all scheduling policies and optionally work rules and/or service objectives
* Create a backup of all scheduling policies, work rules and service objectives and their relationships
* Restore a backup of all scheduling policies, work rules and service objectives and their relationships
  * A backup file of the standard scheduling policies, work rules and service objectives are provided in config/files/Backup of Field Service Standard Scheduling Policies.json which can be used to restore the default ones.

### Components
The class sfsSeedDataUtil provides the following methods:
* resetServiceAppointmentStatusTransitions - resets the Service Appointment status transitions to the default ones provided that the default status values exist
* backupServiceAppointmentStatusTransitions - creates a backup file for the current Service Appointment status transitions and saves it as a File (ContentDocument) in an anonymous Apex code block so you can restore the status transitions by running it as anonymous Apex
* deleteAllSchedulingPolicies - deletes all the Scheduling Policy records and optionally all Work Rule and/or Service Objective records. Exception: The Work Rule records "Earliest Start Permitted" and "Due Date" cannot be deleted
* backupSchedulingPoliciesFull - creates a backup file for all Scheduling Policy, Work Rules, Service Objective records and the relationship between them and saves it as a File (ContentDocument)
* restoreSchedulingPoliciesFull - restores all Scheduling Policy, Work Rules, Service Objective records from the file created with the backupSchedulingPoliciesFull method

## Create Data Util
A number of Apex class methods to provide the ability to:
* Create a number of users based on a template users 
* Assign the Field Service permission sets to a technician user
* Assign a list of permission sets to a list of users
* Create a service territory, service resources from a list of users and associate these service resources with the service territory as members. Location of the territory and its members are based on a provided geolocation and radius in meters
* Create work orders and service appointments with a random duration. Location of the work orders and service appointments are based on a provided geolocation and radius in meters

### Components
The class sfsCreateUtil provides the following methods:
* createTechnicianUsers - creates users to be used as Service Resources (Technicians)
* assignPermSetsToTechnicianUsers - assigns the permission sets Field Service Resource Permissions and Field Service Resource License to the users
* assignPermSetsToUsers - assigns a list of permission sets to a list of users
* createServiceTerritoryWithMembers - creates a service territory, service resources and associates these resources to the territory as service territory members based on a geolocaiton and provided radius in meters
* createWorkOrdersAndServiceAppointments - creates work orders and service appoontments based on a geolocation and provided radius in meters and a random duration based on the provided minimum and maximum length
