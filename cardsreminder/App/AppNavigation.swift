import Foundation
import SwiftUI

@Observable
@MainActor
final class AppNavigation {
    var selectedTab: AppTab = .timeline
    var showCreateCard = false
    var showLearn = false
    var learnLessonID: String?

    func openCreateCard() {
        showCreateCard = true
    }

    func openLearn(lessonID: String? = nil) {
        learnLessonID = lessonID
        showLearn = true
    }

    func openGarden() {
        selectedTab = .garden
    }
}
