import SwiftUI

struct CalendarWeekList: View {
    let dates: [Date]
    let contents: [Date: CalendarDayContent]
    let selectedDate: Date?
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(dates, id: \.self) { date in
                let start = Calendar.current.startOfDay(for: date)
                row(
                    date: date,
                    content: contents[start] ?? CalendarDayContent(),
                    isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false
                )
            }
        }
        .padding(12)
        .sectionCard(cornerRadius: 16)
        .padding(.horizontal, 16)
    }

    private func row(date: Date, content: CalendarDayContent, isSelected: Bool) -> some View {
        let isToday = Calendar.current.isDateInToday(date)

        return Button {
            Haptics.selection()
            onSelect(date)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                dayBadge(date: date, isToday: isToday, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 6) {
                    if content.isEmpty {
                        Text("calendar_day_empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(content.payments.prefix(3)) { payment in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(payment.color)
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle().strokeBorder(payment.state.accentColor, lineWidth: 1.5)
                                    }

                                Text(payment.cardName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                Text(payment.state.labelKey)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(payment.state.accentColor)
                            }
                        }

                        if content.payments.count > 3 {
                            Text("+\(content.payments.count - 3)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }

                        if !content.optimalPurchaseCardNames.isEmpty {
                            Label("calendar_day_optimal_title", systemImage: "sparkles")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.violetStateForeground)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                isSelected
                    ? Color.primaryAction.opacity(0.08)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func dayBadge(date: Date, isToday: Bool, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("\(Calendar.current.component(.day, from: date))")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background {
                    if isSelected {
                        Circle().fill(Color.primaryAction)
                    } else if isToday {
                        Circle().strokeBorder(Color.primaryAction, lineWidth: 1.5)
                    }
                }
        }
        .frame(width: 48)
        .accessibilityHidden(true)
    }
}
