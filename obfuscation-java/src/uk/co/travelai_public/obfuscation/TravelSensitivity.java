package uk.co.travelai_public.obfuscation;

import lombok.NoArgsConstructor;
import lombok.NonNull;
import uk.co.travelai_public.model.HERE.HERELinkFunctionalClass;
import uk.co.travelai_public.model.HERE.HERESpeedCategory;
import uk.co.travelai_public.model.Location;
import uk.co.travelai_public.model.TransportMode;
import uk.co.travelai_public.model.place.Place;
import uk.co.travelai_public.model.travel.Leg;
import uk.co.travelai_public.model.travel.PedestrianStop;
import uk.co.travelai_public.model.travel.Route;
import uk.co.travelai_public.tools.GeoMetrics;
import uk.co.travelai_public.tools.Tools;

import java.time.DayOfWeek;
import java.time.ZonedDateTime;
import java.util.List;

/**
 * Class containing methods to assess sensitivity of a Route and its Legs and Waypoints
 *
 * Author: S.Hemminki
 * Date: 15.2.2020
 */

@NoArgsConstructor
public class TravelSensitivity {


    /**
     * Estimate Route sensitivity
     */
    public void run(List<Route> routes) {
        for (Route r: routes) {
            estimateRouteSensitivity(r);
        }
    }


    /**
     * Estimate Route sensitivity
     *
     * @param r {@link Route} to estimate sensitivity of
     */
    public void estimateRouteSensitivity(@NonNull Route r) {

        Place startPlace = r.getStartPlace();
        Place endPlace = r.getEndPlace();

        PrivacyCategory startPlaceSensitivity = PrivacyCategory.UNKNOWN;
        PrivacyCategory endPlaceSensitivity = PrivacyCategory.UNKNOWN;

        if (startPlace != null)
            startPlaceSensitivity = startPlace.getPrivacyCategory();

        if (endPlace != null)
            endPlaceSensitivity = endPlace.getPrivacyCategory();

        if (r.getMatchedLegs() == null) {
            r.setPrivacyCategory(PrivacyCategory.UNKNOWN);
            return;
        }

        Leg prevLeg = null;
        Leg nextLeg = null;
        for (int i = 0; i < r.getMatchedLegs().size(); i++) {

            Leg leg = r.getMatchedLegs().get(i);

            ZonedDateTime startDate = Tools.epoch2ZonedDateTime(leg.getStartTime(), leg.getOriginTZOffset());
            DayOfWeek day = startDate.getDayOfWeek();
            int hour = startDate.getHour();

            // Weekend vs. weekday
            double dayScore = 0;
            if (Tools.isWeekend(day))
                dayScore = 1;

            // Time of day; private vs. public hours
            double todScore = 0;
            if (Tools.isPrivateHours(hour))
                todScore = 1;

            if (i > 0)
                prevLeg = r.getMatchedLegs().get(i - 1);
            if (r.getMatchedLegs().size() > (i + 1))
                nextLeg = r.getMatchedLegs().get(i + 1);

            // last leg gets privacy score from end place privacyCategory
            double lastLegScore = 0.0;
            if (nextLeg == null && endPlaceSensitivity != null) {
                if (endPlaceSensitivity.equals(PrivacyCategory.PUBLIC))
                    lastLegScore = 0.0;
                if (endPlaceSensitivity.equals(PrivacyCategory.SENSITIVE))
                    lastLegScore = 0.5;
                if (endPlaceSensitivity.equals(PrivacyCategory.PRIVATE))
                    lastLegScore = 1.0;
                if (endPlaceSensitivity.equals(PrivacyCategory.UNKNOWN))
                    lastLegScore = 1.0;
            }

            // first leg gets privacy score from start place privacyCategory
            double firstLegScore = 0.0;
            if (prevLeg == null && startPlaceSensitivity != null) {
                if (startPlaceSensitivity.equals(PrivacyCategory.PUBLIC))
                    firstLegScore = 0.0;
                if (startPlaceSensitivity.equals(PrivacyCategory.SENSITIVE))
                    firstLegScore = 0.5;
                if (startPlaceSensitivity.equals(PrivacyCategory.PRIVATE))
                    firstLegScore = 1.0;
                if (startPlaceSensitivity.equals(PrivacyCategory.UNKNOWN))
                    firstLegScore = 1.0;
            }
            double firstLastLegScore = Math.max(firstLegScore, lastLegScore);


            // Public transit --> PrivacyCategory 1
            if (leg.isPublicTransit()) {
                leg.setPrivacyCategory(PrivacyCategory.PUBLIC);
                continue;
            }

            GeoMetrics geoMetrics = Tools.getGeometrics(leg.getLegLocs(), false);

            // Handle walking/run legs
            if (leg.getMode().equals(TransportMode.walk) || leg.getMode().equals(TransportMode.run)) {

                // Single-leg walking round trips share privacy rating of the place
                if (startPlace == endPlace && r.getMatchedLegs().size() == 1) {
                    leg.setPrivacyCategory(startPlaceSensitivity);
                    continue;
                }

                // PublicTransitConnection score [0.0 - 1.0]
                double publicTransitConnectionScore = 0;
                if (prevLeg != null && prevLeg.isPublicTransit())
                    publicTransitConnectionScore += 0.5;
                if (nextLeg != null && nextLeg.isPublicTransit())
                    publicTransitConnectionScore += 0.5;

                // Distance score [0.0 - 1.0], 300m = 0.0, 3000m = 1.0
                double minDistance = 300;
                double maxDistance = 3000;
                double distanceScore = (geoMetrics.getDistance() - minDistance) / (maxDistance - minDistance);
                distanceScore = Math.min(1, Math.max(0, distanceScore));

                // Sinuosity score [0.0 - 1.0], 1.5 = 0, 3.0 = 1.0
                double sinuosityScore = 0.0;
                if (geoMetrics.getDistance() > minDistance) {
                    double minSinuosity = 1.33;
                    double maxSinuosity = 2.50;
                    sinuosityScore = (geoMetrics.getSinuosity() - minSinuosity) / (maxSinuosity - minSinuosity);
                    sinuosityScore = Math.min(1, Math.max(0, sinuosityScore));
                }

                // Pedestrian stops score [0.0 - 1.0]
                double pedestrianStopsScore = 0;
                for (PedestrianStop ps: leg.getPedestrianStops()) {
                    if (ps.getDuration() > 60)
                        pedestrianStopsScore += 0.2;
                    if (ps.getDuration() > 300)
                        pedestrianStopsScore += 0.3;
                    if (ps.getDuration() > 900)
                        pedestrianStopsScore += 0.5;
                }
                pedestrianStopsScore = Math.min(pedestrianStopsScore, 1.0);

                // Base score for walking legs
                double basePrivacy              = 1.33;

                // Weights should sum to 4
                double wDistance                = 0.25;
                double wSinuosity               = 0.90;
                double wPedestrianStops         = 0.90;
                double wFirstLastLeg            = 0.45;
                double wDay                     = 0.75;
                double wTimeOfDay               = 0.75;

                // Connection to public transit is a negative weight
                double wPublicTransitConnect    = -1.0;

                double legPrivacyScore = basePrivacy                            +
                        wDistance               * distanceScore                 +
                        wSinuosity              * sinuosityScore                +
                        wPedestrianStops        * pedestrianStopsScore          +
                        wFirstLastLeg           * firstLastLegScore             +
                        wDay                    * dayScore                      +
                        wTimeOfDay              * todScore                      +
                        wPublicTransitConnect   * publicTransitConnectionScore;

                // Store factors and weights for debugging
                TravelPrivacyCategoryFactors debug = new TravelPrivacyCategoryFactors();

                debug.basePrivacy           = basePrivacy;
                debug.distanceScore         = distanceScore;
                debug.pedestrianStopsScore  = pedestrianStopsScore;
                debug.ptConnectScore        = publicTransitConnectionScore;
                debug.sinuosityScore        = sinuosityScore;
                debug.firstLastLegScore     = firstLastLegScore;
                debug.dayScore              = dayScore;
                debug.todScore              = todScore;
                debug.wDistanceScore        = wDistance;
                debug.wPedestrianStopsScore = wPedestrianStops;
                debug.wFirstLastLegScore    = wFirstLastLeg;
                debug.wPtConnectScore       = wPublicTransitConnect;
                debug.wSinuosityScore       = wSinuosity;
                debug.wDayScore             = wDay;
                debug.wTimeOfDayScore       = wTimeOfDay;

                leg.setPrivacyCategory(PrivacyCategory.fromPrivacyScore(legPrivacyScore));
                leg.setPrivacyCategoryFactors(debug);
            }


            // Handle private automotive (car, motorcycle, taxi, lowkinemacy) legs
            if (TransportMode.isPrivateAutomotive(leg.getMode())) {

                if (leg.getLegLocs() == null || leg.getLegLocs().isEmpty()) {
                    leg.setPrivacyCategory(PrivacyCategory.UNKNOWN);
                    continue;
                }

                // Distance score [0.0 - 1.0], 3<00m = 0.0, 3000m = 1.0
                double minDistance = 1000;
                double maxDistance = 100000;
                double distanceScore = (geoMetrics.getDistance() - minDistance) / (maxDistance - minDistance);
                distanceScore = Math.min(1, Math.max(0, distanceScore));

                // Sinuosity score [0.0 - 1.0], 1.5 = 0, 3.0 = 1.0
                double sinuosityScore = 0.0;
                if (geoMetrics.getDistance() > minDistance) {
                    double minSinuosity = 1.25;
                    double maxSinuosity = 2.50;
                    sinuosityScore = (geoMetrics.getSinuosity() - minSinuosity) / (maxSinuosity - minSinuosity);
                    sinuosityScore = Math.min(1, Math.max(0, sinuosityScore));
                }

                // Location extraDetails score
                double sumFC = 0;
                double sumSC = 0;
                int nPrivate     = 0;
                int nPaved       = 0;

                int nLocsWithExtras = 0;
                int nFC = 0;
                int nSC = 0;
                for (Location l: leg.getLegLocs()) {
                    if (l.getExtraDetails() != null) {

                        if (l.getExtraDetails().getFunctionalClass().ordinal() > 0) {
                            HERELinkFunctionalClass fc = l.getExtraDetails().getFunctionalClass();
                            sumFC += fc.ordinal();
                            nFC++;
                        }

                        if (l.getExtraDetails().getSpeedCategory().ordinal() > 0) {
                            HERESpeedCategory sc = l.getExtraDetails().getSpeedCategory();
                            sumSC += sc.ordinal();
                            nSC++;
                        }

                        boolean isPaved = l.getExtraDetails().isPaved();
                        boolean isPrivate = l.getExtraDetails().isPrivateRoad();

                        if (isPrivate)
                            nPrivate++;
                        if (isPaved)
                            nPaved++;

                        nLocsWithExtras++;
                    }
                }

                double averageSC = sumSC / (nSC * 1.0);
                double averageFC = sumFC / (nFC * 1.0);

                // Sensitivity for FCs 1-3=0, 3-5 = 0 - 1.0
                double roadFCScore = Math.min(1, Math.max(0, (averageFC - 3) / 2));

                // Sensitivity for SCs 1-5=0, 6-8 = 0 - 1.0
                double roadSCScore = Math.min(1, Math.max(0, (averageSC - 5) / 3));

                // Private roads, 0-5% = 0, 5-15% = 0 - 1.0
                double privateRatio = nPrivate / (nLocsWithExtras * 1.0);
                double privateRoadScore = Math.min(1, Math.max(0, (privateRatio - 0.05) / 0.1));

                // Paved roads not used for now
                // ...

                // Base privacy for private automotive legs
                double basePrivacy              = 0.50;

                // Weights should sum to 4
                double wDistance                = 0.1;
                double wSinuosity               = 0.5;
                double wPrivateRoad             = 0.9;
                double wRoadSCScore             = 0.4;
                double wRoadFCScore             = 0.7;
                double wFirstLastLeg            = 0.2;
                double wDay                     = 0.6;
                double wTimeOfDay               = 0.6;

                double legPrivacyScore = basePrivacy                            +
                        wDistance               * distanceScore                 +
                        wSinuosity              * sinuosityScore                +
                        wPrivateRoad            * privateRoadScore              +
                        wFirstLastLeg           * firstLastLegScore             +
                        wRoadFCScore            * roadFCScore                   +
                        wRoadSCScore            * roadSCScore                   +
                        wDay                    * dayScore                      +
                        wTimeOfDay              * todScore;


                // Store factors and weights for debugging
                TravelPrivacyCategoryFactors debug = new TravelPrivacyCategoryFactors();

                debug.basePrivacy           = basePrivacy;
                debug.distanceScore         = distanceScore;
                debug.roadFCScore           = roadFCScore;
                debug.roadSCScore           = roadSCScore;
                debug.sinuosityScore        = sinuosityScore;
                debug.firstLastLegScore     = firstLastLegScore;
                debug.privateRoadScore      = privateRoadScore;
                debug.dayScore              = dayScore;
                debug.todScore              = todScore;

                debug.wDistanceScore        = wDistance;
                debug.wRoadFCScore          = wRoadFCScore;
                debug.wRoadSCScore          = wRoadSCScore;
                debug.wPrivateRoadScore     = wPrivateRoad;
                debug.wFirstLastLegScore    = wFirstLastLeg;
                debug.wSinuosityScore       = wSinuosity;
                debug.wDayScore             = wDay;
                debug.wTimeOfDayScore       = wTimeOfDay;

                leg.setPrivacyCategory(PrivacyCategory.fromPrivacyScore(legPrivacyScore));
                leg.setPrivacyCategoryFactors(debug);
            }

            // Handle bike legs
            if (leg.getMode().equals(TransportMode.bicycle)) {

                if (leg.getLegLocs() == null || leg.getLegLocs().isEmpty()) {
                    leg.setPrivacyCategory(PrivacyCategory.UNKNOWN);
                    continue;
                }

                // Distance score [0.0 - 1.0], 3<00m = 0.0, 3000m = 1.0
                double minDistance = 500;
                double maxDistance = 10000;
                double distanceScore = (geoMetrics.getDistance() - minDistance) / (maxDistance - minDistance);
                distanceScore = Math.min(1, Math.max(0, distanceScore));

                // Sinuosity score [0.0 - 1.0], 1.5 = 0, 3.0 = 1.0
                double sinuosityScore = 0.0;
                if (geoMetrics.getDistance() > minDistance) {
                    double minSinuosity = 1.33;
                    double maxSinuosity = 2.75;
                    sinuosityScore = (geoMetrics.getSinuosity() - minSinuosity) / (maxSinuosity - minSinuosity);
                    sinuosityScore = Math.min(1, Math.max(0, sinuosityScore));
                }

                // Location extraDetails score
                double sumFC = 0;
                double sumSC = 0;
                int nPrivate = 0;
                int nPaved   = 0;

                int nLocsWithExtras = 0;
                int nFC = 0;
                int nSC = 0;
                for (Location l: leg.getLegLocs()) {
                    if (l.getExtraDetails() != null) {

                        if (l.getExtraDetails().getFunctionalClass().ordinal() > 0) {
                            HERELinkFunctionalClass fc = l.getExtraDetails().getFunctionalClass();
                            sumFC += fc.ordinal();
                            nFC++;
                        }

                        if (l.getExtraDetails().getSpeedCategory().ordinal() > 0) {
                            HERESpeedCategory sc = l.getExtraDetails().getSpeedCategory();
                            sumSC += sc.ordinal();
                            nSC++;
                        }

                        boolean isPaved = l.getExtraDetails().isPaved();
                        boolean isPrivate = l.getExtraDetails().isPrivateRoad();

                        if (isPrivate)
                            nPrivate++;
                        if (isPaved)
                            nPaved++;

                        nLocsWithExtras++;
                    }
                }

                double averageSC = sumSC / (nSC * 1.0);
                double averageFC = sumFC / (nFC * 1.0);

                // Sensitivity for FCs 1-4=0, 5 = 0.5
                double roadFCScore = Math.min(1, Math.max(0, (averageFC - 4) / 2));

                // Sensitivity for SCs 1-6=0, 7-8 = 0 - 1.0
                double roadSCScore = Math.min(1, Math.max(0, (averageSC - 6) / 2));

                // Private roads, 0-5% = 0, 5-15% = 0 - 1.0
                double privateRatio = nPrivate / (nLocsWithExtras * 1.0);
                double privateRoadScore = Math.min(1, Math.max(0, (privateRatio - 0.05) / 0.1));

                // Base privacy for private bike legs
                double basePrivacy              = 0.75;

                // Weights should sum to 4
                double wDistance                = 0.20;
                double wSinuosity               = 0.60;
                double wPrivateRoad             = 1.00;
                double wRoadSCScore             = 0.15;
                double wRoadFCScore             = 0.25;
                double wFirstLastLeg            = 0.40;
                double wDay                     = 0.70;
                double wTimeOfDay               = 0.70;

                double legPrivacyScore = basePrivacy                            +
                        wDistance               * distanceScore                 +
                        wSinuosity              * sinuosityScore                +
                        wPrivateRoad            * privateRoadScore              +
                        wFirstLastLeg           * firstLastLegScore             +
                        wRoadFCScore            * roadFCScore                   +
                        wRoadSCScore            * roadSCScore                   +
                        wDay                    * dayScore                      +
                        wTimeOfDay              * todScore;

                TravelPrivacyCategoryFactors debug = new TravelPrivacyCategoryFactors();

                debug.basePrivacy           = basePrivacy;
                debug.distanceScore         = distanceScore;
                debug.roadFCScore           = roadFCScore;
                debug.roadSCScore           = roadSCScore;
                debug.sinuosityScore        = sinuosityScore;
                debug.firstLastLegScore     = firstLastLegScore;
                debug.privateRoadScore      = privateRoadScore;
                debug.dayScore              = dayScore;
                debug.todScore              = todScore;

                debug.wDistanceScore        = wDistance;
                debug.wRoadFCScore          = wRoadFCScore;
                debug.wRoadSCScore          = wRoadSCScore;
                debug.wPrivateRoadScore     = wPrivateRoad;
                debug.wFirstLastLegScore    = wFirstLastLeg;
                debug.wSinuosityScore       = wSinuosity;
                debug.wDayScore             = wDay;
                debug.wTimeOfDayScore       = wTimeOfDay;

                leg.setPrivacyCategory(PrivacyCategory.fromPrivacyScore(legPrivacyScore));
                leg.setPrivacyCategoryFactors(debug);
            }
        }
    }
}
