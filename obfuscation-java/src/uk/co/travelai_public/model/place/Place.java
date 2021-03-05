package uk.co.travelai_public.model.place;

import lombok.Getter;
import lombok.Setter;
import uk.co.travelai_public.model.travel.Route;
import uk.co.travelai_public.obfuscation.PrivacyCategory;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Getter
@Setter
public class Place {

    private static int placeIDCounter = 0;
    private int uid = ++placeIDCounter;

    // Dwells, arriving and departing Routes
    private List<Route> departingRoutes;
    private List<Route> arrivingRoutes;
    private List<Dwell> dwells;

    // Real-world places near Place location
    private Map<POI, Double> POIScores = new HashMap<>();
    private List<POI> nearbyPOIs;

    // Place visit stats and privacy score
    private double visitFrequency;
    private double visitRegularity;
    private double visitDuration;
    private int nSleepVisits;
    private PrivacyCategory privacyCategory = PrivacyCategory.UNKNOWN;

    // PlaceType based on dwell visits
    private PlaceType placeType;

    // Place Location
    private double latitude;
    private double longitude;

    // Indicates whether this Place is imported from DB or created from present data
    private boolean isImported = false;
}
