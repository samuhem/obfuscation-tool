package uk.co.travelai_public.model.HERE;

import lombok.Getter;
import lombok.Setter;
import uk.co.travelai_public.model.place.DwellDurationType;
import uk.co.travelai_public.obfuscation.PrivacyCategory;

@Getter
@Setter
public class HEREPlaceCategory {

    private String id;
    private String title;
    private String description;
    private PrivacyCategory sensitivityCategory;
    private DwellDurationType[] durationCategory;

}
