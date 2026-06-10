import CoreGraphics

public enum OutlinePolicy {
    /// Quiet at rest and when the match is already unique (it's about to fire);
    /// outlines appear exactly when several candidates remain and the user needs
    /// to see which element each badge owns.
    public static func framesToOutline(
        badges: [LaidOutBadge],
        typed: String,
        minCandidatesToShow: Int = 2
    ) -> [CGRect] {
        guard !typed.isEmpty else { return [] }
        let matching = badges.filter { $0.label.hasPrefix(typed) }
        guard matching.count >= minCandidatesToShow else { return [] }
        return matching.map(\.elementFrame)
    }
}
