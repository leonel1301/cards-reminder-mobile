import Foundation
import Testing
@testable import cardsreminder

struct TreeHealthTests {
    @Test func blankDashboardIsDormant() {
        let health = TreeHealth(summary: nil)
        #expect(health.stage == .dormant)

        let empty = TreeHealth(
            summary: DashboardSummary(total: 0, overdue: 0, urgent: 0, dueSoon: 0, paid: 0, optimalDay: 0, onTrack: 0)
        )
        #expect(empty.stage == .dormant)
    }

    @Test func overdueCardsLookWithered() {
        let health = TreeHealth(
            summary: DashboardSummary(total: 3, overdue: 2, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 0, onTrack: 0)
        )
        #expect(health.stage == .withered)
        #expect(health.score < 0.3)
    }

    @Test func allCardsPaidLooksThriving() {
        let health = TreeHealth(
            summary: DashboardSummary(total: 4, overdue: 0, urgent: 0, dueSoon: 0, paid: 4, optimalDay: 0, onTrack: 0)
        )
        #expect(health.stage == .thriving)
        #expect(health.score == 1)
    }

    @Test func mixedOnTrackLooksHealthyOrGrowing() {
        let health = TreeHealth(
            summary: DashboardSummary(total: 4, overdue: 0, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 1, onTrack: 2)
        )
        #expect(health.stage == .healthy || health.stage == .thriving)
        #expect(health.score > 0.8)
    }
}

struct VoxelWorldSnapshotTests {
    @Test func paidCardsBecomeTreesAndOverdueStarvesAnimals() {
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 4, overdue: 2, urgent: 0, dueSoon: 0, paid: 3, optimalDay: 0, onTrack: 0),
            unlockedAnimals: Array(VoxelAnimalKind.allCases.prefix(5))
        )
        #expect(snapshot.treeCount == 3)
        #expect(snapshot.starvedAnimalCount == 2)
        #expect(snapshot.livingAnimalCount == 3)
        #expect(snapshot.unlockedAnimalKinds.count == 5)
    }

    @Test func allPaidKeepsAnimalsAlive() {
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 2, overdue: 0, urgent: 0, dueSoon: 0, paid: 2, optimalDay: 0, onTrack: 0),
            unlockedAnimals: Array(VoxelAnimalKind.allCases.prefix(4))
        )
        #expect(snapshot.treeCount == 2)
        #expect(snapshot.starvedAnimalCount == 0)
        #expect(snapshot.livingAnimalCount == 4)
    }

    @Test func lifetimePaymentCountBecomesTreeCount() {
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 4, overdue: 0, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 0, onTrack: 3),
            unlockedAnimals: Array(VoxelAnimalKind.allCases.prefix(2)),
            paymentCount: 7
        )
        #expect(snapshot.treeCount == 7)
    }

    @Test func treeCountCapsAtTen() {
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 4, overdue: 0, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 0, onTrack: 3),
            unlockedAnimals: [],
            paymentCount: 30
        )
        #expect(snapshot.treeCount == VoxelWorldSnapshot.maxTreeCount)
    }

    @Test func hungryWorldPutsHungryCloudMessageFirst() {
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 3, overdue: 1, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 0, onTrack: 0),
            unlockedAnimals: Array(VoxelAnimalKind.allCases.prefix(2))
        )
        #expect(snapshot.cloudMessageKeys.first == "cloud_comment_hungry")
    }

    @Test func onlyUnlockedAnimalsAppearInTheSnapshot() {
        let unlocked: [VoxelAnimalKind] = [.sheep, .cow]
        let snapshot = VoxelWorldSnapshot(
            summary: DashboardSummary(total: 1, overdue: 0, urgent: 0, dueSoon: 0, paid: 1, optimalDay: 0, onTrack: 0),
            unlockedAnimals: unlocked
        )
        #expect(snapshot.unlockedAnimalKinds == unlocked)
        #expect(snapshot.livingAnimalCount == 2)
    }
}

struct VoxelWorldRecipeTests {
    @Test func seedZeroKeepsTheClassicMeadowAndLake() {
        let recipe = VoxelWorldRecipe.make(seed: 0)
        #expect(recipe == .classic)
        #expect(recipe.biome == .meadow)
        #expect(recipe.isLake(6, 6))
        #expect(recipe.isLake(9, 9))
        #expect(!recipe.isLake(5, 6))
        #expect(recipe.isShore(5, 6))
    }

    @Test func biomeFollowsTheSeedDeterministically() {
        #expect(VoxelWorldRecipe.make(seed: 1).biome == .desert)
        #expect(VoxelWorldRecipe.make(seed: 2).biome == .grove)
        #expect(VoxelWorldRecipe.make(seed: 3).biome == .highlands)
        #expect(VoxelWorldRecipe.make(seed: 4).biome == .meadow)
        #expect(VoxelWorldRecipe.make(seed: 1) == VoxelWorldRecipe.make(seed: 1))
    }

    @Test func rebuildAlwaysChangesTheSoilType() {
        let next = VoxelWorldRecipe.nextSeed(after: 0, draw: { 0 })
        #expect(next != 0)
        #expect(VoxelWorldRecipe.make(seed: next).biome != .meadow)
    }

    @Test func snapshotCountsDoNotDependOnTheWorldSeed() {
        let summary = DashboardSummary(
            total: 4, overdue: 1, urgent: 0, dueSoon: 0, paid: 3, optimalDay: 0, onTrack: 0
        )
        let unlocked = Array(VoxelAnimalKind.allCases.prefix(5))
        let snapshot = VoxelWorldSnapshot(summary: summary, unlockedAnimals: unlocked)
        #expect(snapshot.treeCount == 3)
        #expect(snapshot.livingAnimalCount == 4)
        #expect(snapshot.starvedAnimalCount == 1)

        _ = VoxelWorldRecipe.nextSeed(after: 0)
        let again = VoxelWorldSnapshot(summary: summary, unlockedAnimals: unlocked)
        #expect(again.treeCount == snapshot.treeCount)
        #expect(again.livingAnimalCount == snapshot.livingAnimalCount)
        #expect(again.starvedAnimalCount == snapshot.starvedAnimalCount)
        #expect(again.unlockedAnimalKinds == snapshot.unlockedAnimalKinds)
    }
}

struct CardsListArrangementTests {
    private static let aliceOwner = UUID()
    private static let bobOwner = UUID()

    private static func card(
        _ name: String,
        lastFour: String = "0000",
        issuer: String? = nil,
        paymentDueDay: Int = 5,
        owner: UUID = aliceOwner
    ) -> APICard {
        APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: owner,
            name: name,
            lastFourDigits: lastFour,
            issuer: issuer,
            billingCycleDay: 15,
            paymentDueDay: paymentDueDay,
            colorHex: "6366F1",
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private static func status(_ raw: String, daysUntilPayment: Int = 5, daysOverdue: Int = 0) -> APICardStatus {
        APICardStatus(
            status: raw,
            cycleStart: .now,
            cycleEnd: .now,
            paymentDueDate: .now,
            daysUntilPayment: daysUntilPayment,
            daysOverdue: daysOverdue,
            optimalPurchaseDay: 16,
            isOptimalPurchaseDay: false,
            isPaidThisCycle: raw == "paid"
        )
    }

    @Test func urgencySortPutsOverdueFirstAndPaidLast() {
        let paid = Self.card("Aaa")
        let overdue = Self.card("Zzz")
        let onTrack = Self.card("Mmm")

        let statuses: [UUID: APICardStatus] = [
            paid.id: Self.status("paid"),
            overdue.id: Self.status("overdue", daysOverdue: 2),
            onTrack.id: Self.status("on_track"),
        ]

        let sorted = CardsListArrangement.apply(
            CardsListQuery(sortOrder: .urgency),
            to: [paid, overdue, onTrack]
        ) { statuses[$0] }

        #expect(sorted.map(\.name) == ["Zzz", "Mmm", "Aaa"])
    }

    @Test func cardsWithoutStatusSortAfterTheOnesThatHaveIt() {
        let known = Self.card("Con estado")
        let unknown = Self.card("Sin estado")
        let statuses = [known.id: Self.status("paid")]

        let sorted = CardsListArrangement.apply(
            CardsListQuery(sortOrder: .urgency),
            to: [unknown, known]
        ) { statuses[$0] }

        #expect(sorted.map(\.name) == ["Con estado", "Sin estado"])
    }

    @Test func urgencyTiesBreakByRemainingDaysThenName() {
        let soonest = Self.card("Zzz")
        let latest = Self.card("Aaa")

        let statuses: [UUID: APICardStatus] = [
            soonest.id: Self.status("due_soon", daysUntilPayment: 1),
            latest.id: Self.status("due_soon", daysUntilPayment: 4),
        ]

        let sorted = CardsListArrangement.apply(
            CardsListQuery(sortOrder: .urgency),
            to: [latest, soonest]
        ) { statuses[$0] }

        #expect(sorted.map(\.name) == ["Zzz", "Aaa"])
    }

    @Test func searchMatchesNameIssuerAndLastFourDigits() {
        let cards = [
            Self.card("Visa Oro", lastFour: "4532", issuer: "Banco X"),
            Self.card("Falabella", lastFour: "8821", issuer: "CMR"),
        ]

        func names(searching text: String) -> [String] {
            CardsListArrangement.apply(CardsListQuery(searchText: text), to: cards) { _ in nil }
                .map(\.name)
        }

        #expect(names(searching: "visa") == ["Visa Oro"])
        #expect(names(searching: "cmr") == ["Falabella"])
        #expect(names(searching: "8821") == ["Falabella"])
        #expect(names(searching: "  ") == ["Falabella", "Visa Oro"])
    }

    @Test func statusAndOwnerFiltersNarrowTheList() {
        let mine = Self.card("Mía", owner: Self.aliceOwner)
        let theirs = Self.card("Suya", owner: Self.bobOwner)
        let statuses: [UUID: APICardStatus] = [
            mine.id: Self.status("overdue", daysOverdue: 1),
            theirs.id: Self.status("paid"),
        ]

        let byStatus = CardsListArrangement.apply(
            CardsListQuery(statusFilter: .kind(.overdue)),
            to: [mine, theirs]
        ) { statuses[$0] }
        #expect(byStatus.map(\.name) == ["Mía"])

        let byOwner = CardsListArrangement.apply(
            CardsListQuery(ownerID: Self.bobOwner),
            to: [mine, theirs]
        ) { statuses[$0] }
        #expect(byOwner.map(\.name) == ["Suya"])
    }

    @Test func statusCountsGroupByKindAndSkipUnknownCards() {
        let overdue = Self.card("A")
        let alsoOverdue = Self.card("B")
        let unknown = Self.card("C")
        let statuses: [UUID: APICardStatus] = [
            overdue.id: Self.status("overdue", daysOverdue: 1),
            alsoOverdue.id: Self.status("overdue", daysOverdue: 3),
        ]

        let counts = CardsListArrangement.statusCounts(for: [overdue, alsoOverdue, unknown]) { statuses[$0] }

        #expect(counts[.overdue] == 2)
        #expect(counts[.paid] == nil)
    }

    @Test func clearingRefinementsKeepsTheChosenSortOrder() {
        var query = CardsListQuery(
            searchText: "visa",
            statusFilter: .kind(.paid),
            ownerID: Self.aliceOwner,
            sortOrder: .name
        )
        #expect(query.isRefined)

        query.clearRefinements()

        #expect(!query.isRefined)
        #expect(query.sortOrder == .name)
    }
}

@MainActor
struct TimelineEventBuilderTests {
    private static func card(name: String, isActive: Bool = true) -> APICard {
        APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: name,
            lastFourDigits: "4532",
            issuer: nil,
            billingCycleDay: 15,
            paymentDueDay: 5,
            colorHex: "6366F1",
            notes: nil,
            isActive: isActive,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private static func entry(
        name: String,
        status rawStatus: String,
        daysUntilPayment: Int = 10,
        daysOverdue: Int = 0,
        isPaid: Bool = false,
        isActive: Bool = true
    ) -> DashboardCardEntry {
        DashboardCardEntry(
            card: card(name: name, isActive: isActive),
            status: APICardStatus(
                status: rawStatus,
                cycleStart: .now,
                cycleEnd: .now.addingTimeInterval(15 * 86_400),
                paymentDueDate: .now.addingTimeInterval(Double(daysUntilPayment) * 86_400),
                daysUntilPayment: daysUntilPayment,
                daysOverdue: daysOverdue,
                optimalPurchaseDay: 16,
                isOptimalPurchaseDay: false,
                isPaidThisCycle: isPaid
            )
        )
    }

    @Test func settledAndHealthyCardsLandInTheirOwnSection() {
        let result = TimelineEventBuilder.build(from: [
            Self.entry(name: "Overdue", status: "overdue", daysOverdue: 3),
            Self.entry(name: "Paid", status: "paid", isPaid: true),
            Self.entry(name: "Fine", status: "on_track"),
        ])

        let allClear = result.sections.first { $0.kind == .allClear }
        #expect(allClear?.events.map(\.card.name).sorted() == ["Fine", "Paid"])

        let attention = result.sections.first { $0.kind == .attention }
        #expect(attention?.events.map(\.card.name) == ["Overdue"])
    }

    @Test func theFeaturedCardIsNotRepeatedInTheSections() {
        let featured = Self.entry(name: "Featured", status: "on_track")
        let other = Self.entry(name: "Other", status: "on_track")

        let result = TimelineEventBuilder.build(
            from: [featured, other],
            excludingCardID: featured.card.id
        )

        let names = result.sections.flatMap { $0.events.map(\.card.name) }
        #expect(names == ["Other"])
    }

    @Test func inactiveCardsNeverReachTheTimeline() {
        let result = TimelineEventBuilder.build(from: [
            Self.entry(name: "Archived", status: "overdue", daysOverdue: 2, isActive: false),
        ])

        #expect(result.sections.isEmpty)
    }

    @Test func theMostUrgentEventsComeFirst() {
        let result = TimelineEventBuilder.build(from: [
            Self.entry(name: "DueSoon", status: "due_soon", daysUntilPayment: 6),
            Self.entry(name: "Overdue", status: "overdue", daysOverdue: 1),
            Self.entry(name: "Today", status: "urgent", daysUntilPayment: 0),
            Self.entry(name: "Urgent", status: "urgent", daysUntilPayment: 2),
        ])

        let attention = result.sections.first { $0.kind == .attention }
        #expect(attention?.events.map(\.card.name) == ["Overdue", "Today", "Urgent", "DueSoon"])
    }

    @Test func onlyEventsWithSomethingOutstandingCanBePaid() {
        let result = TimelineEventBuilder.build(from: [
            Self.entry(name: "Overdue", status: "overdue", daysOverdue: 3),
            Self.entry(name: "Paid", status: "paid", isPaid: true),
            Self.entry(name: "Fine", status: "on_track"),
        ])

        let payable = result.sections
            .flatMap(\.events)
            .filter(\.canMarkPaid)
            .map(\.card.name)

        #expect(payable == ["Overdue"])
    }
}

@MainActor
struct CalendarGridLayoutTests {
    /// The grid used to assume weeks start on Sunday while the header row followed the
    /// locale, which shifted every date by one column outside the US.
    @Test func everyDayLandsUnderItsOwnWeekdayColumn() {
        let calendar = Calendar.current

        for month in 1...12 {
            let slots = CalendarBillingLogic.generateCalendarDays(year: 2026, month: month)

            for (index, day) in slots.enumerated() {
                guard let day else { continue }

                var components = DateComponents()
                components.year = 2026
                components.month = month
                components.day = day
                guard let date = calendar.date(from: components) else {
                    Issue.record("Could not build \(day)/\(month)/2026")
                    continue
                }

                let weekday = calendar.component(.weekday, from: date)
                let expectedColumn = (weekday - calendar.firstWeekday + 7) % 7
                #expect(index % 7 == expectedColumn)
            }
        }
    }

    @Test func gridKeepsEveryDayAndFillsCompleteWeeks() {
        let slots = CalendarBillingLogic.generateCalendarDays(year: 2026, month: 2)

        #expect(slots.count % 7 == 0)
        #expect(slots.compactMap { $0 } == Array(1...28))
    }
}

@MainActor
struct CalendarMonthBuilderTests {
    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? .now
    }

    private static func card(billingCycleDay: Int = 15, paymentDueDay: Int = 5) -> APICard {
        APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: "Visa",
            lastFourDigits: "4532",
            issuer: nil,
            billingCycleDay: billingCycleDay,
            paymentDueDay: paymentDueDay,
            colorHex: "6366F1",
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
    }

    private static func status(
        paymentDueDate: Date,
        daysOverdue: Int = 0,
        isPaid: Bool = false,
        optimalPurchaseDay: Int = 16
    ) -> APICardStatus {
        APICardStatus(
            status: isPaid ? "paid" : "on_track",
            cycleStart: paymentDueDate.addingTimeInterval(-30 * 86_400),
            cycleEnd: paymentDueDate.addingTimeInterval(-10 * 86_400),
            paymentDueDate: paymentDueDate,
            daysUntilPayment: 3,
            daysOverdue: daysOverdue,
            optimalPurchaseDay: optimalPurchaseDay,
            isOptimalPurchaseDay: false,
            isPaidThisCycle: isPaid
        )
    }

    @Test func periodBarsCoverTheCycleAndMarkTheCutDay() {
        let card = Self.card()
        let period = CalendarBillingLogic.makePeriod(card: card, startYear: 2026, startMonth: 1)

        let contents = CalendarMonthBuilder.build(
            cards: [card],
            periods: [period],
            year: 2026,
            month: 2,
            status: { _ in nil },
            referenceDate: Self.date(2026, 6, 1)
        )

        #expect(contents[1]?.periods.count == 1)
        #expect(contents[15]?.periods.first?.isCutDay == true)
        #expect(contents[14]?.periods.first?.isCutDay == false)
        #expect(contents[16] == nil)
    }

    @Test func paymentLandsOnItsDueDay() {
        let card = Self.card()
        let period = CalendarBillingLogic.makePeriod(card: card, startYear: 2026, startMonth: 1)

        let contents = CalendarMonthBuilder.build(
            cards: [card],
            periods: [period],
            year: 2026,
            month: 3,
            status: { _ in nil },
            referenceDate: Self.date(2026, 1, 1)
        )

        #expect(contents[5]?.payments.count == 1)
        #expect(contents[5]?.payments.first?.state == .upcoming)
    }

    @Test func paymentInTheTrackedCycleUsesTheDashboardState() {
        let card = Self.card()
        let period = CalendarBillingLogic.makePeriod(card: card, startYear: 2026, startMonth: 1)
        let dueDate = Self.date(2026, 3, 5)
        let reference = Self.date(2026, 3, 10)

        #expect(
            CalendarMonthBuilder.paymentState(
                for: period,
                status: Self.status(paymentDueDate: dueDate, isPaid: true),
                referenceDate: reference
            ) == .paid
        )

        #expect(
            CalendarMonthBuilder.paymentState(
                for: period,
                status: Self.status(paymentDueDate: dueDate, daysOverdue: 5),
                referenceDate: reference
            ) == .overdue
        )

        #expect(
            CalendarMonthBuilder.paymentState(
                for: period,
                status: Self.status(paymentDueDate: dueDate),
                referenceDate: reference
            ) == .due
        )
    }

    @Test func paymentOutsideTheTrackedCycleFallsBackToTheCalendar() {
        let card = Self.card()
        let period = CalendarBillingLogic.makePeriod(card: card, startYear: 2026, startMonth: 1)

        #expect(
            CalendarMonthBuilder.paymentState(
                for: period,
                status: nil,
                referenceDate: Self.date(2026, 8, 1)
            ) == .past
        )

        #expect(
            CalendarMonthBuilder.paymentState(
                for: period,
                status: nil,
                referenceDate: Self.date(2026, 1, 1)
            ) == .upcoming
        )
    }

    @Test func optimalPurchaseDayOnlyShowsOnTheMonthThatContainsToday() {
        let card = Self.card()
        let cardStatus = Self.status(paymentDueDate: Self.date(2026, 6, 5), optimalPurchaseDay: 16)
        let reference = Self.date(2026, 6, 10)

        let currentMonth = CalendarMonthBuilder.build(
            cards: [card],
            periods: [],
            year: 2026,
            month: 6,
            status: { _ in cardStatus },
            referenceDate: reference
        )
        #expect(currentMonth[16]?.optimalPurchaseCardNames == [card.name])

        let otherMonth = CalendarMonthBuilder.build(
            cards: [card],
            periods: [],
            year: 2026,
            month: 7,
            status: { _ in cardStatus },
            referenceDate: reference
        )
        #expect(otherMonth.isEmpty)
    }
}

struct ProfileInitialsTests {
    @Test func fullNameUsesFirstAndLastWord() {
        #expect(ProfileInitials.resolve(name: "Leonel Ortega", email: nil) == "LO")
        #expect(ProfileInitials.resolve(name: "ana maria de la cruz", email: nil) == "AC")
    }

    @Test func singleWordNameUsesOneLetter() {
        #expect(ProfileInitials.resolve(name: "Leonel", email: "z@example.com") == "L")
    }

    @Test func emailFillsInWhenThereIsNoName() {
        #expect(ProfileInitials.resolve(name: nil, email: "leonel@example.com") == "L")
        #expect(ProfileInitials.resolve(name: "   ", email: "ana@example.com") == "A")
    }

    @Test func nonLetterCharactersAreSkipped() {
        #expect(ProfileInitials.resolve(name: "42 Robles", email: nil) == "R")
        #expect(ProfileInitials.resolve(name: nil, email: "1234@example.com") == "E")
    }

    @Test func nothingUsableReturnsEmpty() {
        #expect(ProfileInitials.resolve(name: nil, email: nil).isEmpty)
        #expect(ProfileInitials.resolve(name: "", email: "").isEmpty)
    }
}

@MainActor
struct CalendarWeekLayoutTests {
    @Test func weekAlwaysHasSevenDaysStartingOnTheLocaleFirstWeekday() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 16
        let date = calendar.date(from: components) ?? .now

        let days = CalendarBillingLogic.datesInWeek(containing: date)

        #expect(days.count == 7)
        #expect(calendar.component(.weekday, from: days[0]) == calendar.firstWeekday)
        #expect(days.contains(where: { calendar.isDate($0, inSameDayAs: date) }))
    }
}

@MainActor
struct CalendarExportBuilderTests {
    @Test func monthExportIncludesEachCardsPaymentDay() {
        let card = APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: "Visa",
            lastFourDigits: "4532",
            issuer: nil,
            billingCycleDay: 15,
            paymentDueDay: 5,
            colorHex: "6366F1",
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )

        let events = CalendarExportBuilder.events(cards: [card], year: 2026, month: 8)

        #expect(events.count == 1)
        #expect(events[0].cardName == "Visa")
        #expect(Calendar.current.component(.day, from: events[0].date) == 5)
        #expect(Calendar.current.component(.month, from: events[0].date) == 8)
    }

    @Test func icsContainsStableUIDAndSummary() {
        let cardID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let event = CalendarExportEvent(
            uid: "waloop-\(cardID.uuidString.lowercased())-20260805@lenaralabs.com",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 5)) ?? .now,
            title: "Pay Visa",
            notes: "Billing period: 15 jul – 14 ago",
            cardName: "Visa"
        )

        let ics = CalendarExportBuilder.ics(events: [event])

        #expect(ics.contains("BEGIN:VCALENDAR"))
        #expect(ics.contains("UID:waloop-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee-20260805@lenaralabs.com"))
        #expect(ics.contains("SUMMARY:Pay Visa"))
        #expect(ics.contains("DTSTART;VALUE=DATE:20260805"))
        #expect(ics.contains("DTEND;VALUE=DATE:20260806"))
    }
}
