import CoreGraphics

/// DESIGN_SYSTEM.md: "Spacing 4/8/12/16/24/32; Cards Radius 16; Buttons mindestens 44 pt
/// bedienbare Fläche."
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum CornerRadius {
    static let card: CGFloat = 16
}

enum HitTarget {
    static let minimum: CGFloat = 44
}
