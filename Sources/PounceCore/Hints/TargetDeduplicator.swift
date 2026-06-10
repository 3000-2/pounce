import CoreGraphics

public struct DedupConfig {
    /// Edges within this many points are the same edge — absorbs AX sub-pixel
    /// jitter without merging a 16pt close button into its tab.
    public var positionTolerance: CGFloat = 2
    /// A container is collapsed only when one child fills at least this fraction
    /// of its area; a tab holding both a label and a close X stays untouched.
    public var containmentAreaRatio: CGFloat = 0.9

    public init() {}
}

public enum TargetDeduplicator {
    /// Order-preserving: the first occurrence survives, so it keeps the shortest
    /// hint label. Must run BEFORE labeling — short hints shouldn't be spent on
    /// duplicates.
    public static func deduplicate(
        _ targets: [HintTarget],
        pressEquivalent: (HintTarget, HintTarget) -> Bool,
        config: DedupConfig = DedupConfig()
    ) -> [HintTarget] {
        var unique: [HintTarget] = []
        for target in targets {
            let isDuplicate = unique.contains {
                nearlyEqual($0.frame, target.frame, tolerance: config.positionTolerance)
            }
            if !isDuplicate { unique.append(target) }
        }

        var droppedIndices = Set<Int>()
        for (outerIndex, outer) in unique.enumerated() {
            for inner in unique where inner.id != outer.id {
                if contains(outer.frame, inner.frame,
                            areaRatio: config.containmentAreaRatio,
                            tolerance: config.positionTolerance),
                   pressEquivalent(outer, inner) {
                    droppedIndices.insert(outerIndex)
                    break
                }
            }
        }
        return unique.enumerated()
            .filter { !droppedIndices.contains($0.offset) }
            .map(\.element)
    }

    static func nearlyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance
            && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance
            && abs(a.height - b.height) <= tolerance
    }

    static func contains(_ outer: CGRect, _ inner: CGRect, areaRatio: CGFloat, tolerance: CGFloat) -> Bool {
        guard outer.insetBy(dx: -tolerance, dy: -tolerance).contains(inner) else { return false }
        let outerArea = outer.width * outer.height
        guard outerArea > 0 else { return false }
        return (inner.width * inner.height) / outerArea >= areaRatio
    }
}
