import SwiftUI

struct DashboardSummaryBanner: View {
    let summary: DashboardSummary

    private var parts: [String] {
        var items: [String] = []
        if summary.overdue > 0 {
            items.append(String(format: String(localized: "dashboard_overdue_count"), summary.overdue))
        }
        if summary.urgent > 0 {
            items.append(String(format: String(localized: "dashboard_urgent_count"), summary.urgent))
        }
        if summary.dueSoon > 0 {
            items.append(String(format: String(localized: "dashboard_due_soon_count"), summary.dueSoon))
        }
        return items
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.amberStateForeground)

            Text(parts.joined(separator: " · "))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.amberStateBackground.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    DashboardSummaryBanner(summary: DashboardSummary(
        total: 4,
        overdue: 1,
        urgent: 2,
        dueSoon: 1,
        paid: 0,
        optimalDay: 0,
        onTrack: 0
    ))
    .padding()
}
