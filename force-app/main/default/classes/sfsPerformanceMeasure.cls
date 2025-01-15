/**
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┐
 * Class for measuring performance in Apex to write to the debug log 
 * ─────────────────────────────────────────────────────────────────────────────────────────────────
 * @author         Patrick Brinksma   <patrick@brinksma.es>
 * ─────────────────────────────────────────────────────────────────────────────────────────────────┘
 */
public with sharing class sfsPerformanceMeasure {

    // Keep track of different performance indicators
    private Map<String, Long> perfMeasures = new Map<String, Long>();
    // Keep ordered list of measures to write to debug log
    private List<String> perfMeasureNames = new List<String>();

    public sfsPerformanceMeasure(){}

    // Start measuring the performance
    public void start(String name){
        if (perfMeasures.keySet().contains(name)){
            throw new sfsPerformanceMeasureException('Performance Measure with name: ' + name + ' already exist, please use a unique name!');
        }
        perfMeasures.put(name, System.now().getTime());
        perfMeasureNames.add(name);
    }

    // Stop measuring the performance
    public void stop(String name){
        if (perfMeasures.get(name) == null){
            throw new sfsPerformanceMeasureException('Performance Measure with name: ' + name + ' does not exist!');
        }    
        perfMeasures.put(name, System.now().getTime() - perfMeasures.get(name));
    }

    // Write as JSON in debug log
    public void debugResults(){
        String debug = '\n\n';
        String sep = '>';
        for (String perfMeasureName : perfMeasureNames){
            debug += sep + perfMeasureName + ': ' + perfMeasures.get(perfMeasureName) + ' ms\n';
            sep += '--';
        }
        System.debug(debug);
    }

    // Custom exception
    public class sfsPerformanceMeasureException extends Exception{}

}