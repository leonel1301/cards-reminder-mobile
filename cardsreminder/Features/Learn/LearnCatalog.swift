import Foundation

enum LearnTrack: String, CaseIterable, Identifiable, Hashable {
    case basics
    case intermediate
    case advanced
    case benefits
    case banks

    var id: String { rawValue }

    var titleKey: String { "learn_track_\(rawValue)_title" }
    var subtitleKey: String { "learn_track_\(rawValue)_subtitle" }
    var iconName: String {
        switch self {
        case .basics: "1.circle.fill"
        case .intermediate: "2.circle.fill"
        case .advanced: "3.circle.fill"
        case .benefits: "hand.thumbsup.fill"
        case .banks: "building.columns.fill"
        }
    }
}

struct LearnLesson: Identifiable, Hashable {
    let id: String
    let track: LearnTrack
    let iconName: String
    let titleKey: String
    let summaryKey: String
    let bodyKey: String
}

enum LearnCatalog {
    static let lessons: [LearnLesson] = [
        LearnLesson(
            id: "basic_what_is_credit",
            track: .basics,
            iconName: "creditcard.fill",
            titleKey: "learn_lesson_basic_what_title",
            summaryKey: "learn_lesson_basic_what_summary",
            bodyKey: "learn_lesson_basic_what_body"
        ),
        LearnLesson(
            id: "basic_billing_cycle",
            track: .basics,
            iconName: "calendar",
            titleKey: "learn_lesson_basic_cycle_title",
            summaryKey: "learn_lesson_basic_cycle_summary",
            bodyKey: "learn_lesson_basic_cycle_body"
        ),
        LearnLesson(
            id: "basic_statement_vs_due",
            track: .basics,
            iconName: "calendar.badge.clock",
            titleKey: "learn_lesson_basic_dates_title",
            summaryKey: "learn_lesson_basic_dates_summary",
            bodyKey: "learn_lesson_basic_dates_body"
        ),
        LearnLesson(
            id: "basic_credit_limit",
            track: .basics,
            iconName: "dollarsign.circle.fill",
            titleKey: "learn_lesson_basic_limit_title",
            summaryKey: "learn_lesson_basic_limit_summary",
            bodyKey: "learn_lesson_basic_limit_body"
        ),
        LearnLesson(
            id: "mid_grace_period",
            track: .intermediate,
            iconName: "hourglass",
            titleKey: "learn_lesson_mid_grace_title",
            summaryKey: "learn_lesson_mid_grace_summary",
            bodyKey: "learn_lesson_mid_grace_body"
        ),
        LearnLesson(
            id: "mid_interest",
            track: .intermediate,
            iconName: "percent",
            titleKey: "learn_lesson_mid_interest_title",
            summaryKey: "learn_lesson_mid_interest_summary",
            bodyKey: "learn_lesson_mid_interest_body"
        ),
        LearnLesson(
            id: "mid_minimum_payment",
            track: .intermediate,
            iconName: "exclamationmark.triangle.fill",
            titleKey: "learn_lesson_mid_minimum_title",
            summaryKey: "learn_lesson_mid_minimum_summary",
            bodyKey: "learn_lesson_mid_minimum_body"
        ),
        LearnLesson(
            id: "mid_optimal_day",
            track: .intermediate,
            iconName: "sparkles",
            titleKey: "learn_lesson_mid_optimal_title",
            summaryKey: "learn_lesson_mid_optimal_summary",
            bodyKey: "learn_lesson_mid_optimal_body"
        ),
        LearnLesson(
            id: "adv_utilization",
            track: .advanced,
            iconName: "chart.bar.fill",
            titleKey: "learn_lesson_adv_util_title",
            summaryKey: "learn_lesson_adv_util_summary",
            bodyKey: "learn_lesson_adv_util_body"
        ),
        LearnLesson(
            id: "adv_multi_card",
            track: .advanced,
            iconName: "rectangle.stack.fill",
            titleKey: "learn_lesson_adv_multi_title",
            summaryKey: "learn_lesson_adv_multi_summary",
            bodyKey: "learn_lesson_adv_multi_body"
        ),
        LearnLesson(
            id: "adv_rewards_vs_interest",
            track: .advanced,
            iconName: "gift.fill",
            titleKey: "learn_lesson_adv_rewards_title",
            summaryKey: "learn_lesson_adv_rewards_summary",
            bodyKey: "learn_lesson_adv_rewards_body"
        ),
        LearnLesson(
            id: "adv_revolving",
            track: .advanced,
            iconName: "arrow.triangle.2.circlepath",
            titleKey: "learn_lesson_adv_revolving_title",
            summaryKey: "learn_lesson_adv_revolving_summary",
            bodyKey: "learn_lesson_adv_revolving_body"
        ),
        LearnLesson(
            id: "benefits_protection",
            track: .benefits,
            iconName: "shield.fill",
            titleKey: "learn_lesson_benefits_protection_title",
            summaryKey: "learn_lesson_benefits_protection_summary",
            bodyKey: "learn_lesson_benefits_protection_body"
        ),
        LearnLesson(
            id: "benefits_float",
            track: .benefits,
            iconName: "clock.fill",
            titleKey: "learn_lesson_benefits_float_title",
            summaryKey: "learn_lesson_benefits_float_summary",
            bodyKey: "learn_lesson_benefits_float_body"
        ),
        LearnLesson(
            id: "benefits_credit",
            track: .benefits,
            iconName: "chart.line.uptrend.xyaxis",
            titleKey: "learn_lesson_benefits_credit_title",
            summaryKey: "learn_lesson_benefits_credit_summary",
            bodyKey: "learn_lesson_benefits_credit_body"
        ),
        LearnLesson(
            id: "banks_interchange",
            track: .banks,
            iconName: "arrow.left.arrow.right",
            titleKey: "learn_lesson_banks_interchange_title",
            summaryKey: "learn_lesson_banks_interchange_summary",
            bodyKey: "learn_lesson_banks_interchange_body"
        ),
        LearnLesson(
            id: "banks_interest",
            track: .banks,
            iconName: "banknote.fill",
            titleKey: "learn_lesson_banks_interest_title",
            summaryKey: "learn_lesson_banks_interest_summary",
            bodyKey: "learn_lesson_banks_interest_body"
        ),
        LearnLesson(
            id: "banks_fees",
            track: .banks,
            iconName: "doc.text.fill",
            titleKey: "learn_lesson_banks_fees_title",
            summaryKey: "learn_lesson_banks_fees_summary",
            bodyKey: "learn_lesson_banks_fees_body"
        ),
        LearnLesson(
            id: "banks_incentives",
            track: .banks,
            iconName: "eye.fill",
            titleKey: "learn_lesson_banks_incentives_title",
            summaryKey: "learn_lesson_banks_incentives_summary",
            bodyKey: "learn_lesson_banks_incentives_body"
        )
    ]

    static func lessons(in track: LearnTrack) -> [LearnLesson] {
        lessons.filter { $0.track == track }
    }

    static func lesson(id: String) -> LearnLesson? {
        lessons.first { $0.id == id }
    }
}

enum LearnProgressStore {
    private static let legacyStorageKey = "learnCompletedLessonIDs"

    static func storageKey(forUserID userID: String) -> String {
        "learnCompletedLessonIDs.\(userID)"
    }

    static func cachedRaw(forUserID userID: String) -> String {
        let defaults = UserDefaults.standard
        let key = storageKey(forUserID: userID)
        if let scoped = defaults.string(forKey: key) {
            return scoped
        }

        // One-time move of pre-account cache into the first signed-in user only.
        let legacy = defaults.string(forKey: legacyStorageKey) ?? ""
        guard !legacy.isEmpty else { return "" }
        defaults.set(legacy, forKey: key)
        defaults.removeObject(forKey: legacyStorageKey)
        return legacy
    }

    static func setCachedRaw(_ raw: String, forUserID userID: String) {
        UserDefaults.standard.set(raw, forKey: storageKey(forUserID: userID))
    }

    static func ids(forUserID userID: String) -> Set<String> {
        ids(from: cachedRaw(forUserID: userID))
    }

    static func ids(from raw: String) -> Set<String> {
        Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    static func raw(from ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    static func totalCompleted(raw: String) -> Int {
        ids(from: raw).count
    }

    static func completedCount(in track: LearnTrack, raw: String) -> Int {
        let ids = ids(from: raw)
        return LearnCatalog.lessons(in: track).filter { ids.contains($0.id) }.count
    }
}
