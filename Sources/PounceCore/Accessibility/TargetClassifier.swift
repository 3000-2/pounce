public enum TargetClassifier {
    /// `hasPressAction` is `@autoclosure` so the expensive action query never
    /// runs for roles decided by name alone.
    public static func qualifies(
        role: String,
        hasPressAction: @autoclosure () -> Bool,
        clickableRoles: Set<String>,
        probeRoles: Set<String>
    ) -> Bool {
        if clickableRoles.contains(role) { return true }
        if probeRoles.contains(role) { return hasPressAction() }
        return false
    }
}
