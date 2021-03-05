package uk.co.travelai_public.model.travel;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.model.TransportMode;
import uk.co.travelai_public.obfuscation.PrivacyCategory;
import uk.co.travelai_public.obfuscation.TravelPrivacyCategoryFactors;

import java.util.List;

/**
 * Representation of Leg
 * Created by S.Hemminki on 24.04.2018
 */

@Setter
@Getter
@NoArgsConstructor
public class Leg {

    private static int idCounter = 0;
    private int uid = ++idCounter;

    private double startTime;
    private double endTime;
    private double originTZOffset;
    private double destinationTZOffset;
    private double duration;
    private double distance;
    private Location startLoc;
    private Location endLoc;
    private List<Location> legLocs;

    private List<PedestrianStop> pedestrianStops;
    private PublicTransitDetails publicTransitDetails;
    private TransportMode mode;

    // Privacy rating & debug information
    private PrivacyCategory privacyCategory = PrivacyCategory.UNKNOWN;
    private TravelPrivacyCategoryFactors privacyCategoryFactors;

    /**
     * Return boolean indicating whether this {@link Leg} is of PublicTransit type
     * <p>
     * @return boolean
     */
    public boolean isPublicTransit() {
        if (this.publicTransitDetails != null)
            return true;
        else
            return false;
    }

}
