public with sharing class sfsUtil {

    /*
     * Default settings for cloning SObject
     */ 
    private static Boolean preserveId = false;
    private static Boolean isDeepClone = true;
    private static Boolean preserveReadonlyTimestamps = false;
    private static Boolean preserveAutonumber = false;   
    
    /*
     * Collection of describe of objects
     */
    public static Map<String, Map<String, Schema.SObjectField>> objFieldsMap = new Map<String, Map<String, Schema.SObjectField>>();

    /*
     * Returns a map of Field API Name to Schema.SObjectField for a specific SObject
     */
    public static Map<String, Schema.SObjectField> getObjectFieldsDescribeMap(String objectApiName){
        Map<String, Schema.SObjectField> fieldDescMap = objFieldsMap.get(objectAPIName);
        if (fieldDescMap == null){
            fieldDescMap = Schema.getGlobalDescribe().get(objectAPIName).getDescribe().fields.getMap();
            objFieldsMap.put(objectAPIName, fieldDescMap);
        }        
        return fieldDescMap;
    }

    /*
     * Returns a list of custom fields and the name field for an SObject
     */
    public static List<String> getObjectNameAndCustomFields(String objectApiName){
        Map<String, Schema.SObjectField> fieldDescMap = getObjectFieldsDescribeMap(objectApiName);
        List<String> fields = new List<String>();
        for (String field : fieldDescMap.keySet()){
            Schema.DescribeFieldResult fieldDesc = fieldDescMap.get(field).getDescribe();
            if (fieldDesc.isCreateable() && (fieldDesc.isNameField() || fieldDesc.isCustom())){
                fields.add(field);
            }
        }
        return fields;
    }  

    /*
     * Returns a SOQL query string including all fields and optionallly additional fields and a where clause
     */    
    public static String getAllFieldsQuery(String objectApiName, List<String> additionalFields, String whereClause) {
        Map<String, Schema.SObjectField> fieldDescMap = getObjectFieldsDescribeMap(objectApiName);
        List<String> fields = new List<String>();
        fields.addAll(fieldDescMap.keySet());
        if (additionalFields != null){
            Set<String> uniqueFields = new Set<String>();
            uniqueFields.addAll(fields);
            uniqueFields.addAll(additionalFields);
            fields = new List<String>();
            fields.addAll(uniqueFields);
        }
        String query = 'SELECT '+ String.join(fields, ',') + ' FROM ' + objectAPIName;
        if (whereClause != null) query += ' WHERE ' + whereClause;
        return query;
    }

    /*
     * Returns a SOQL query string including all fields and optionallly additional fields
     */    
    public static String getAllFieldsQuery(String objectAPIName, List<String> additionalFields) {
        return getAllFieldsQuery(objectAPIName, additionalFields, null);
    }

    /*
     * Returns a SOQL query string including all fields and optionallly a where clause
     */    
    public static String getAllFieldsQuery(String objectAPIName, String whereClause) {
        return getAllFieldsQuery(objectAPIName, null, whereClause);
    }
    
    /*
     * Returns a SOQL query string including all fields
     */    
    public static String getAllFieldsQuery(String objectAPIName) {
        return getAllFieldsQuery(objectAPIName, null, null);
    }    

    /*
     * Returns a clone of an SObject record and optionally updates a field
     * that references to a parent object
     */    
    public static SObject cloneRecord(SObject obj, String parentAPIField, Id parentId){
        SObject clonedObj = obj.clone(preserveId, isDeepClone, preserveReadonlyTimestamps, preserveAutonumber);
        if (parentAPIField != null)
            clonedObj.put(parentAPIField, parentId);
        return clonedObj;
    }

    /*
     * Returns a list of clones of a list of SObject records and optionally updates a field
     * that references to a parent object
     */    
    public static List<SObject> cloneRecords(List<SObject> objs, String parentAPIField, Id parentId){
        List<SObject> clonedRecords = new List<SObject>();
        for (SObject obj : objs){
            SObject clonedObj = obj.clone(preserveId, isDeepClone, preserveReadonlyTimestamps, preserveAutonumber);
            if (parentAPIField != null){
                clonedObj.put(parentAPIField, parentId);
            }
            clonedRecords.add(clonedObj);
        }
        return clonedRecords;
    }

    /*
     * Converts a list of SObject to a map of a field of choice to the SObject
     * Make sure the field value is unique across the list of SObjects
     */    
    public static Map<String, SObject> convertObjectListToMap(List<SObject> objects, String keyField){
        Map<String, SObject> objMap = new Map<String, SObject>();
        for (SObject obj : objects){
            objMap.put((String)obj.get(keyField), obj);
        }
        return objMap;
    }

    /*
     * Returns a list of random geolocations within a defined radius of a center geolocation
     */    
    public static List<Location> getRandomLocationsInCircle(Decimal centerLat, Decimal centerLong, Double radius, Integer nrOfLocations){
        List<Location> points = new List<Location>();
        Location center = Location.newInstance(centerLat, centerLong);
        for (Integer i=0; i<nrOfLocations; i++) {
            points.add(getRandomPointInCircle(center, radius));
        }  
        return points;      
    }

    /*
     * Returns a random geolocation within a defined radius of a center geolocation
     */        
    public static Location getRandomPointInCircle(Location center, Double radiusInM) {
        Double rd = radiusInM/Double.valueOf(111300);
        Double t = 2 * Math.PI * Math.random();
        Double r = Math.sqrt(Math.random());
        Double x = r * Math.cos(t);
        Double y = r * Math.sin(t);
    
        return Location.newInstance(center.getLatitude() + x * rd, center.getLongitude() + y * rd * 2);
    }
    
    /*
     * Returns a random Integer provided a min and max value
     */        
    public static Integer getRandomInteger(Integer min, Integer max){
        return Integer.valueOf(min + (Math.random() * (max - min)));
    }  
    
    /*
     * Returns a random String of a defined length, and optionally includes
     * spaces or numbers only
     */    
    public static String generateRandomString(Integer length, Boolean includeSpace, Boolean numbersOnly) {
        String chars;
        if (numbersOnly){
            chars = '0123456789';
        } else {
            chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
        }
        if (includeSpace){
            chars += ' ';
        }
        String randStr = '';
        while (randStr.length() < length) {
            Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
            randStr += chars.substring(idx, idx+1);
        }
        return randStr;
    }  

}