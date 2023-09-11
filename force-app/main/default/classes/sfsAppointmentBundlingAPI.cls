/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Class to easily call the Salesforce Field Service Appointment Bundling REST APIs
* See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/fsl_rest_sabundling.htm
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsAppointmentBundlingAPI {

    /*
        How to use:

        // Automatic Bundling
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.AUTOMATIC_BUNDLING);
        sfsAppointmentBundlingAPI.automaticBundlingResponse res = (sfsAppointmentBundlingAPI.automaticBundlingResponse)bApi.run();

        // Create a bundle
        Id bundlePolicyId = [select Id from ApptBundlePolicy where Name = '<Appointment Bundling Policy Name>'].Id;
        List<Id> saIds = new List<Id>{'08p060000003FeHAAU','08p060000003FeIAAU','08p060000003FeJAAU','08p060000003FeKAAU'};
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.BUNDLE, bundlePolicyId, saIds);  
        sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();     
        
        // Remove bundle members
        List<Id> saIds = new List<Id>{'08p060000003FgCAAU','08p060000003FeAAAU'};
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.REMOVE_BUNDLE_MEMBERS, saIds);
        sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();

        // Unbundle single bundle
        Id bundleId = '08p060000003KipAAE';
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.UNBUNDLE, bundleId);
        sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();        

        // Unbundling multiple bundles
        List<Id> saIds = new List<Id>{'08p060000003KkPAAU','08p060000003KkKAAU','08p060000003KkFAAU'};
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.BundlingAction.UNBUNDLE_MULTIPLE, saIds);
        sfsAppointmentBundlingAPI.multipleUnbundleResponse res = (sfsAppointmentBundlingAPI.multipleUnbundleResponse)bApi.run();

        // Update existing bundle (add members)
        Id bundleId = '08p060000003KipAAE';
        List<Id> saIds = new List<Id>{'08p060000003FgCAAU','08p060000003FeAAAU'};
        sfsAppointmentBundlingAPI bApi = new sfsAppointmentBundlingAPI(sfsAppointmentBundlingAPI.bundlingAction.UPDATE_BUNDLE, bundleId, saIds);
        sfsAppointmentBundlingAPI.bundleResponse res = (sfsAppointmentBundlingAPI.bundleResponse)bApi.run();

    */

    /**
     *  Generic settings for the Appointment Bundling REST API
     *  See https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/fsl_rest_sabundling.htm
     */

    // API version
    private final String API_VERSION = '58.0';

    // API endpoint
    private final String BUNDLE_HOST = FSL.BundleLogic.getBundlerFalconEnvironment();
    private final String API_BUNDLING_ENDPOINT = BUNDLE_HOST + '/bundleflow/api/v1.0/';

    // HTTP Timeout
    private final Integer HTTP_TIMEOUT = 20000;

    // API endpoint suffix based on the action performed
    private final String API_AUTOMATIC_BUNDLE_SUFFIX = 'startbatch';
    private final String API_BUNDLE_SUFFIX = 'bundle';
    private final String API_UNBUNDLE_SUFFIX = '?initiate=manual';
    private final String API_UNBUNDLE_MULTIPLE_SUFFIX = 'unbundleMultiple';
    private final String API_REMOVE_BUNDLE_MEMBER_SUFFIX = 'bundle/remove';
    private final String API_UPDATE_BUNDLE_SUFFIX = 'bundle/';    

    // Referer to the org performing the request
    private final String BUNDLE_REFERER = URL.getOrgDomainUrl().toExternalForm();    

    /**
     * Expose Actions accepted by this class
     */
    public enum BundlingAction {
        AUTOMATIC_BUNDLING,                 // For automatic bundling
        BUNDLE,                             // Create a bundle
        REMOVE_BUNDLE_MEMBERS,              // Remove bundle members from existing bundle
        UNBUNDLE,                           // Unbundle single bundle
        UNBUNDLE_MULTIPLE,                  // Unbundle multiple bundles
        UPDATE_BUNDLE                       // Update existing bundle (add members)
    }

    /**
     * Local vars
     */
    private BundlingAction bundlingAction;
    private Id bundleId;
    private Id bundlePolicyId;
    private List<Id> serviceAppointmentIds;

    /**
     * Constructors
     */

    // For automatic bundling
    public sfsAppointmentBundlingAPI(BundlingAction bundlingAction) {
        this.bundlingAction = bundlingAction;
    }

    // For bundling and updating existing bundle
    public sfsAppointmentBundlingAPI(BundlingAction bundlingAction, Id bundleIdOrPolicyId, List<Id> serviceAppointmentIds) {
        this.bundlingAction = bundlingAction;
        switch on this.bundlingAction {
            when BUNDLE {
                this.bundlePolicyId = bundleIdOrPolicyId;
            }
            when UPDATE_BUNDLE {
                this.bundleId = bundleIdOrPolicyId;
            }
        }
        this.serviceAppointmentIds = serviceAppointmentIds;
    }    

    // For remove bundle members, unbundling multiple bundles
    public sfsAppointmentBundlingAPI(BundlingAction bundlingAction, List<Id> serviceAppointmentIds) {
        this.bundlingAction = bundlingAction;
        this.serviceAppointmentIds = serviceAppointmentIds;
    }

    // For unbundling single bundle
    public sfsAppointmentBundlingAPI(BundlingAction bundlingAction, Id bundleId) {
        this.bundlingAction = bundlingAction;
        this.bundleId = bundleId;
    }    

    /**
     * One method to just run the action defined in the constructor
     */
    public Object run(){
        // Create HTTP request
        HttpRequest request = createHTTPRequest();

        // Set request body
        String bodyJSON = generateRequestBody();
        if (bodyJSON != null) request.setBody(bodyJSON);

        // Send request
        HttpResponse response = new Http().send(request);        
        
        // Handle a redirect message
        while (response.getStatusCode() == 302) {
            request.setEndpoint(response.getHeader('Location'));
            response = new Http().send(request);
        }       
        
        // Debug response
        System.debug('Response status: ' + response.toString());
        System.debug('Response body:\n\n\n' + response.getBody());

        // Process response
        if (response.getStatusCode() != 200) {
            throw new AppointmentBundlingException(
                'An error occurred during the appointment bundling operation: ' + bundlingAction.name() + '. Details: ' + 
                response.getStatusCode() + ' ' + response.getStatus() + '. Body: ' + response.getBody()
            );                        
        }

        // Process response JSON and return an object
        return processResponse(response.getBody());

    }

    /**
     * Construct the correct endpoint based on the action and optionally an appointment Id
     */
    private String constructEndpoint(){
        String suffix;

        switch on bundlingAction {
            when AUTOMATIC_BUNDLING {
                suffix = API_AUTOMATIC_BUNDLE_SUFFIX;
            }
            when BUNDLE {
                suffix = API_BUNDLE_SUFFIX;
            }
            when REMOVE_BUNDLE_MEMBERS {
                suffix = API_REMOVE_BUNDLE_MEMBER_SUFFIX;
            }
            when UNBUNDLE {
                suffix = API_BUNDLE_SUFFIX + '/' + bundleId + API_UNBUNDLE_SUFFIX;
            }
            when UNBUNDLE_MULTIPLE {
                suffix = API_UNBUNDLE_MULTIPLE_SUFFIX;
            }
            when UPDATE_BUNDLE {
                suffix = API_UPDATE_BUNDLE_SUFFIX + '/' + bundleId;
            }            
        }
        // System.debug('Bundling Api Endpoint: ' + API_BUNDLING_ENDPOINT + suffix);
        return API_BUNDLING_ENDPOINT + suffix;
    }    

    /**
     * Determine HTTP method based on the action
     */
    private String getHTTPMethod(){
        String httpMethod;
        switch on bundlingAction {
            when AUTOMATIC_BUNDLING, BUNDLE, UNBUNDLE_MULTIPLE {
                httpMethod = 'POST';
            }
            when UNBUNDLE {
                httpMethod = 'DELETE';
            }
            when REMOVE_BUNDLE_MEMBERS, UPDATE_BUNDLE {
                httpMethod = 'PATCH';
            }
        }
        return httpMethod;        
    }

    /**
     * Create HTTP Request object
     */
    private HTTPRequest createHTTPRequest(){
        HttpRequest request = new HttpRequest();
        request.setEndpoint(constructEndpoint());
        request.setMethod(getHTTPMethod());
        request.setHeader('sf_api_version', API_VERSION);
        request.setHeader('Content-Type', 'application/json' );
        // NOTE: This user must have 'Field Service Integration' permission set assigned!
        // which is the running user in this example
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId()); 
        request.setHeader('Referer', BUNDLE_REFERER);
        request.setTimeout(HTTP_TIMEOUT);
        return request;
    }    

    /**
     * Generate the JSON request body
     */
    private String generateRequestBody(){
        Map<String, Object> bodyMap;
        String bodyJSON;

        switch on bundlingAction {
            when AUTOMATIC_BUNDLING {
                bodyMap = new Map<String, Object>();
                bodyMap.put('operation','start-batch-processing');                
            }
            when BUNDLE, UPDATE_BUNDLE {
                bodyMap = new Map<String, Object>();
                bodyMap.put('initiate', 'manual');
                bodyMap.put('bundlePolicyId', bundlePolicyId);
                // Add all appointments to the body that need to be bundled
                List<Object> objectsList =  new List<Object>();
                for (Id saId : serviceAppointmentIds){
                    Map<String, Object> saList = new Map<String, Object>(); 
                    saList.put('serviceAppointmentId', saId);
                    saList.put('action', 'add');
                    objectsList.add(saList);
                }
                bodyMap.put('saRequestPayloads', objectsList);                
            }
            when REMOVE_BUNDLE_MEMBERS {
                bodyMap = new Map<String, Object>();
                bodyMap.put('initiate', 'manual');
                // Add all appointments to the body that need to be bundled
                List<Object> objectsList =  new List<Object>();
                for (Id saId : serviceAppointmentIds){
                    Map<String, Object> saList = new Map<String, Object>(); 
                    saList.put('serviceAppointmentId', saId);
                    saList.put('action', 'remove');
                    objectsList.add(saList);
                }
                bodyMap.put('saRequestPayloads', objectsList);                
            }
            when UNBUNDLE {
                // No body is set
            }
            when UNBUNDLE_MULTIPLE {
                bodyMap = new Map<String, Object>();
                bodyMap.put('initiate', 'manual');
                // Add all appointments to the body that need to be bundled
                List<Object> objectsList =  new List<Object>();
                for (Id saId : serviceAppointmentIds){
                    Map<String, Object> saList = new Map<String, Object>(); 
                    saList.put('serviceAppointmentId', saId);
                    objectsList.add(saList);
                }
                bodyMap.put('saRequestPayloads', objectsList);                   
            }
        }

        if (bodyMap != null){
            bodyJSON = JSON.serialize(bodyMap);
        }

        // System.debug(bodyJSON);
        return bodyJSON;
    }

    /**
     * Process response from REST API call 
     * and deserialize into object
     */    
    private Object processResponse(String response){
        Object resObj;

        switch on bundlingAction {
            when AUTOMATIC_BUNDLING {
                resObj = (automaticBundlingResponse)JSON.deserializeStrict(response, automaticBundlingResponse.class);
            }
            when BUNDLE, UNBUNDLE, REMOVE_BUNDLE_MEMBERS, UPDATE_BUNDLE {
                resObj = (bundleResponse)JSON.deserialize(response, bundleResponse.class);
            }
            when UNBUNDLE_MULTIPLE {
                // TODO - Response contains a JSON string in one of the JSON attributes
                // Not been able to parse that JSON string yes
                resObj = (multipleUnbundleResponse)JSON.deserialize(response, multipleUnbundleResponse.class);
            }
        }

        return resObj;
    }

    /**
     * Response objects for the API Calls
     */

    // Response object for automatic bundling
    public class automaticBundlingResponse {
        public Integer httpStatus;
        public String statusDescription;
        public String responsePayload;
        public String messageCode;
        public String messageAdditionalInfo;
    }

    // Response object for (un)bundle action
    public class bundleResponse {
        public Id bundleId;
        public List<bundleResponsePayload> responsePayloads;
        public String status;
        public String messageCode;
        public String message;
    }   
    
    // Part of the response for (un)bundle action
    public class bundleResponsePayload {
        public String objectName;
        public Id objectId;
        public String action;
        public String status;
        public String messageCode;
        public String message;
        public List<messageParam> messageParams;
    }

    public class messageParam {}

    // Response object for multiple unbundle action
    public class multipleUnbundleResponse {
        public Integer httpStatus;
        public String statusDescription;
        public String responsePayload;
        public String messageCode;    
    }

    // Inner part of the response for multiple unbundle action
    public class multipleUnbundleResponsePayload {
        public Header headers;
        public Body body;
        public String statusCode;
        public Integer statusCodeValue;
    }   
    
    // Inner part of the response for multiple unbundle action
    public class Header {}

    // Inner part of the response for multiple unbundle action
    public class Body {
        public Object bundleId;
        public List<multipleUnbundleResponsePayloads> responsePayloads;
        public String status;
        public String messageCode;
        public String message;
        public String messageAdditionalInfo;
    }    

    // Inner part of the response for multiple unbundle action
    public class multipleUnbundleResponsePayloads {
        public String status;
        public String messageCode;
        public String message;
        public List<messageParam> messageParams;
    }    

    /**
     * Custom bundle API Apex Exception
     */
    public class AppointmentBundlingException extends Exception{}    
}