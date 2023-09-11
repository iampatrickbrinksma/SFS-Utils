/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class which can be used in Apex Test Classes which require the appointment status transitions
* to be configured to reflect the real configuration
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
@isTest
public with sharing class sfsTestUtil {

    public static void setupServiceAppointmentStatusTransitions(){
        // To be sure, clear all statuses
        // Up to Spring '19, a set of default status transitions were available
        // In Summer '19 release no default transitions were available
        FSL.GlobalAPIS.ClearAllStatusTransitions();
 
        // The status transitions defined
        // This Map needs to be maintained if:
        // 1) transitions are added, changed or removed
        // 2) Status values are changed
        Map<Integer, Map<String, String>> mapOfStatusTransitions = new Map<Integer, Map<String, String>>{
            1 => new Map<String, String>{'None' => 'Canceled'},
            2 => new Map<String, String>{'None' => 'Scheduled'},
            4 => new Map<String, String>{'Scheduled' => 'None'},
            4 => new Map<String, String>{'Scheduled' => 'Dispatched'},
            5 => new Map<String, String>{'Scheduled' => 'Canceled'},
            6 => new Map<String, String>{'Dispatched' => 'Canceled'},
            7 => new Map<String, String>{'Dispatched' => 'In Progress'},
            8 => new Map<String, String>{'In Progress' => 'Completed'},
            9 => new Map<String, String>{'In Progress' => 'Cannot Complete'}
        };
 
        // Add status transitions
        for (Map<String, String> statusTransition : mapOfStatusTransitions.values()) {
            for (String statusFrom : statusTransition.keySet()){
                FSL.GlobalAPIS.addStatusTransition(new FSL.StatusTransition(statusFrom, statusTransition.get(statusFrom)));
            }
        }
    }
 

}