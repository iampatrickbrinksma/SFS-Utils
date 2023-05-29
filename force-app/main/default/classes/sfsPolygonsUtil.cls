public with sharing class sfsPolygonsUtil {

    private Double lat;
    private Double lng;

    public sfsPolygonsUtil(Decimal lat, Decimal lng) {
        this.lat = Double.valueOf(lat);
        this.lng = Double.valueOf(lng);
    }

    public sfsPolygonsUtil(Double lat, Double lng) {
        this.lat = lat;
        this.lng = lng;
    }

    public ServiceTerritory getServiceTerritoryByGeolocation(){
        ServiceTerritory st;
        Id stId = FSL.PolygonUtils.getTerritoryIdByPolygons(lng, lat);
        if (stId != null){
            st = getServiceTerritoryById(stId);
        }
        return st;
    }

    public List<ServiceTerritory> getServiceTerritoriesByGeolocation(){
        List<ServiceTerritory> sts;
        List<FSL__Polygon__c> polygons = FSL.PolygonUtils.getAllPolygonsByLatLong(lng, lat);
        if (!polygons.isEmpty()){
            List<Id> stIds = new List<Id>();
            for (FSL__Polygon__c polygon : polygons){
                stIds.add(polygon.FSL__Service_Territory__c);
            }
            sts = getServiceTerritoriesByIds(stIds);
        }
        return sts;
    }

    public List<FSL__Polygon__c> getMapPolygonsByServiceTerritoryId(Id stId){
        String q = getAllFieldsQuery('FSL__Polygon__c', 'FSL__Service_Territory__c = :stId');
        Map<String, Object> bindParams = new Map<String, Object>{
            'stId' => stId
        };
        return Database.queryWithBinds(q, bindParams, AccessLevel.SYSTEM_MODE);        
    }

    public Map<Id, FSL__Polygon__c> getMapPolygonsByServiceTerritoryIds(List<Id> stIds){
        Map<Id, FSL__Polygon__c> stIdToPolygon;
        String q = getAllFieldsQuery('FSL__Polygon__c', 'FSL__Service_Territory__c IN :stIds');
        Map<String, Object> bindParams = new Map<String, Object>{
            'stIds' => stIds
        };
        List<FSL__Polygon__c> polygons = Database.queryWithBinds(q, bindParams, AccessLevel.SYSTEM_MODE);     
        if (!polygons.isEmpty()){
            stIdToPolygon = new Map<Id, FSL__Polygon__c>();
            for (FSL__Polygon__c polygon : polygons){
                stIdToPolygon.put(polygon.FSL__Service_Territory__c, polygon);
            }
        }   
        return stIdToPolygon;
    }    

    private ServiceTerritory getServiceTerritoryById(Id stId){
        List<ServiceTerritory> sts = getServiceTerritoriesByIds(new List<Id>{stId});
        if (!sts.isEmpty()){
            return sts[0];
        } else {
            return null;
        }
    }

    private List<ServiceTerritory> getServiceTerritoriesByIds(List<Id> stIds){
        String q = getAllFieldsQuery('ServiceTerritory', 'Id IN :stIds');
        Map<String, Object> bindParams = new Map<String, Object>{
            'stIds' => stIds
        };
        return Database.queryWithBinds(q, bindParams, AccessLevel.SYSTEM_MODE);
    }

    private static String getAllFieldsQuery(String objectAPIName, String whereClause) {
        List<String> fields = new List<String>(Schema.getGlobalDescribe().get(objectAPIName).getDescribe().fields.getMap().keySet());
        return 'SELECT '+ String.join(fields, ',') + ' FROM ' + objectAPIName + ' WHERE ' + whereClause;
    }       

}