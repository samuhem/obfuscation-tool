package uk.co.travelai_public.tools;

import lombok.AllArgsConstructor;
import uk.co.travelai_public.model.Location;

/**
 * Class representing geo-details for an edge made from a pair of locations (A,B)
 *
 * Created by S.Hemminki on 13.03.2018
 */

@AllArgsConstructor
public class EdgeDetails {
    public Location locA;
    public Location locB;
    public double distance;
    public double duration;
    public double velocity;

    @Override
    public String toString() {
        return "d: " + distance + ", t: " + duration + ", v: " + velocity;
    }

    public boolean isValid() {
        return !(distance == 0 && duration == 0 && velocity == 0);
    }
}
