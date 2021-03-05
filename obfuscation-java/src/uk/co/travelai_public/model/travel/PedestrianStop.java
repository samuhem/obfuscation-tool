package uk.co.travelai_public.model.travel;

import lombok.Getter;
import lombok.Setter;
import uk.co.travelai_public.model.Location;

/**
 * Class representing a (brief) stop within a pedestrian leg
 */

@Getter
@Setter
public class PedestrianStop {
    private double startTime;
    private double endTime;
    private double duration;
    private Location stopLoc;
}
