package uk.co.travelai_public.model;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import uk.co.travelai_public.model.HERE.HEREExtraDetails;

import java.util.Locale;

/**
 * A class that represents a Location.
 */

@Getter
@Setter
@NoArgsConstructor
public class Location {

    private double timestamp;
    private double latitude;
    private double longitude;
    private double accuracy;
    private double speed;
    private double dspeed;
    private double tzOffset_ms;
    private HEREExtraDetails extraDetails;

    // Allow switching location overwritten state
    private boolean overwrittenByGISProcess = false;


    /**
     * Format timestamp
     *
     * @return formatted timestamp
     */
    private String getTimestampString() {
        return String.format(Locale.UK, "%.3f", timestamp);
    }

    @Override
    public String toString() {
        return "Loc {" + getTimestampString() + "," + latitude + "," + longitude + "," + accuracy + "," + speed;
    }
}
