import SwiftUI

struct FinanceFeelingButton: View {
    let feeling: DashboardFeeling
    @Binding var isExplanationPresented: Bool

    var body: some View {
        Button {
            Haptics.lightImpact()
            isExplanationPresented = true
        } label: {
            HStack(spacing: 5) {
                FeelingIcon(feeling: feeling)

                Text(LocalizedStringKey(feeling.wordKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .modifier(FeelingButtonStyle())
        .accessibilityHint(Text("finance_feeling_accessibility_hint"))
        .sheet(isPresented: $isExplanationPresented) {
            FeelingExplanationSheet(feeling: feeling)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct FeelingButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .buttonStyle(.glass)
                .controlSize(.small)
        } else {
            content
                .buttonStyle(.plain)
                .controlSize(.small)
        }
    }
}

private struct FeelingIcon: View {
    let feeling: DashboardFeeling

    var body: some View {
        Image(systemName: feeling.iconName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(feeling.accentColor)
            .symbolEffect(.pulse, options: feeling.usesAttentionPulse ? .repeating.speed(0.45) : .nonRepeating)
    }
}

private struct FeelingExplanationSheet: View {
    let feeling: DashboardFeeling

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: feeling.iconName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(feeling.accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 72, height: 72)
                        .background(feeling.accentColor.opacity(0.14))
                        .clipShape(Circle())
                        .padding(.top, 8)

                    VStack(spacing: 8) {
                        Text(LocalizedStringKey(feeling.wordKey))
                            .font(.title2.bold())

                        Text(LocalizedStringKey(feeling.headlineKey))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("finance_feeling_why_title")
                            .font(.headline)

                        ForEach(Array(feeling.reasonLines.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)

                                Text(line)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .navigationTitle("finance_feeling_sheet_title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FinanceFeelingButton(
        feeling: DashboardFeeling(
            summary: DashboardSummary(
                total: 4,
                overdue: 1,
                urgent: 1,
                dueSoon: 0,
                paid: 0,
                optimalDay: 0,
                onTrack: 2
            )
        ),
        isExplanationPresented: .constant(false)
    )
    .padding()
}
