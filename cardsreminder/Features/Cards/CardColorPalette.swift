import SwiftUI

struct CardPaletteOption: Identifiable, Hashable {
    let id: String
    let nameKey: String

    var color: Color { Color(hex: id) }

    var localizedName: String {
        String(localized: String.LocalizationValue(nameKey))
    }

    static let `default` = CardPaletteOption(id: "3B82F6", nameKey: "color_blue")

    static let all: [CardPaletteOption] = [
        CardPaletteOption(id: "3B82F6", nameKey: "color_blue"),
        CardPaletteOption(id: "6366F1", nameKey: "color_indigo"),
        CardPaletteOption(id: "8B5CF6", nameKey: "color_violet"),
        CardPaletteOption(id: "22C55E", nameKey: "color_green"),
        CardPaletteOption(id: "10B981", nameKey: "color_emerald"),
        CardPaletteOption(id: "F97316", nameKey: "color_orange"),
        CardPaletteOption(id: "EF4444", nameKey: "color_red"),
        CardPaletteOption(id: "EC4899", nameKey: "color_pink"),
        CardPaletteOption(id: "EAB308", nameKey: "color_yellow"),
        CardPaletteOption(id: "14B8A6", nameKey: "color_teal"),
        CardPaletteOption(id: "171717", nameKey: "color_black"),
        CardPaletteOption(id: "6B7280", nameKey: "color_gray"),
    ]

    static var defaultHex: String { `default`.id }

    static func matching(hex: String?) -> String? {
        let normalized = normalize(hex)
        return all.first { $0.id == normalized }?.id
    }

    static func normalize(_ hex: String?) -> String {
        (hex ?? "").trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
    }
}

struct CardColorPaletteGrid: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CardPaletteOption.all) { option in
                colorSwatch(option)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorSwatch(_ option: CardPaletteOption) -> some View {
        let isSelected = CardPaletteOption.normalize(selection) == option.id

        return Button {
            selection = option.id
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                        .padding(-3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.localizedName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct DayNumberPicker: View {
    let id: String
    let title: String
    @Binding var selection: Int
    @Binding var expandedPickerID: String?

    private var isExpanded: Bool {
        expandedPickerID == id
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                expandedPickerID = isExpanded ? nil : id
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(selection)")
                        .foregroundStyle(isExpanded ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Picker(title, selection: $selection) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .frame(height: isExpanded ? 150 : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
        }
    }
}
