package uk.co.travelai_public.model.travel;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.model.place.Dwell;
import uk.co.travelai_public.model.place.Place;
import uk.co.travelai_public.obfuscation.PrivacyCategory;

import java.util.ArrayList;
import java.util.List;

/**
 * Class representing a Route
 * <p>
 * Created by S.Hemminki 06.03.2018
 */

@Setter
@Getter
@NoArgsConstructor
public class Route {

    private static int routeIDCounter = 0;
    private int uid = ++routeIDCounter;

    private Dwell startDwell;
    private Dwell endDwell;
    private Place startPlace;
    private Place endPlace;

    private List<Location> routeLocs = new ArrayList<>();

    private double startTime        = -1;
    private double endTime          = -1;
    private double duration         = -1;
    private double distance         = -1;
    private double gisDistance      = -1;

    private double originTZOffset;
    private double destinationTZOffset;

    private double distFromStartDwell = -1;
    private double distToEndDwell     = -1;

    private List<Leg> matchedLegs = new ArrayList<>();

    private String label;

    private PrivacyCategory privacyCategory = PrivacyCategory.UNKNOWN;
}
