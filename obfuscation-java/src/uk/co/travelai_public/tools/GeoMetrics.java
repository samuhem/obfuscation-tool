package uk.co.travelai_public.tools;

import lombok.Getter;
import lombok.NonNull;
import uk.co.travelai_public.model.Location;

import java.util.ArrayList;
import java.util.List;

/**
 * Class containing a set of geometrics derived from a list of {@link EdgeDetails}s
 */

@Getter
public class GeoMetrics {

    @NonNull private List<EdgeDetails> edgeDetails;

    private Location startLoc;
    private Location endLoc;

    private double distance;
    private double sinuosity;

    private double maxDistance;
    private double minDistance;
    private double maxVelocity;
    private double minVelocity;
    private int maxDistanceIndex;
    private int minDistanceIndex;
    private int maxVelocityIndex;
    private int minVelocityIndex;
    private double meanVelocity;

    /**
     * Empty Constructor initialising variables
     */
    public GeoMetrics() {
        edgeDetails = new ArrayList<>();
        distance = -1;
        sinuosity = -1;
        maxDistance = -1;
        minDistance = -1;
        maxVelocity = -1;
        minVelocity = -1;
        meanVelocity = -1;
        maxDistanceIndex = -1;
        minDistanceIndex = -1;
        maxVelocityIndex = -1;
        minVelocityIndex = -1;
    }

    /**
     * Insert {@link EdgeDetails} and update result variables
     * <p>
     * @param ds new {@link EdgeDetails} object
     */
    public void insertDistSpeed(EdgeDetails ds) {
        edgeDetails.add(ds);
        int thisIdx = edgeDetails.size() - 1;

        // Handle first case
        if (edgeDetails.size() == 1) {
            startLoc = ds.locA;
            endLoc = ds.locB;
            maxDistance = ds.distance;
            minDistance = ds.distance;
            maxVelocity = ds.velocity;
            minVelocity = ds.velocity;
            maxDistanceIndex = 0;
            minDistanceIndex = 0;
            maxVelocityIndex = 0;
            minVelocityIndex = 0;
            return;
        }

        if (ds.distance > maxDistance) {
            maxDistance = ds.distance;
            maxDistanceIndex = thisIdx;
        }
        if (ds.distance < minDistance) {
            minDistance = ds.distance;
            minDistanceIndex = thisIdx;
        }
        if (ds.velocity > maxVelocity) {
            maxVelocity = ds.velocity;
            maxVelocityIndex = thisIdx;
        }
        if (ds.velocity < minVelocity) {
            minVelocity = ds.velocity;
            minVelocityIndex = thisIdx;
        }

        endLoc = ds.locB;
        distance += ds.distance;

        if (startLoc == null && ds.locA != null)
            startLoc = ds.locA;

        if (ds.locB != null)
            endLoc = ds.locB;

        if (startLoc != null && endLoc != null)
            sinuosity = distance / Tools.getDistanceMeters(startLoc, endLoc);

    }

    /**
     * Get mean velocity of the LDR
     */
    public double updateMeanVelocity() {
        double sumDist = 0;
        double sumTime = 0;
        for (EdgeDetails ds : edgeDetails) {
            sumDist += ds.distance;
            sumTime += ds.duration;
        }
        meanVelocity = sumDist / sumTime;
        return meanVelocity;
    }
}
