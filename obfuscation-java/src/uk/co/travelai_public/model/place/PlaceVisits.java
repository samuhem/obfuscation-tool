package uk.co.travelai_public.obfuscation;

import lombok.AllArgsConstructor;
import lombok.NoArgsConstructor;
import uk.co.travelai_public.model.place.Dwell;
import uk.co.travelai_public.model.place.Place;

import java.util.List;

@NoArgsConstructor
@AllArgsConstructor
public class PlaceVisits {
    protected Place place;
    protected List<Dwell> dwells;
    protected double regularity;
    protected double frequency;


    /**
     * toString
     */
    @Override
    public String toString() {

        return "{" + place.getUid()             + ", " +
                "nDwells: " + dwells.size()     + ", " +
                "regularity: " + regularity     + ", " +
                "frequency: " + frequency;
    }

}
