import SwiftUI

struct DayCell: View {
    /// Fixed number of period rows. Anything past them is reported as "+N" in the
    /// footer so a busy day can never spill into the rows around it.
    static let barSlots = 3
    static let dotSlots = 4

    struct PeriodBar: Identifiable {
        let id: String
        let color: Color
        let isSegmentStart: Bool
        let isSegmentEnd: Bool
        let isCutDay: Bool
    }

    struct PaymentDot: Identifiable {
        let id: String
        let color: Color
        let ringColor: Color?
        let isSettled: Bool
    }

    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let bars: [PeriodBar]
    let dots: [PaymentDot]
    let hiddenMarkCount: Int
    let accessibilityText: String

    @ScaledMetric(relativeTo: .caption) private var dayNumberSize: CGFloat = 28
    @ScaledMetric(relativeTo: .caption) private var barHeight: CGFloat = 5
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var footerHeight: CGFloat = 11

    private var barsHeight: CGFloat {
        CGFloat(Self.barSlots) * barHeight + CGFloat(Self.barSlots - 1) * 2
    }

    private var cellHeight: CGFloat {
        dayNumberSize + 4 + barsHeight + 3 + footerHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            dayNumber

            Spacer(minLength: 4)

            barsColumn

            Spacer(minLength: 3)

            footerRow
        }
        .frame(height: cellHeight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dayNumber: some View {
        Text("\(day)")
            .font(.caption.weight(isToday || isSelected ? .semibold : .regular))
            .foregroundStyle(dayNumberForeground)
            .frame(width: dayNumberSize, height: dayNumberSize)
            .background {
                if isSelected {
                    Circle().fill(Color.primaryAction)
                } else if isToday {
                    Circle().strokeBorder(Color.primaryAction, lineWidth: 1.5)
                }
            }
    }

    private var dayNumberForeground: Color {
        if isSelected { return .white }
        if isToday { return Color.primaryAction }
        return .primary
    }

    private var barsColumn: some View {
        VStack(spacing: 2) {
            ForEach(bars.prefix(Self.barSlots)) { bar in
                barView(bar)
            }

            ForEach(Array(0..<emptyBarSlots), id: \.self) { _ in
                Color.clear.frame(height: barHeight)
            }
        }
    }

    private var emptyBarSlots: Int {
        max(0, Self.barSlots - min(bars.count, Self.barSlots))
    }

    private func barView(_ bar: PeriodBar) -> some View {
        bar.color
            .opacity(0.45)
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
            .clipShape(barShape(isStart: bar.isSegmentStart, isEnd: bar.isSegmentEnd))
            .overlay(alignment: .trailing) {
                if bar.isCutDay {
                    Capsule()
                        .fill(bar.color)
                        .frame(width: 2.5, height: barHeight)
                }
            }
            .padding(.leading, bar.isSegmentStart ? 2 : 0)
            .padding(.trailing, bar.isSegmentEnd ? 2 : 0)
    }

    private func barShape(isStart: Bool, isEnd: Bool) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 2.5 : 0,
            bottomLeadingRadius: isStart ? 2.5 : 0,
            bottomTrailingRadius: isEnd ? 2.5 : 0,
            topTrailingRadius: isEnd ? 2.5 : 0
        )
    }

    private var footerRow: some View {
        HStack(spacing: 3) {
            ForEach(dots.prefix(Self.dotSlots)) { dot in
                Circle()
                    .fill(dot.color.opacity(dot.isSettled ? 0.4 : 1))
                    .frame(width: dotSize, height: dotSize)
                    .overlay {
                        if let ringColor = dot.ringColor {
                            Circle().strokeBorder(ringColor, lineWidth: 1.5)
                        }
                    }
            }

            if hiddenMarkCount > 0 {
                Text(verbatim: "+\(hiddenMarkCount)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: footerHeight)
    }
}

#Preview {
    HStack(spacing: 4) {
        DayCell(
            day: 5,
            isToday: true,
            isSelected: false,
            bars: [
                .init(id: "a", color: .indigo, isSegmentStart: true, isSegmentEnd: false, isCutDay: false),
                .init(id: "b", color: .green, isSegmentStart: false, isSegmentEnd: true, isCutDay: true),
            ],
            dots: [.init(id: "p", color: .indigo, ringColor: Color.red, isSettled: false)],
            hiddenMarkCount: 0,
            accessibilityText: "5"
        )

        DayCell(
            day: 12,
            isToday: false,
            isSelected: true,
            bars: [
                .init(id: "a", color: .indigo, isSegmentStart: false, isSegmentEnd: false, isCutDay: false),
                .init(id: "b", color: .green, isSegmentStart: false, isSegmentEnd: false, isCutDay: false),
                .init(id: "c", color: .orange, isSegmentStart: false, isSegmentEnd: false, isCutDay: false),
            ],
            dots: [
                .init(id: "p", color: .orange, ringColor: Color.green, isSettled: true),
                .init(id: "q", color: .pink, ringColor: nil, isSettled: false),
            ],
            hiddenMarkCount: 2,
            accessibilityText: "12"
        )

        DayCell(
            day: 20,
            isToday: false,
            isSelected: false,
            bars: [],
            dots: [],
            hiddenMarkCount: 0,
            accessibilityText: "20"
        )
    }
    .padding()
}
