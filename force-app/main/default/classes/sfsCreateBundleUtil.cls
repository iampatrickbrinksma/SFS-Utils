/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class to prepare bundles for creation. This class doesn't create the bundles itself but 
* prepares the bundles for creation using the provided bundling policy
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsCreateBundleUtil {

    // Prepare bundles by using the Bundling Policy to "group" appointments together
    // Make sure the Appointment Bundling Restriction Policy fields are included in the 
    // appointments passed into this method
    public static Map<Integer, List<Id>> prepareBundles(List<ServiceAppointment> sas, String bundlePolicyName){
        // Return Map
        Map<Integer, List<Id>> bundles = new Map<Integer, List<Id>>();

        // Get Appointment Bundle Policy details
        ApptBundlePolicy bundlePolicy = getBundlePolicy(bundlePolicyName);
    
        // Read bundle limits from bundle policy        
        Integer maxBundleDuration = bundlePolicy.LimitDurationOfBundle;
        Integer maxBundleMembers = bundlePolicy.LimitAmountOfBundleMembers;

        // Default values
        Integer bundleKey = 0;
        Integer bundleDuration = 0;
        Integer bundleMembers = 0;
        String prevAddressKey = '';

        // Determine the appointment bundling restriction policies used so
        // the key can be constructed to compare appointments
        List<String> restrictByFieldApiNames = getFieldsFromRestrictionPolicies(bundlePolicy);

        // Loop through sorted list of appointments and prepare bundles
        for (ServiceAppointment sa : sas){
            // build comparison key based on restriction fields
            String addressKey = '';
            for (String fieldApiName : restrictByFieldApiNames){
                addressKey += (String)sa.get(fieldApiName);
            }
            
            // Appointment Duration, used to limit bundle
            Integer saDuration = Integer.valueOf(sa.DurationInMinutes);

            // Compare record to previous and determine
            // if record is added to existing bundle or
            // create new bundle
            if (addressKey == prevAddressKey && 
                (bundleMembers <= maxBundleMembers && bundleDuration + saDuration <= maxBundleDuration))
            {
                List<Id> saIds = bundles.get(bundleKey);
                if (saIds == null) saIds = new List<Id>();
                saIds.add(sa.Id);
                bundles.put(bundleKey, saIds);
                bundleDuration += saDuration;    
                bundleMembers++;
            } else {
                bundleKey++;
                bundles.put(bundleKey, new List<Id>{sa.Id});    
                bundleDuration = saDuration;
                bundleMembers = 1;
            }
            prevAddressKey = addressKey;
        }
        return bundles;
    }

    // Retrieve Appointment Bundle Policy information
    // including the restriction policies for manual bundling
    private static ApptBundlePolicy getBundlePolicy(String bundlePolicyName){
        return [
            select 
                Id,
                LimitDurationOfBundle,
                LimitAmountOfBundleMembers,
                (
                    select 
                        Id,
                        RestrictionFieldName
                    from 
                        ApptBundleRestrictPolicies
                    where 
                        DoesRestrictManualMode = true
                )
            from 
                ApptBundlePolicy 
            where 
                Name = :bundlePolicyName and
                IsManualBundling = true
        ];
    }    

    // Get all Field API Names from the restriction policies
    private static List<String> getFieldsFromRestrictionPolicies(ApptBundlePolicy bundlePolicy){
        List<String> restrictByFieldApiNames = new List<String>();
        for (ApptBundleRestrictPolicy bundleRestrictPolicy : bundlePolicy.ApptBundleRestrictPolicies){
            String fieldApiName = bundleRestrictPolicy.RestrictionFieldName;
            fieldApiName = fieldApiName.removeStart('ServiceAppointment.');
            restrictByFieldApiNames.add(fieldApiName);
        }
        return restrictByFieldApiNames;
    }

}