package uk.co.travelai_public.model;

/**
 * Class containing time-related constants
 */

public class TimeConstants {

    public static final int DAYS_PER_WEEK   = 7;
    public static final int HOURS_PER_DAY   = 24;

    public static final double HOUR_S       = 60 * 60; // One hour in Seconds
    public static final long HOUR_MS        = 60 * 60 * 1000; // One hour in Seconds
    public static final double DAY_S        = 24 * HOUR_S;
    public static final long DAY_MS         = 24 * HOUR_MS;

    // Hour-of-day categories
    public static final int[] NIGHT_HOURS   = {0,1,2,3,4,5};
    public static final int[] MORNING_HOURS = {6,7,8,9,10,11};
    public static final int[] DAY_HOURS     = {12,13,14,15,16,17,18};
    public static final int[] EVENING_HOURS = {19,20,21,22,23};
    public static final int[] PRIVATE_HOURS = {0,1,2,3,4,5,20,21,22,23};

    // Weekday categories
    public static final int[] WORK_DAYS     = {2,3,4,5,6};
    public static final int[] WEEK_END      = {1,7};

}
