package uk.co.travelai_public.model;

import lombok.AllArgsConstructor;

import java.util.HashSet;
import java.util.Set;

/**
 * Representation of a Transportation Mode.
 * OBS! The modes should start from 0 and increase (by 1) for each additional mode.
 * Otherwise fromID() method (and possible other uses elsewhere in code) will break.
 * <p>
 * Created by Michalis on 29/03/2017.
 * Extended by S.Hemminki on 26/03/2018.
 *
 */
@AllArgsConstructor
public enum TransportMode {

    unknown,        // 0
    tilt,           // 1
    stationary,     // 2
    walk,           // 3
    run,            // 4
    bicycle,        // 5
    automotive,     // 6
    bus,            // 7
    train,          // 8
    tram,           // 9
    metro,          // 10
    car,            // 11
    water,          // 12
    aerial,         // 13
    lowkinemacy,    // 14
    highkinemacy,   // 15
    publicTransit,  // 16
    motorbike,      // 17
    taxi;           // 18

    /**
     * @return Set of Modes based on Kinemacy
     */
    public static Set<TransportMode> getModesByKinemacy(TransportMode kinemacy) {
        Set<TransportMode> modes = new HashSet<>();
        if (kinemacy.equals(TransportMode.lowkinemacy)) {
            modes.add(stationary);
            modes.add(bicycle);
            modes.add(automotive);
            modes.add(bus);
            modes.add(train);
            modes.add(tram);
            modes.add(metro);
            modes.add(car);
            modes.add(water);
            modes.add(aerial);
        }
        if (kinemacy.equals(TransportMode.highkinemacy)) {
            modes.add(walk);
            modes.add(run);
        }
        return modes;
    }

    /**
     * Return {@link TransportMode) object matching the input mode
     *
     * @param mode of transportation modality we are trying to match with TransportMode
     * @return {@link TransportMode} corresponding to the input mode
     */
    public static TransportMode fromString(String mode) {
        for (TransportMode tm : TransportMode.values()) {
            if (tm.name().equalsIgnoreCase(mode)) {
                return tm;
            }
        }
        throw new IllegalArgumentException("No matching TransportMode " + mode + " found");
    }

    /**
     * @return {@link TransportMode} object matching the input ID.
     */
    public static TransportMode fromID(int modeID) {
        if (modeID < 0)
            return TransportMode.unknown;
        if (modeID > TransportMode.values().length - 1) {
            return TransportMode.unknown;
        }

        return TransportMode.values()[modeID];
    }

    /**
     * @return boolean indicating if the input TransportMode is automotive
     */
    public static boolean isAutomotive(TransportMode mode) {
        return (mode == TransportMode.automotive ||
                mode == TransportMode.bus ||
                mode == TransportMode.train ||
                mode == TransportMode.metro ||
                mode == TransportMode.tram ||
                mode == TransportMode.car ||
                mode == TransportMode.aerial ||
                mode == TransportMode.water ||
                mode == TransportMode.publicTransit ||
                mode == TransportMode.motorbike ||
                mode == TransportMode.taxi);
    }

    /**
     * @return boolean indicating if the input TransportMode is public transportation
     */
    public static boolean isPublicTransit(TransportMode mode) {
        return (mode == TransportMode.bus ||
                mode == TransportMode.train ||
                mode == TransportMode.metro ||
                mode == TransportMode.tram ||
                mode == TransportMode.aerial ||
                mode == TransportMode.water ||
                mode == TransportMode.publicTransit);
    }

    /**
     * @return boolean indicating if the input TransportMode is private automotive transit
     */
    public static boolean isPrivateAutomotive(TransportMode mode) {
        return (mode == TransportMode.car ||
                mode == TransportMode.motorbike ||
                mode == TransportMode.taxi ||
                mode == TransportMode.lowkinemacy);
    }

    /**
     * @return boolean indicating if the input TransportMode is public transportation
     */
    public static boolean isTransit(TransportMode mode) {
        return (isAutomotive(mode) ||
                isPublicTransit(mode) ||
                mode == TransportMode.bicycle ||
                mode == TransportMode.lowkinemacy);
    }

    @Override
    public String toString() {
        return String.format("TransportMode{order=%s, name=%s}", ordinal(), name());
    }
}
