import SwiftUI

enum SmoothRevealAnimation {
    static let duration: Double = 0.45

    static var motion: Animation {
        .smooth(duration: duration)
    }

    static var transition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.88))
    }

    static var sectionTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.98))
    }

    static func staggerDelay(for index: Int) -> Double {
        Double(index) * 0.05
    }
}
