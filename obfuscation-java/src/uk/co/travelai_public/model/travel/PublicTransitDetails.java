package uk.co.travelai_public.model.travel;

import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Class containing details on public transit line
 */

@Getter
@Setter
@NoArgsConstructor
public class PublicTransitDetails {
    private String companyName;
    private String destination;
    private String lineName;
    private String lineID;
    private String lineType;
}
