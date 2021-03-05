package uk.co.travelai_public.model.place;

import lombok.Getter;
import lombok.Setter;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.obfuscation.PrivacyCategory;

@Getter
@Setter
public class POI {

        private PlaceCategory category;
        private PrivacyCategory categorySensitivity;
        private OpenHours openHours;
        private String title;
        private String id;
        private Location position;
        private Location access;
        private double distance; // Distance from the query geo location

}
