package uk.co.travelai_public.model.place;

import lombok.Getter;
import lombok.Setter;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.model.travel.Route;

/**
 * Class representing a single Dwell within a {@link Place}
 * <p>
 * Created by S.Hemminki 06.03.2018
 */

@Setter
@Getter
public class Dwell {

    private static int dwellIDCounter = 0;
    private int uid = ++dwellIDCounter;

    // Dwell duration
    private double startTime = -1;
    private double endTime = -1;
    private double duration = -1;

    // Dwell location
    private Location dwellLocation;

    // TravelObjects associated with this Dwell
    private int parentPlaceID = -1;
    private Route origin_of_route;
    private Route destination_of_route;

    // Additional dwell details
    private DwellDurationType dwellDurationType;

}
