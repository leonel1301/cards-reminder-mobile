import Foundation

enum AppTab: Hashable {
    case timeline
    case calendar
    case cards
    case profile
    case garden

    var analyticsName: String {
        switch self {
        case .timeline: "Timeline"
        case .calendar: "Calendar"
        case .cards: "Cards"
        case .profile: "Profile"
        case .garden: "Things"
        }
    }
}
