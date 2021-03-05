package uk.co.travelai_public.model.HERE;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.json.JSONObject;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class HEREExtraDetails {
    private long id;
    private HERELinkFunctionalClass functionalClass;
    private HERESpeedCategory speedCategory;
    private boolean paved;
    private boolean privateRoad;
}

