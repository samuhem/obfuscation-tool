package uk.co.travelai_public.model.HERE;

import java.util.HashMap;
import java.util.Map;

public enum HERESpeedCategory {
    unknown,    // 0
    fast_3,      // > 130km/h
    fast_2,      // 101-130km/h
    fast_1,      // 91-100km/h
    medium_2,    // 71-90km/h
    medium_1,    // 51-70km/h
    slow_3,      // 31-50km/h
    slow_2,      // 11-30km/h
    slow_1;      // < 11km/h

    public static HERESpeedCategory fromOrdinal(int catId) {
        if (catId < 0)
            return HERESpeedCategory.unknown;
        if (catId > HERESpeedCategory.values().length - 1) {
            return HERESpeedCategory.unknown;
        }

        return HERESpeedCategory.values()[catId];
    }

    public Map<HERESpeedCategory, Double[]> getSpeedRanges() {
        Map<HERESpeedCategory, Double[]> speedRanges = new HashMap<>();

        speedRanges.put(unknown,     new Double[]{-1.0, -1.0});
        speedRanges.put(fast_3,      new Double[]{131.0, 9999.0});
        speedRanges.put(fast_2,      new Double[]{101.0, 130.0});
        speedRanges.put(fast_1,      new Double[]{91.0, 100.0});
        speedRanges.put(medium_2,    new Double[]{71.0, 90.0});
        speedRanges.put(medium_1,    new Double[]{51.0, 70.0});
        speedRanges.put(slow_3,      new Double[]{31.0, 50.0});
        speedRanges.put(slow_2,      new Double[]{11.0, 30.0});
        speedRanges.put(slow_1,      new Double[]{0.0, 10.0});

        return speedRanges;
    }
}
