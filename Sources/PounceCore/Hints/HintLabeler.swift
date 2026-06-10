public enum HintLabeler {
    /// Home-row-first ordering so the most frequent (shortest) hints land on the
    /// strongest fingers.
    public static let defaultKeys: [Character] = Array("fjdkslaghrueiwovbncmxztyqp")

    /// Produces `count` prefix-free hint strings: no hint is a prefix of another,
    /// so a completed hint is always unambiguous. Shorter hints come first.
    public static func generate(count: Int, keys: [Character] = defaultKeys) -> [String] {
        precondition(keys.count >= 2, "need at least two hint keys")
        guard count > 0 else { return [] }

        var leaves = keys.map(String.init)
        var expanded = 0
        while leaves.count - expanded < count {
            let parent = leaves[expanded]
            expanded += 1
            for key in keys { leaves.append(parent + String(key)) }
        }
        return Array(leaves[expanded...].prefix(count))
    }
}
