package uk.co.travelai_public.obfuscation;

public enum PrivacyCategory {
    UNKNOWN,
    PUBLIC,
    SENSITIVE,
    PRIVATE;

    public static PrivacyCategory fromOrdinal(int id) {
        return PrivacyCategory.values()[id];
    }

    /**
     * Return PlacePrivacySensitivity value from double privacyScore
     * @param privacyScore
     * @return
     */
    public static PrivacyCategory fromPrivacyScore(double privacyScore) {
        int privacyId = Math.min(Math.max(0, (int)Math.round(privacyScore)), 3);

        return PrivacyCategory.fromOrdinal(privacyId);
    }
}
