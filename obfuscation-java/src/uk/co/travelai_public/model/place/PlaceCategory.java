package uk.co.travelai_public.model.place;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@AllArgsConstructor
@Getter
@Setter
public class PlaceCategory {

    private String categoryName;
    private String categoryId;
    private POI poi;

}
