import EventKit
import Foundation

struct CalendarExportEvent: Hashable, Sendable {
    let uid: String
    let date: Date
    let title: String
    let notes: String
    let cardName: String
}

enum CalendarExportError: Error {
    case accessDenied
    case noCalendar
}

enum CalendarExportBuilder {
    /// One all-day event per payment that falls in the given month.
    static func events(
        cards: [APICard],
        year: Int,
        month: Int
    ) -> [CalendarExportEvent] {
        let periods = CalendarBillingLogic.paymentsInMonth(
            CalendarBillingLogic.periodsRelevantToMonth(cards: cards, year: year, month: month),
            year: year,
            month: month
        )

        return periods.compactMap { period in
            guard let date = CalendarBillingLogic.paymentDueDate(for: period) else { return nil }

            return CalendarExportEvent(
                uid: uid(cardID: period.cardID, date: date),
                date: date,
                title: String(format: String(localized: "calendar_export_event_title"), period.cardName),
                notes: String(format: String(localized: "calendar_export_event_notes"), period.periodLabel),
                cardName: period.cardName
            )
        }
        .sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.cardName.localizedCompare(rhs.cardName) == .orderedAscending
        }
    }

    static func ics(events: [CalendarExportEvent], calendarName: String = "Waloop") -> String {
        var lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Lenara Labs//Waloop//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:\(escape(calendarName))"
        ]

        let stamp = utcStamp(Date())

        for event in events {
            let start = dateStamp(event.date)
            let end = dateStamp(Calendar.current.date(byAdding: .day, value: 1, to: event.date) ?? event.date)
            lines.append("BEGIN:VEVENT")
            lines.append("UID:\(event.uid)")
            lines.append("DTSTAMP:\(stamp)")
            lines.append("DTSTART;VALUE=DATE:\(start)")
            lines.append("DTEND;VALUE=DATE:\(end)")
            lines.append("SUMMARY:\(escape(event.title))")
            lines.append("DESCRIPTION:\(escape(event.notes))")
            lines.append("BEGIN:VALARM")
            lines.append("ACTION:DISPLAY")
            lines.append("DESCRIPTION:\(escape(event.title))")
            lines.append("TRIGGER:PT9H")
            lines.append("END:VALARM")
            lines.append("END:VEVENT")
        }

        lines.append("END:VCALENDAR")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func writeTemporaryICS(events: [CalendarExportEvent], year: Int, month: Int) throws -> URL {
        let filename = String(format: "Waloop-%04d-%02d.ics", year, month)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let data = Data(ics(events: events).utf8)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func uid(cardID: UUID, date: Date) -> String {
        "waloop-\(cardID.uuidString.lowercased())-\(dateStamp(date))@lenaralabs.com"
    }

    private static func dateStamp(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func utcStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

enum CalendarAppleExporter {
    @MainActor
    static func add(events: [CalendarExportEvent]) async throws -> Int {
        let store = EKEventStore()
        try await requestAccess(store)

        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarExportError.noCalendar
        }

        for event in events {
            let ekEvent = EKEvent(eventStore: store)
            ekEvent.calendar = calendar
            ekEvent.title = event.title
            ekEvent.notes = event.notes
            ekEvent.isAllDay = true
            ekEvent.startDate = Calendar.current.startOfDay(for: event.date)
            ekEvent.endDate = Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: Calendar.current.startOfDay(for: event.date)
            )
            ekEvent.url = AppMetadata.faqURL

            if let reminder = Calendar.current.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: event.date
            ) {
                ekEvent.addAlarm(EKAlarm(absoluteDate: reminder))
            }

            try store.save(ekEvent, span: .thisEvent, commit: false)
        }

        try store.commit()
        return events.count
    }

    @MainActor
    private static func requestAccess(_ store: EKEventStore) async throws {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return
        case .denied, .restricted:
            throw CalendarExportError.accessDenied
        case .notDetermined:
            let granted = try await store.requestWriteOnlyAccessToEvents()
            if !granted { throw CalendarExportError.accessDenied }
        @unknown default:
            throw CalendarExportError.accessDenied
        }
    }
}
