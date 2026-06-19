import SwiftUI

struct TimelineSummaryStrip: View {
    let summary: DashboardSummary
    let revealDelay: Double
    var isRevealed: Bool

    private var chips: [(label: String, color: Color, background: Color)] {
        var items: [(String, Color, Color)] = []

        if summary.overdue > 0 {
            items.append((
                String(format: String(localized: "dashboard_overdue_count"), summary.overdue),
                Color.redStateForeground,
                Color.redStateBackground
            ))
        }
        if summary.urgent > 0 {
            items.append((
                String(format: String(localized: "dashboard_urgent_count"), summary.urgent),
                Color.amberStateForeground,
                Color.amberStateBackground
            ))
        }
        if summary.dueSoon > 0 {
            items.append((
                String(format: String(localized: "dashboard_due_soon_count"), summary.dueSoon),
                Color.violetStateForeground,
                Color.violetStateBackground
            ))
        }
        if summary.optimalDay > 0 {
            items.append((
                String(format: String(localized: "timeline_summary_optimal_count"), summary.optimalDay),
                Color.violetStateForeground,
                Color.violetStateBackground
            ))
        }
        if summary.paid > 0, items.isEmpty {
            items.append((
                String(format: String(localized: "timeline_summary_paid_count"), summary.paid),
                Color.emeraldStateForeground,
                Color.emeraldStateBackground
            ))
        }

        return items
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
                    Text(chip.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(chip.color)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(chip.background.opacity(0.85))
                        .clipShape(Capsule())
                        .opacity(isRevealed ? 1 : 0)
                        .offset(y: isRevealed ? 0 : 8)
                        .animation(
                            SmoothRevealAnimation.motion.delay(revealDelay + SmoothRevealAnimation.staggerDelay(for: index)),
                            value: isRevealed
                        )
                }
            }
            .padding(.horizontal, 16)
        }
        .opacity(chips.isEmpty ? 0 : 1)
        .frame(height: chips.isEmpty ? 0 : nil)
    }
}

#Preview {
    TimelineSummaryStrip(
        summary: DashboardSummary(
            total: 4,
            overdue: 1,
            urgent: 1,
            dueSoon: 1,
            paid: 0,
            optimalDay: 1,
            onTrack: 1
        ),
        revealDelay: 0,
        isRevealed: true
    )
}
