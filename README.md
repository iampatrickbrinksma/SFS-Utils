# Salesforce Field Service Utils

A collection of useful code snippets to use in your Salesforce Field Service implementation and projects

# What's Included?

## Polygon Utils
The class sfsPolygonUtil provides the following methods:
* getServiceTerritoryByGeolocation - returns a Service Territory record based on a geolocation (latitude / longitude)
* getServiceTerritoriesByGeolocation - returns a list of Service Territory records based on a geolocation (latitude / longitude) (Support from Summer '23 onwards)
* getMapPolygonsByServiceTerritoryId - returns a list of Map Polygon records to which the Service Territory is mapped to
* getMapPolygonsByServiceTerritoryIds - returns a map of Service Territory Id to the list of Map Polygon records it is mapped to

## Seed Data Utils
The class sfsSeedDataUtil provides the following methods:
* resetServiceAppointmentStatusTransitions - resets the Service Appointment status transitions to the default ones provided that the default status values exist
* backupServiceAppointmentStatusTransitions - creates a backup file for the current Service Appointment status transitions and saves it as a File (ContentDocument) in an anonymous Apex code block so you can restore the status transitions by running it as anonymous Apex
* deleteAllSchedulingPolicies - deletes all the Scheduling Policy records and optionally all Work Rule and/or Service Objective records. Exception: The Work Rule records "Earliest Start Permitted" and "Due Date" cannot be deleted
* backupSchedulingPoliciesFull - creates a backup file for all Scheduling Policy, Work Rules, Service Objective records and the relationship between them and saves it as a File (ContentDocument)
* restoreSchedulingPoliciesFull - restores all Scheduling Policy, Work Rules, Service Objective records from the file created with the backupSchedulingPoliciesFull method

## Create Data Util
The class sfsCreateUtil provides the following methods:
* createTechnicianUsers - creates users to be used as Service Resources (Technicians)
* assignPermSetsToTechnicianUsers - assigns the permission sets Field Service Resource Permissions and Field Service Resource License to the users
* assignPermSetsToUsers - assigns a list of permission sets to a list of users
* createServiceTerritoryWithMembers - creates a service territory, service resources and associates these resources to the territory as service territory members based on a geolocaiton and provided radius in meters
* createWorkOrdersAndServiceAppointments - creates work orders and service appoontments based on a geolocation and provided radius in meters and a random duration based on the provided minimum and maximum length
