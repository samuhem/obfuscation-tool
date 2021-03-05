package uk.co.travelai_public.model.place;

import java.time.LocalTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class OpenHours {

    public class OpenClose {
        public LocalTime openTime;
        public LocalTime closeTime;
    }

    enum Weekday {
        monday,
        tuesday,
        wednesday,
        thursday,
        friday,
        saturday,
        sunday
    }

    private Map<Weekday, List<OpenClose>> openHours = new HashMap<>();
}
