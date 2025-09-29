import SwiftUI

enum Palette {
    static let background = Color(red: 0.94, green: 0.95, blue: 0.98)
    static let surface = Color.white.opacity(0.92)
    static let surfaceMuted = Color.white.opacity(0.75)
    static let accentBlue = Color(red: 0.36, green: 0.5, blue: 0.98)
    static let accentLavender = Color(red: 0.76, green: 0.8, blue: 0.97)
    static let accentCoral = Color(red: 0.97, green: 0.62, blue: 0.64)
    static let textPrimary = Color.black.opacity(0.85)
    static let textSecondary = Color.black.opacity(0.55)
    static let border = Color.black.opacity(0.08)
}

struct SoftCard: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func softCard(padding: CGFloat = 20, cornerRadius: CGFloat = 28) -> some View {
        modifier(SoftCard(padding: padding, cornerRadius: cornerRadius))
    }

    func pillStyle(isSelected: Bool = false) -> some View {
        self
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Palette.accentBlue : Palette.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Palette.accentBlue.opacity(0.6) : Palette.border, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? Color.white : Palette.textPrimary)
    }

    func elevatedIconButton() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 8)
    }
}

struct MetricChip: View {
    var title: String
    var value: String
    var accent: Color = Palette.accentBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

extension Collection where Element: BinaryFloatingPoint {
    var average: Element {
        guard !isEmpty else { return 0 }
        let total = reduce(0, +)
        return total / Element(count)
    }
}
