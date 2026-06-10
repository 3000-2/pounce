import CoreGraphics

/// All rects are bottom-left-origin view coordinates.
public struct BadgePlacement: Equatable {
    public let id: Int
    public let label: String
    public let elementFrame: CGRect
    public let size: CGSize

    public init(id: Int, label: String, elementFrame: CGRect, size: CGSize) {
        self.id = id
        self.label = label
        self.elementFrame = elementFrame
        self.size = size
    }
}

public struct LayoutConfig {
    public var gap: CGFloat = 2
    /// Fraction of the badge that protrudes past the element's top-right
    /// corner. 0.5 would center the badge on the corner; 0 tucks it fully
    /// inside.
    public var cornerOverhang: CGFloat = 0.35
    /// Give up nudging past this distance and accept the least-bad overlap —
    /// a slightly overlapping badge beats one that drifted away from its owner.
    public var maxNudge: CGFloat = 60
    public var bounds: CGRect = .infinite

    public init() {}
}

public struct LaidOutBadge: Equatable {
    public let id: Int
    public let label: String
    public let box: CGRect
    public let elementFrame: CGRect

    public init(id: Int, label: String, box: CGRect, elementFrame: CGRect) {
        self.id = id
        self.label = label
        self.box = box
        self.elementFrame = elementFrame
    }
}

public enum BadgeLayout {
    /// Deterministic and order-stable: earlier placements never move, so the
    /// layout is computed once per activation and typing only filters —
    /// survivors never jump.
    public static func resolve(
        _ placements: [BadgePlacement],
        config: LayoutConfig = LayoutConfig()
    ) -> [LaidOutBadge] {
        var placed: [CGRect] = []
        return placements.map { placement in
            let frame = placement.elementFrame
            let inset = 0.5 - config.cornerOverhang
            let center = CGPoint(
                x: frame.maxX - placement.size.width * inset,
                y: frame.maxY - placement.size.height * inset
            )
            let anchor = CGRect(
                x: center.x - placement.size.width / 2,
                y: center.y - placement.size.height / 2,
                width: placement.size.width,
                height: placement.size.height
            )
            var box = deCollide(anchor, against: placed, config: config)
            box = clamp(box, into: config.bounds)
            placed.append(box)
            return LaidOutBadge(
                id: placement.id, label: placement.label,
                box: box, elementFrame: placement.elementFrame
            )
        }
    }

    private static func deCollide(_ start: CGRect, against placed: [CGRect], config: LayoutConfig) -> CGRect {
        func blocker(of rect: CGRect) -> CGRect? {
            placed.first { $0.insetBy(dx: -config.gap, dy: -config.gap).intersects(rect) }
        }
        guard blocker(of: start) != nil else { return start }

        // Down first: vertical stacking reads as a list and stays in the
        // element's column. Down = -y in bottom-left-origin coords.
        var box = start
        while let hit = blocker(of: box), start.maxY - box.maxY <= config.maxNudge {
            let shift = box.maxY - (hit.minY - config.gap)
            guard shift > 0 else { break }
            box.origin.y -= shift
        }
        if blocker(of: box) == nil, start.maxY - box.maxY <= config.maxNudge { return box }

        box = start
        while let hit = blocker(of: box), box.minX - start.minX <= config.maxNudge {
            let shift = (hit.maxX + config.gap) - box.minX
            guard shift > 0 else { break }
            box.origin.x += shift
        }
        if blocker(of: box) == nil, box.minX - start.minX <= config.maxNudge { return box }

        return start
    }

    private static func clamp(_ box: CGRect, into bounds: CGRect) -> CGRect {
        guard bounds != .infinite, !bounds.isNull else { return box }
        var clamped = box
        clamped.origin.x = min(max(box.minX, bounds.minX), bounds.maxX - box.width)
        clamped.origin.y = min(max(box.minY, bounds.minY), bounds.maxY - box.height)
        return clamped
    }
}
