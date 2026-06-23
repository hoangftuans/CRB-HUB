import SwiftUI

// MARK: - CRB Design System
// Inspired by the Cereblix website dark theme

enum CRBTheme {
    
    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: 0x0A0E1C)
        static let backgroundSecondary = Color(hex: 0x0F1730)
        static let cardBackground = Color(hex: 0x141C38).opacity(0.55)
        static let cardBorder = Color(hex: 0x1D2B50)
        
        static let cyan = Color(hex: 0x22D3EE)
        static let violet = Color(hex: 0xA78BFA)
        static let ink = Color(hex: 0xDCE8FF)
        static let muted = Color(hex: 0x8A9BC4)
        
        static let success = Color(hex: 0x9FF5C9)
        static let warning = Color(hex: 0xFFC777)
        static let error = Color(hex: 0xFF6B6B)
        static let info = Color(hex: 0x7FDCFF)
        
        static let sellRed = Color(hex: 0xFF4D6A)
        static let buyGreen = Color(hex: 0x22D37E)
        
        // Opacity variants
        static let cyanGlow = Color(hex: 0x22D3EE).opacity(0.16)
        static let violetGlow = Color(hex: 0xA78BFA).opacity(0.16)
    }
    
    // MARK: - Gradients
    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.cyan, Colors.violet],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        static let card = LinearGradient(
            colors: [
                Color(hex: 0x141C38).opacity(0.55),
                Color(hex: 0x0F1730).opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let backgroundRadial = RadialGradient(
            colors: [Colors.cyanGlow, .clear],
            center: .topTrailing,
            startRadius: 100,
            endRadius: 500
        )
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
    }
    
    // MARK: - Typography
    enum Typography {
        static func largeTitle() -> Font {
            .system(size: 30, weight: .heavy, design: .rounded)
        }
        static func title() -> Font {
            .system(size: 22, weight: .bold, design: .rounded)
        }
        static func headline() -> Font {
            .system(size: 17, weight: .semibold)
        }
        static func body() -> Font {
            .system(size: 15, weight: .regular)
        }
        static func caption() -> Font {
            .system(size: 13, weight: .medium)
        }
        static func mono() -> Font {
            .system(size: 13, weight: .medium, design: .monospaced)
        }
        static func monoLarge() -> Font {
            .system(size: 36, weight: .bold, design: .monospaced)
        }
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: UInt64, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - View Modifiers

struct GlassCard: ViewModifier {
    var padding: CGFloat = CRBTheme.Spacing.xl
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(CRBTheme.Gradients.card)
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CRBTheme.Radius.lg)
                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

struct GradientText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(CRBTheme.Gradients.primary)
    }
}

extension View {
    func glassCard(padding: CGFloat = CRBTheme.Spacing.xl) -> some View {
        modifier(GlassCard(padding: padding))
    }
    
    func gradientText() -> some View {
        modifier(GradientText())
    }
    
    func crbBackground() -> some View {
        self
            .background(CRBTheme.Colors.background)
            .background(
                ZStack {
                    RadialGradient(
                        colors: [CRBTheme.Colors.cyanGlow, .clear],
                        center: UnitPoint(x: 0.78, y: -0.08),
                        startRadius: 100,
                        endRadius: 500
                    )
                    RadialGradient(
                        colors: [CRBTheme.Colors.violetGlow, .clear],
                        center: UnitPoint(x: 0.04, y: 0.02),
                        startRadius: 100,
                        endRadius: 450
                    )
                }
            )
    }
}
