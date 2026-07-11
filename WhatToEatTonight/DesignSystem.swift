import SwiftUI

enum AppTheme {
    static let orange = Color(red: 1, green: 0.31, blue: 0.03)
    static let pink = Color(red: 1, green: 0.23, blue: 0.39)
    static let green = Color(red: 0.16, green: 0.62, blue: 0.30)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.065, blue: 0.06, alpha: 1)
            : UIColor(red: 0.985, green: 0.977, blue: 0.955, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 1)
            : .white
    })
}

struct AppCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 0.75)
            }
            .shadow(color: .black.opacity(0.055), radius: 8, y: 3)
    }
}

struct SelectedChip: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(selected ? AppTheme.orange.opacity(0.10) : AppTheme.surface, in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).stroke(selected ? AppTheme.orange : .primary.opacity(0.12), lineWidth: selected ? 1.5 : 0.75) }
            .foregroundStyle(selected ? AppTheme.orange : .primary)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension View {
    func appCard(padding: CGFloat = 16) -> some View { modifier(AppCard(padding: padding)) }
    func selectedChip(_ selected: Bool) -> some View { modifier(SelectedChip(selected: selected)) }

    @ViewBuilder
    func appGlassControl(tint: Color? = nil, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: 18))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    func appPrimaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func appSecondaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct FoodIcon: View {
    let emoji: String
    var size: CGFloat = 48

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.58))
            .frame(width: size, height: size)
            .background(AppTheme.orange.opacity(0.10), in: Circle())
            .accessibilityHidden(true)
    }
}

struct ScreenHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension String {
    var ingredientEmoji: String {
        ["鸡蛋": "🥚", "番茄": "🍅", "米饭": "🍚", "面条": "🍜", "鸡肉": "🍗", "牛肉": "🥩", "豆腐": "⬜️", "土豆": "🥔", "洋葱": "🧅", "青菜": "🥬", "蘑菇": "🍄", "虾": "🍤", "奶酪": "🧀", "面包": "🍞"][self] ?? "🥣"
    }
}
