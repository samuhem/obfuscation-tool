package uk.co.travelai_public.obfuscation;

import lombok.NoArgsConstructor;
import uk.co.travelai_public.model.place.POI;
import uk.co.travelai_public.model.place.Place;
import uk.co.travelai_public.model.place.PlaceType;
import uk.co.travelai_public.tools.Tools;

import java.util.List;
import java.util.Map;

/**
 * Class containing methods to assess sensitivity of {@link Place}s
 *
 * Author: S.Hemminki
 * Date: 15.2.2020
 */


@NoArgsConstructor
public class PlaceSensitivity {

    /**
     * Assess overall place sensitivity. Run after running other place and dwell analysis functions.
     */
    public void assessPlaceSensitivity(List<Place> places) {

        for (Place p: places) {

            if (p.getPlaceType() != null) {
                if (p.getPlaceType().equals(PlaceType.home)) {
                    p.setPrivacyCategory(PrivacyCategory.PRIVATE);
                    continue;
                }
                if (p.getPlaceType().equals(PlaceType.work)) {
                    p.setPrivacyCategory(PrivacyCategory.PRIVATE);
                    continue;
                }
            }

            double placeFrequency = p.getVisitFrequency();
            double placeRegularity = p.getVisitRegularity();
            double placeDuration = p.getVisitDuration();

            Map<POI, Double> rpPlaceScores = p.getPOIScores();
            Map<POI, Double> topThreePOIs = Tools.getTopThreeRPPlaces(rpPlaceScores);

            // Calculate category sensitivity over all places nearby
            double sensitivityAvrg = 0;
            double norm = 0;
            for (POI poi : p.getPOIScores().keySet()) {
                double weight = Math.pow(p.getPOIScores().get(poi), 2);
                if (poi.getCategorySensitivity() != null) {
                    sensitivityAvrg += poi.getCategorySensitivity().ordinal() * weight;
                    norm += weight; // Use squared for increased weight differentiation
                }
                else {
                    int stophere = 1;
                }
            }
            double categorySensitivityAll = 0;
            if (norm > 0)
                categorySensitivityAll = sensitivityAvrg/norm;

            // Calculate category sensitivity for top three places
            double maxP = 0.0;
            POI mostLikelyPOI = null;
            sensitivityAvrg = 0;
            norm = 0;
            for (POI poi : topThreePOIs.keySet()) {
                double weight = Math.pow(topThreePOIs.get(poi), 2);
                if (poi.getCategorySensitivity() != null) {
                    sensitivityAvrg += poi.getCategorySensitivity().ordinal() * weight;
                    norm += weight;
                    if (topThreePOIs.get(poi) > maxP) {
                        maxP = topThreePOIs.get(poi);
                        mostLikelyPOI = poi;
                    }
                }
            }
            double categorySensitivityTop3 = 0;
            if (norm > 0)
                categorySensitivityTop3 = sensitivityAvrg/norm;

            // Category sensitivity is never below sensitivity of most likely RPPlace
            double mostLikelyPlaceSensitivity = 0;
            double categoryConfidence = 0;
            if (mostLikelyPOI != null) {
                mostLikelyPlaceSensitivity = mostLikelyPOI.getCategorySensitivity().ordinal();
                // match <= 0.5 confidence 0;
                // match > 0.7, confidence 1; linear growth in between
                categoryConfidence = Math.max(0, Math.min(1, (topThreePOIs.get(mostLikelyPOI) - 0.5) * 5));
            }
            double categorySensitivityTop1 = mostLikelyPlaceSensitivity;

            // Overall category sensitivity score; max 3.0.
            double categorySensitivityFused = (categorySensitivityAll + categorySensitivityTop3 + categorySensitivityTop1) / 3;
            categorySensitivityFused = Math.max(1, categorySensitivityFused*categoryConfidence);

            // Frequency score, over 0.25 increases; max increase 1.0.
            double frequencyAdjust = 0;
            if (placeFrequency > 0.25) {
                frequencyAdjust = Math.min(1.0, Math.max(0, placeFrequency));
            }

            // Regularity score, over 0.5 increases by 0.33-0.83; only applies if frequency >= 0.2. Max 0.83.
            double regularityAdjust = 0;
            if (placeFrequency >= 0.2) {
                regularityAdjust = 0.33 + Math.max(0, placeRegularity - 0.5);
            }

            // Duration score, over 2h increases. Every 20min = 0.1. Max 1.0.
            double durationAdjust = Math.min(1, (Math.max(0, (placeDuration - 1.5*60*60)) / (20*60)) * 0.1);

            // Each over-night visit increases; each sleep increases by 0.5. Max 2.0.
            double sleepAdjust = Math.min(2, p.getNSleepVisits() * 0.5);

            double privacyScore = categorySensitivityFused + regularityAdjust + frequencyAdjust + durationAdjust + sleepAdjust;
            if (Double.isNaN(privacyScore))
                privacyScore = 0;

            p.setPrivacyCategory(PrivacyCategory.fromPrivacyScore(privacyScore));

        }
    }
}
