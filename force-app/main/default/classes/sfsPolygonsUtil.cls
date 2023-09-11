/**
* ─────────────────────────────────────────────────────────────────────────────────────────────────┐
* Util class which provides a set of methods to deal with polygons
* ──────────────────────────────────────────────────────────────────────────────────────────────────
* @author         Patrick Brinksma   <patrick@brinksma.es>
* ─────────────────────────────────────────────────────────────────────────────────────────────────┘
*/
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
        Map<Id, List<FSL__Polygon__c>> stIdToPolygons = getMapPolygonsByServiceTerritoryIds(new List<Id>{stId});
        if (stIdToPolygons != null){
            return stIdToPolygons.get(stId);
        } else {
            return null;
        }
    }

    public Map<Id, List<FSL__Polygon__c>> getMapPolygonsByServiceTerritoryIds(List<Id> stIds){
        Map<Id, List<FSL__Polygon__c>> stIdToPolygons;
        String q = getAllFieldsQuery('FSL__Polygon__c', 'FSL__Service_Territory__c IN :stIds');
        Map<String, Object> bindParams = new Map<String, Object>{
            'stIds' => stIds
        };
        List<FSL__Polygon__c> polygons = Database.queryWithBinds(q, bindParams, AccessLevel.SYSTEM_MODE);     
        if (!polygons.isEmpty()){
            stIdToPolygons = new Map<Id, List<FSL__Polygon__c>>();
            for (FSL__Polygon__c polygon : polygons){
                List<FSL__Polygon__c> listOfPolygon = stIdToPolygons.get(polygon.FSL__Service_Territory__c);
                if (listOfPolygon == null){
                    listOfPolygon = new List<FSL__Polygon__c>();
                }
                listOfPolygon.add(polygon);
                stIdToPolygons.put(polygon.FSL__Service_Territory__c, listOfPolygon);
            }
        }   
        return stIdToPolygons;
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