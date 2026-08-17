import SwiftUI

struct TreeGlyph: View {
    let health: TreeHealth

    var body: some View {
        Canvas { context, size in
            let inset = size.width * 0.08
            let globe = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)

            context.fill(Path(ellipseIn: globe), with: .color(health.oceanColor))

            let landWidth = globe.width * (0.38 + health.canopyScale * 0.12)
            let land = CGRect(
                x: globe.midX - landWidth * 0.15,
                y: globe.midY - landWidth * 0.35,
                width: landWidth,
                height: landWidth * 0.7
            )
            context.fill(Path(ellipseIn: land), with: .color(health.landColor))

            if health.stage != .withered && health.stage != .dormant {
                let cap = CGRect(
                    x: globe.midX - globe.width * 0.18,
                    y: globe.minY + globe.height * 0.04,
                    width: globe.width * 0.36,
                    height: globe.height * 0.16
                )
                context.fill(Path(ellipseIn: cap), with: .color(Color.white.opacity(0.85)))
            }

            let highlight = globe.insetBy(dx: globe.width * 0.22, dy: globe.height * 0.28)
                .offsetBy(dx: -globe.width * 0.12, dy: -globe.height * 0.12)
            context.fill(Path(ellipseIn: highlight), with: .color(Color.white.opacity(0.22)))
        }
        .accessibilityHidden(true)
    }
}
