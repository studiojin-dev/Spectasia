import SwiftUI

// MARK: - Gypsum Design Tokens

/// Gypsum color palette - modern, polished, matte finish
public enum GypsumColor {
    // Primary colors
    public static let primary = Color(red: 0.1, green: 0.1, blue: 0.15)       // Deep slate
    public static let secondary = Color(red: 0.95, green: 0.95, blue: 0.97)   // Off-white

    // Accent colors
    public static let accent = Color(red: 0.2, green: 0.5, blue: 0.9)        // Ocean blue
    public static let accentHover = Color(red: 0.3, green: 0.6, blue: 1.0)

    // Semantic colors
    public static let background = Color(red: 0.97, green: 0.97, blue: 0.98)
    public static let surface = Color.white
    public static let border = Color(red: 0.85, green: 0.85, blue: 0.87)
    public static let text = Color(red: 0.15, green: 0.15, blue: 0.2)
    public static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.55)
}

/// Gypsum typography system
public enum GypsumFont {
    public static let largeTitle = Font.system(size: 28, weight: .bold)
    public static let title = Font.system(size: 22, weight: .semibold)
    public static let headline = Font.system(size: 17, weight: .semibold)
    public static let body = Font.system(size: 15, weight: .regular)
    public static let caption = Font.system(size: 13, weight: .regular)
}

/// Gypsum shadow system - soft, subtle
public enum GypsumShadow {
    public static let card = [
        Shadow.color: Color.black.opacity(0.05),
        Shadow.radius: 8,
        Shadow.x: 0,
        Shadow.y: 2
    ] as [String: Any]

    public static let button = [
        Shadow.color: Color.black.opacity(0.1),
        Shadow.radius: 4,
        Shadow.x: 0,
        Shadow.y: 1
    ] as [String: Any]
}

// MARK: - Gypsum Components

/// Gypsum-styled container with matte finish
public struct GypsumContainer: View {
    let padding: CGFloat
    let background: Color

    public init(padding: CGFloat = 16, background: Color = GypsumColor.surface) {
        self.padding = padding
        self.background = background
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(background)
                .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
    }
}

/// Gypsum button with subtle bevel and press effect
public struct GypsumButton: View {
    let title: String
    let action: () -> Void
    let style: ButtonStyle

    public enum ButtonStyle {
        case primary
        case secondary
    }

    public init(title: String, style: ButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(GypsumFont.headline)
                .foregroundColor(style == .primary ? .white : GypsumColor.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(backgroundStyle)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        Group {
            if style == .primary {
                GypsumColor.primary
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else {
                GypsumColor.background
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GypsumColor.border, lineWidth: 1)
                    )
            }
        }
    }
}

/// Gypsum card with elevated surface
public struct GypsumCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(GypsumColor.surface)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Preview

#Preview("Gypsum Components") {
    VStack(spacing: 20) {
        GypsumCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gypsum Card")
                    .font(GypsumFont.title)
                    .foregroundColor(GypsumColor.text)
                Text("Modern, polished design with matte finish and subtle shadows.")
                    .font(GypsumFont.body)
                    .foregroundColor(GypsumColor.textSecondary)
            }
        }

        HStack(spacing: 12) {
            GypsumButton(title: "Primary", style: .primary) {}
            GypsumButton(title: "Secondary", style: .secondary) {}
        }
    }
    .padding()
    .background(GypsumColor.background)
}
