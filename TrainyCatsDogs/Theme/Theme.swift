import SwiftUI

/// Единый визуальный стиль приложения: акцентные цвета, фон, карточки.
enum Theme {
    static let accent = Color(red: 0.29, green: 0.53, blue: 0.95)
    static let accentSecondary = Color(red: 0.62, green: 0.36, blue: 0.95)

    static let accentGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = Color(uiColor: .systemGroupedBackground)

    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: .secondarySystemGroupedBackground) : .white
    }
}

/// Карточка со скруглёнными углами и мягкой тенью — базовый строительный блок дизайна.
private struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.cardBackground(colorScheme),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.06), radius: 10, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
