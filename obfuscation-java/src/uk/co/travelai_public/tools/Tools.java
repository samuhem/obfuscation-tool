package uk.co.travelai_public.tools;

import lombok.Getter;
import lombok.NonNull;
import lombok.Setter;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.model.TimeConstants;
import uk.co.travelai_public.model.place.POI;
import org.gavaghan.geodesy.Ellipsoid;
import org.gavaghan.geodesy.GeodeticCalculator;
import org.gavaghan.geodesy.GeodeticCurve;
import org.gavaghan.geodesy.GlobalCoordinates;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.*;

@Getter
@Setter
public class Tools {

    /**
     * Convert Sunday = 1 weekday enumeration to Monday = 1 enumeration
     *
     * @param i weekday integer such that Sunday = 1
     * @return weekday integer such that Monday = 1
     */
    public static int sunday2mondayFirstDayOfWeekInt(int i) {
        return (i + 5) % 7 + 1;
    }

    /**
     * Remove non-numeric characters from input string
     * @param s
     * @return
     */
    public static String removeNonNumerics(String s) {
        if (s == null || s.isEmpty())
            return "";

        return s.replaceAll("[^\\d.]", "");
    }

    /**
     * Return three most likely {@link POI}s based on their score
     * @param rpPlaceScores
     */
    public static Map<POI, Double> getTopThreeRPPlaces(Map<POI, Double> rpPlaceScores) {
        Map<POI, Double> topThree = new HashMap<>();

        if (rpPlaceScores == null || rpPlaceScores.isEmpty())
            return topThree;

        // Get values
        List<POI> rpPlaceList = new ArrayList<>();
        Set<POI> rpPlaces = rpPlaceScores.keySet();
        double[] scores = new double[rpPlaceScores.size()];
        int i = 0;
        for (POI rpPlace: rpPlaceScores.keySet()) {
            scores[i] = rpPlaceScores.get(rpPlace);
            rpPlaceList.add(i, rpPlace);
            i++;
        }

        Map<Integer, Double> topThreeMap = getTopX(scores, 3);
        for (Integer idx: topThreeMap.keySet()) {
            topThree.put(rpPlaceList.get(idx), topThreeMap.get(idx));
        }

        return topThree;
    }

    /**
     * Get Top X values from input array.
     * If Array length is smaller than x, return min(array.length, x)
     *
     * @return Map<index, value> of top X values in the input array
     */
    public static Map<Integer, Double> getTopX(double[] a, int x) {

        //create sort able array with index and value pair
        IndexValuePair[] pairs = new IndexValuePair[a.length];
        for (int i = 0; i < a.length; i++) {
            pairs[i] = new IndexValuePair(i, a[i]);
        }

        //sort
        Arrays.sort(pairs, new Comparator<IndexValuePair>() {
            public int compare(IndexValuePair o1, IndexValuePair o2) {
                return Double.compare(o2.value, o1.value);
            }
        });

        //extract the indices
        int x_ = Math.min(x, pairs.length);
        Map<Integer, Double> result = new HashMap<>();
        for (int i = 0; i < x_; i++) {
            result.put(pairs[i].index, pairs[i].value);
        }

        return result;
    }

    /**
     * Translate epochTS to ZonedDateTime
     *
     * @param epochTS epoch timestamp
     * @param tzOffset timezone offset in milliseconds
     * @return
     */
    public static ZonedDateTime epoch2ZonedDateTime(double epochTS, double tzOffset) {
        Instant instant = Instant.ofEpochMilli((long) epochTS);
        ZonedDateTime zonedDateTime = ZonedDateTime.ofInstant(instant, ZoneId.of("UTC"));
        zonedDateTime = zonedDateTime.plusSeconds((long) (tzOffset / 1000));
        return zonedDateTime;
    }

    /**
     * Check if input {@link DayOfWeek} is during weekend
     *
     * @param day
     * @return boolean
     */
    public static boolean isWeekend(DayOfWeek day) {

        if (day == null) {
            return false;
        }

        if (day.equals(DayOfWeek.SATURDAY) || day.equals(DayOfWeek.SUNDAY))
            return true;

        return false;
    }

    /**
     * Check if input hour of the day is during private hours as set in {@link TimeConstants}
     */
    public static boolean isPrivateHours(int hour) {
        if (hour > 24 || hour < 0) {
            return false;
        }

        for (int i : TimeConstants.PRIVATE_HOURS)
            if (i == hour)
                return true;

        return false;
    }

    /**
     * Calculates distance in meters between two {@link Location}s
     * <p>
     * @param firstLocation  first {@link Location}
     * @param secondLocation second {@link Location}
     * @return distance in meters
     */
    public static double getDistanceMeters(@NonNull Location firstLocation, @NonNull Location secondLocation) {

        final GeodeticCalculator geoCalc = new GeodeticCalculator();
        final Ellipsoid ref = Ellipsoid.WGS84;
        final GlobalCoordinates firstCoords = new GlobalCoordinates(firstLocation.getLatitude(), firstLocation.getLongitude());
        final GlobalCoordinates secondCoords = new GlobalCoordinates(secondLocation.getLatitude(), secondLocation.getLongitude());
        final GeodeticCurve path = geoCalc.calculateGeodeticCurve(ref, firstCoords, secondCoords);
        return path.getEllipsoidalDistance();
    }

    /**
     * Calculate distance between consecutive {@link Location} points, and estimated velocity between the points
     * <p>
     * @return result as {@link GeoMetrics} containing List of {@link EdgeDetails}s and min/max values and indices
     */
    public static GeoMetrics getGeometrics(@NonNull List<Location> locs, boolean accountForLocAcc) {
        GeoMetrics res = new GeoMetrics();
        res.insertDistSpeed(new EdgeDetails(null, null, 0, 0, 0));
        if (locs.size() < 2)
            return res;
        for (int i = 1; i < locs.size(); i++) {
            Location locA = locs.get(i - 1);
            Location locB = locs.get(i);
            double ddist = getDistanceMeters(locA, locB);
            double v = getLocSpeed(ddist, locA, locB, accountForLocAcc);
            double t = Math.abs(locA.getTimestamp() - locB.getTimestamp());
            res.insertDistSpeed(new EdgeDetails(locA, locB, ddist, t, v));
        }
        res.updateMeanVelocity();
        return res;
    }

    /**
     * Conservative estimate of velocity based on two Location points; takes Accuracy into account
     * <p>
     * @param ddist Distance between l1 and l2
     * @param l1 First {@link Location}
     * @param l2 Second {@link Location}
     * @return estimated locSpeed = distance - max(accuracy) / dtime
     */
    private static double getLocSpeed(double ddist, @NonNull Location l1, @NonNull Location l2, boolean reduceLocAcc) {

        double dtime = Math.abs(l1.getTimestamp() - l2.getTimestamp());
        if (dtime == 0) {
            // log.warn("Identical timestamp for input Locations (--> Division by zero). Returning -1.0 speed");
            return -1.0;
        }

        double acc1 = l1.getAccuracy();
        double acc2 = l2.getAccuracy();

        if (reduceLocAcc)
            ddist = ddist - Math.max(acc1, acc2);

        return ddist / dtime;
    }




}
