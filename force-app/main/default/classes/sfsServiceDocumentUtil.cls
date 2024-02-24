/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class to generate Service Documents (part of the Document Builder feature)
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
public with sharing class sfsServiceDocumentUtil {

    // Exception
    public class sfsServiceDocumentException extends Exception {}

    // Endpoint is available from API version 60.0 and above (Spring '24')
    private static final String API_ENDPOINT = '/services/data/v60.0/actions/standard/createServiceDocument';

    // In future releases more document types will be added
    private static final String DOCUMENT_TYPE = 'SERVICE_DOCUMENT';

    // Create Service Document asynchronously
    @future(callout=true)
    public static void createDocumentAsync(Id recordId, Id templateId, String title, String locale, Id pdfReportId){
        createDocument(recordId, templateId, title, locale, pdfReportId);
    }

    // Create Service Document synchronously
    public static Id createDocument(Id recordId, Id templateId, String title, String locale, Id pdfReportId){
        // Construct REST API body
        inputBody inputBody = new inputBody(recordId, templateId, title, locale, pdfReportId);
        input input = new input(inputBody);
        String body = JSON.serializePretty(input);

        // Callout
        HttpRequest request = new HttpRequest();        
        request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + API_ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        Http http = new Http();
        HttpResponse response = http.send(request);
        String responseBody = response.getBody();

        // Deserialize response
        List<outputBody> outputs = (List<outputBody>)JSON.deserialize(responseBody, List<outputBody>.class);
        outputBody output = outputs[0];

        // Process results
        if (response.getStatusCode() == 200){
            pdfReportId = (Id)output.outputValues.get('pdfReportId');
        } else {
            String errMsg = 'Status: ' + response.getStatusCode() + ' - ' + response.getStatus();
            if (response.getStatusCode() == 400){
                errMsg += ' The following errors occurred: ' + output.getErrorMessages();
            }
            throw new sfsServiceDocumentException(errMsg);
        }

        return pdfReportId;
    }

    // Input structure for REST API call
    public class input {
        public List<inputBody> inputs;

        public input(inputBody inputBody){
            inputs = new List<inputBody>{inputBody};
        }
    }

    public class inputBody {
        public Id recordId;
        public Id templateId;
        public String title;
        public String documentType;
        public String locale;
        public Id pdfReportId;

        public inputBody (Id recordId, Id templateId, String title, String locale, Id pdfReportId){
            this.documentType = DOCUMENT_TYPE;
            this.recordId = recordId;
            this.templateId = templateId;
            if (locale != null){
                this.locale = locale;
            }
            if (title !=  null){
                this.title = title;
            }
            if (pdfReportId != null){
                this.pdfReportId = pdfReportId;
            }
        }
    }

    // Return structure of REST API call
    public class outputBody {
        public String actionName;
        public List<error> errors;
        public Boolean isSuccess;
        public Map<String, String> outputValues;
        public String version;

        public String getErrorMessages(){
            String errMSg = '';
            for(error error : errors){
                errMSg += 'statusCode: ' + error.statusCode + ', message: ' + error.message + ', in fields: ' + String.join(error.fields, ',') + ', ';
            }
            return errMSg;
        }
    }

    public class error {
        public String statusCode;
        public String message;
        public List<String> fields;
    }

}