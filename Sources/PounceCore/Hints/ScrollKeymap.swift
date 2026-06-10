public enum ScrollCommand: Equatable {
    /// Unit steps; positive dy scrolls up (toward earlier content), positive
    /// dx scrolls left — CGEvent wheel conventions.
    case line(dx: Int, dy: Int)
    case halfPage(up: Bool)
    case edge(top: Bool)
}

public enum ScrollKeymap {
    public static func command(for character: String) -> ScrollCommand? {
        switch character {
        case "j": return .line(dx: 0, dy: -1)
        case "k": return .line(dx: 0, dy: 1)
        case "h": return .line(dx: 1, dy: 0)
        case "l": return .line(dx: -1, dy: 0)
        case "d": return .halfPage(up: false)
        case "u": return .halfPage(up: true)
        case "g": return .edge(top: true)
        case "G": return .edge(top: false)
        default: return nil
        }
    }
}
