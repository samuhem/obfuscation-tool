package uk.co.travelai_public.model.place;

import java.util.HashMap;
import java.util.Map;

public enum DwellDurationType {
    brief,  // < 30 minutes
    visit,  // 30min - 2h
    stay,   // 2h+
    sleep;  // 4h+ & nightime

    public static DwellDurationType fromOrdinal(int id) {
        return DwellDurationType.values()[id - 1];
    }

    /**
     * @return time bounds for different DwellDurationTypes as a Map. The value of Map keys is [lower bound, higher bound].
     */
    public static Map<DwellDurationType, int[]> getDwellDurationTypeTimesInMinutes() {

        Map<DwellDurationType, int[]> dwellDurationTypeMinutes = new HashMap<>();

        int[] briefTimeBounds = {0, 30};
        int[] visitTimeBounds = {31, 120};
        int[] stayTimeBounds = {121, Integer.MAX_VALUE};
        int[] sleepTimeBounds = {240, Integer.MAX_VALUE};

        dwellDurationTypeMinutes.put(brief, briefTimeBounds);
        dwellDurationTypeMinutes.put(visit, visitTimeBounds);
        dwellDurationTypeMinutes.put(stay, stayTimeBounds);
        dwellDurationTypeMinutes.put(sleep, sleepTimeBounds);

        return dwellDurationTypeMinutes;
    }



}
