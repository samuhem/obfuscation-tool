package uk.co.travelai_public.model.HERE;


/** HERE Road Functional Class categorization
     *
     * https://developer.here.com/documentation/traffic-data-service/dev_guide/topics/apply-functional-road-class-filter.html
     *
     Functional Road Class Value 	Functional Class Description

     1 	These roads are meant for high volume, maximum speed traffic between and through major metropolitan areas.
     There are very few, if any, speed changes. Access to this road is usually controlled.

     2 	These roads are used to channel traffic to Main Roads (FRC1) for travel between and through cities in the
     shortest amount of time. There are very few, if any speed changes.

     3 	These roads interconnect First Class Roads (FRC2) and provide a high volume of traffic movement at a lower
     level of mobility than First Class Roads (FRC2).

     4 	These roads provide for a high volume of traffic movement at moderate speeds between neighborhoods.
     These roads connect with higher Functional Class roads to collect and distribute traffic between neighborhoods.

     5 	These roads' volume and traffic movements are below the level of any other road.

     */
public enum HERELinkFunctionalClass {
    unknown,
    roadclass_1,
    roadclass_2,
    roadclass_3,
    roadclass_4,
    roadclass_5;


    /**
     * @return {@link HERELinkFunctionalClass} object matching the input ID.
     */
    public static HERELinkFunctionalClass fromID(int id) {
        if (id < 0)
            return HERELinkFunctionalClass.unknown;
        if (id > HERELinkFunctionalClass.values().length - 1) {
            return HERELinkFunctionalClass.unknown;
        }

        return HERELinkFunctionalClass.values()[id];
    }




}
