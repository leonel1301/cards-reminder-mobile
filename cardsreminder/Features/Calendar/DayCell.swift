import SwiftUI

struct DayCell: View {
    let day: Int
    let isToday: Bool
    let bars: [CardBarDisplay]

    struct CardBarDisplay: Identifiable {
        let id: UUID
        let color: Color
        let showBar: Bool
        let isPeriodStart: Bool
        let isPeriodEnd: Bool
        let showPaymentPin: Bool
        let barHighlighted: Bool
        let pinHighlighted: Bool
        let isDimmed: Bool
    }

    var body: some View {
        VStack(spacing: 2) {
            dayNumber

            VStack(spacing: 2) {
                ForEach(bars) { bar in
                    barRow(bar)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 52)
    }

    private var dayNumber: some View {
        Text("\(day)")
            .font(.caption.weight(isToday ? .semibold : .regular))
            .foregroundStyle(isToday ? .white : .primary)
            .frame(width: 28, height: 28)
            .background {
                if isToday {
                    Circle().fill(.blue)
                }
            }
    }

    @ViewBuilder
    private func barRow(_ bar: CardBarDisplay) -> some View {
        ZStack {
            if bar.showBar {
                bar.color
                    .opacity(barOpacity(for: bar, isBar: true))
                    .frame(height: 5)
                    .frame(maxWidth: .infinity)
                    .clipShape(periodBarShape(isStart: bar.isPeriodStart, isEnd: bar.isPeriodEnd))
                    .overlay {
                        if bar.barHighlighted {
                            periodBarShape(isStart: bar.isPeriodStart, isEnd: bar.isPeriodEnd)
                                .stroke(bar.color, lineWidth: 1.5)
                        }
                    }
                    .padding(.leading, bar.isPeriodStart ? 2 : 0)
                    .padding(.trailing, bar.isPeriodEnd ? 2 : 0)
            } else {
                Color.clear.frame(height: 5)
            }

            if bar.showPaymentPin {
                Circle()
                    .fill(bar.color.opacity(bar.isDimmed ? 0.25 : 1))
                    .frame(width: bar.pinHighlighted ? 10 : 8, height: bar.pinHighlighted ? 10 : 8)
                    .overlay {
                        Circle().stroke(.white, lineWidth: bar.pinHighlighted ? 2 : 1.5)
                    }
                    .shadow(color: bar.pinHighlighted ? bar.color.opacity(0.45) : .clear, radius: 3)
            }
        }
        .frame(height: 5)
    }

    private func barOpacity(for bar: CardBarDisplay, isBar: Bool) -> Double {
        if bar.isDimmed { return 0.12 }
        if bar.barHighlighted { return 0.75 }
        return 0.35
    }

    private func periodBarShape(isStart: Bool, isEnd: Bool) -> some Shape {
        UnevenRoundedRectangle(
            topLeadingRadius: isStart ? 2.5 : 0,
            bottomLeadingRadius: isStart ? 2.5 : 0,
            bottomTrailingRadius: isEnd ? 2.5 : 0,
            topTrailingRadius: isEnd ? 2.5 : 0
        )
    }
}
