import Combine
import SwiftUI

struct WorldCloudView: View {
    let snapshot: VoxelWorldSnapshot
    var isActive: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var messageIndex = 0
    @State private var drift = false
    @State private var isBlinking = false
    @State private var isPressed = false

    private var messages: [String] {
        snapshot.cloudMessageKeys
    }

    private var currentKey: String {
        guard !messages.isEmpty else { return "cloud_comment_dormant_1" }
        return messages[messageIndex % messages.count]
    }

    private var isNight: Bool {
        colorScheme == .dark
    }

    var body: some View {
        Button(action: advance) {
            VStack(alignment: .trailing, spacing: 6) {
                bubble
                dots
                VoxelCloud(isNight: isNight, isBlinking: isBlinking)
                    .offset(x: drift ? -3 : 3, y: drift ? -4 : 3)
                    .scaleEffect(isPressed ? 0.94 : 1)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .padding(.trailing, 14)
        .onAppear(perform: startIdleMotion)
        .onChange(of: snapshot) { _, _ in
            messageIndex = 0
        }
        .onReceive(Timer.publish(every: 6, on: .main, in: .common).autoconnect()) { _ in
            guard isActive else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                messageIndex += 1
            }
        }
        .onReceive(Timer.publish(every: 3.4, on: .main, in: .common).autoconnect()) { _ in
            blink()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("cloud_accessibility")
        .accessibilityValue(Text(LocalizedStringKey(currentKey)))
        .accessibilityHint("cloud_accessibility_hint")
    }

    private var bubble: some View {
        ZStack(alignment: .topTrailing) {
            Text(LocalizedStringKey(currentKey))
                .font(.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .id(messageIndex)
                .transition(
                    .asymmetric(
                        insertion: .offset(y: 6).combined(with: .opacity),
                        removal: .opacity
                    )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: 196, alignment: .trailing)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var dots: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(messages.count, 1), id: \.self) { index in
                let isCurrent = index == messageIndex % max(messages.count, 1)
                Rectangle()
                    .fill(Color.primary.opacity(isCurrent ? 0.65 : 0.2))
                    .frame(width: isCurrent ? 9 : 4, height: 3)
            }
        }
        .padding(.trailing, 6)
    }

    private func advance() {
        Haptics.lightImpact()
        withAnimation(.spring(duration: 0.32)) {
            messageIndex += 1
            isPressed = true
        }
        withAnimation(.spring(duration: 0.3).delay(0.12)) {
            isPressed = false
        }
    }

    private func startIdleMotion() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
            drift = true
        }
    }

    private func blink() {
        guard isActive, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.08)) { isBlinking = true }
        withAnimation(.easeInOut(duration: 0.08).delay(0.14)) { isBlinking = false }
    }
}

/// A blocky cloud drawn pixel by pixel, to match the voxel world below it.
private struct VoxelCloud: View {
    let isNight: Bool
    let isBlinking: Bool

    private static let cell: CGFloat = 7.5
    private static let shape = [
        "....####....",
        "..#########.",
        ".###########",
        "############",
        ".##########."
    ]
    private static let eyeColumns = [3, 8]
    private static let eyeRow = 2

    private var columns: Int { Self.shape.first?.count ?? 0 }

    var body: some View {
        Canvas { context, _ in
            for (row, pattern) in Self.shape.enumerated() {
                for (column, pixel) in pattern.enumerated() where pixel == "#" {
                    let rect = CGRect(
                        x: CGFloat(column) * Self.cell,
                        y: CGFloat(row) * Self.cell,
                        width: Self.cell,
                        height: Self.cell
                    )
                    context.fill(Path(rect), with: .color(shade(for: row)))
                }
            }

            for column in Self.eyeColumns {
                let height = isBlinking ? Self.cell * 0.3 : Self.cell * 0.9
                let rect = CGRect(
                    x: CGFloat(column) * Self.cell + Self.cell * 0.1,
                    y: CGFloat(Self.eyeRow) * Self.cell + (Self.cell - height) / 2,
                    width: Self.cell * 0.8,
                    height: height
                )
                context.fill(Path(rect), with: .color(eye))
            }
        }
        .frame(
            width: CGFloat(columns) * Self.cell,
            height: CGFloat(Self.shape.count) * Self.cell
        )
        .shadow(color: .black.opacity(isNight ? 0.4 : 0.16), radius: 7, y: 4)
    }

    /// Lit from above: the top rows catch the light, the base stays in shade.
    private func shade(for row: Int) -> Color {
        let last = Self.shape.count - 1
        if isNight {
            switch row {
            case 0, 1: return Color(red: 0.76, green: 0.82, blue: 0.94)
            case last: return Color(red: 0.5, green: 0.56, blue: 0.72)
            default: return Color(red: 0.66, green: 0.73, blue: 0.87)
            }
        }
        switch row {
        case 0, 1: return .white
        case last: return Color(red: 0.85, green: 0.88, blue: 0.93)
        default: return Color(red: 0.95, green: 0.96, blue: 0.98)
        }
    }

    private var eye: Color {
        isNight
            ? Color(red: 0.13, green: 0.15, blue: 0.22)
            : Color(red: 0.18, green: 0.2, blue: 0.25)
    }
}