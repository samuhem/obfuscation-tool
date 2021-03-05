package uk.co.travelai_public.obfuscation;

import lombok.NoArgsConstructor;

/**
 * Debug class containing details about the various factors used to estimate place and travel privacy ratings.
 *
 * Author: S. Hemminki
 * Date: 05.03.2021
 */

@NoArgsConstructor
public class TravelPrivacyCategoryFactors {

    // Factors
    public double basePrivacy           = 0;
    public double distanceScore         = 0;
    public double sinuosityScore        = 0;
    public double firstLastLegScore     = 0;
    public double pedestrianStopsScore  = 0;
    public double roadFCScore           = 0;
    public double roadSCScore           = 0;
    public double privateRoadScore      = 0;
    public double ptConnectScore        = 0;
    public double dayScore              = 0;
    public double todScore              = 0;

    // Weights
    public double wDistanceScore        = 0;
    public double wSinuosityScore       = 0;
    public double wFirstLastLegScore    = 0;
    public double wPedestrianStopsScore = 0;
    public double wRoadFCScore          = 0;
    public double wRoadSCScore          = 0;
    public double wPrivateRoadScore     = 0;
    public double wPtConnectScore       = 0;
    public double wDayScore             = 0;
    public double wTimeOfDayScore       = 0;


    /**
     * toString
     */
    @Override
    public String toString() {
        return "{ Base: "                   + basePrivacy
                + ", + Distance: + "        + distanceScore
                + ", + Sinuosity: + "       + sinuosityScore
                + ", + FirstLastLeg: + "    + firstLastLegScore
                + ", + PedestrianStop: + "  + pedestrianStopsScore
                + ", + RoadFC: + "          + roadFCScore
                + ", + RoadSC: + "          + roadSCScore
                + ", + PrivateRoad: + "     + privateRoadScore
                + ", + PTConnect: + "       + ptConnectScore + "}";
    }

}
