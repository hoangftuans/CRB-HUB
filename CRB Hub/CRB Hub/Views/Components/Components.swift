import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = CRBTheme.Colors.cyan
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: CRBTheme.Spacing.sm) {
            HStack(spacing: CRBTheme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(CRBTheme.Typography.caption())
                    .foregroundColor(CRBTheme.Colors.muted)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(CRBTheme.Colors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(CRBTheme.Colors.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(padding: CRBTheme.Spacing.lg)
    }
}

// MARK: - Gradient Button
struct GradientButton: View {
    let title: String
    var icon: String? = nil
    var isDisabled: Bool = false
    var style: ButtonStyle = .primary
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, destructive
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: CRBTheme.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CRBTheme.Spacing.md)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
            .overlay(overlayView)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            CRBTheme.Gradients.primary
        case .secondary:
            Color.white.opacity(0.08)
        case .destructive:
            CRBTheme.Colors.error.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return Color(hex: 0x06121F)
        case .secondary:
            return CRBTheme.Colors.ink
        case .destructive:
            return CRBTheme.Colors.error
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        switch style {
        case .primary:
            EmptyView()
        case .secondary:
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .stroke(CRBTheme.Colors.cardBorder, lineWidth: 1)
        case .destructive:
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .stroke(CRBTheme.Colors.error.opacity(0.4), lineWidth: 1)
        }
    }
}

// MARK: - CRB Amount View
struct CRBAmountView: View {
    let baseUnits: UInt64
    var style: AmountStyle = .large
    var showSymbol: Bool = true
    
    enum AmountStyle {
        case large, medium, small
    }
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(CRBUnits.formatCRB(baseUnits))
                .font(amountFont)
                .foregroundColor(CRBTheme.Colors.ink)
            
            if showSymbol {
                Text("CRB")
                    .font(symbolFont)
                    .foregroundColor(CRBTheme.Colors.cyan)
            }
        }
    }
    
    private var amountFont: Font {
        switch style {
        case .large: return CRBTheme.Typography.monoLarge()
        case .medium: return .system(size: 20, weight: .bold, design: .monospaced)
        case .small: return .system(size: 14, weight: .semibold, design: .monospaced)
        }
    }
    
    private var symbolFont: Font {
        switch style {
        case .large: return .system(size: 18, weight: .bold)
        case .medium: return .system(size: 14, weight: .bold)
        case .small: return .system(size: 11, weight: .bold)
        }
    }
}

// MARK: - Loading View
struct LoadingView: View {
    var message: String = "Loading..."
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: CRBTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(CRBTheme.Colors.cardBorder, lineWidth: 3)
                    .frame(width: 44, height: 44)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        CRBTheme.Gradients.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            Text(message)
                .font(CRBTheme.Typography.caption())
                .foregroundColor(CRBTheme.Colors.muted)
        }
        .onAppear { isAnimating = true }
    }
}

// MARK: - QR Code View
struct QRCodeView: View {
    let data: String
    var size: CGFloat = 200
    
    var body: some View {
        if let image = generateQRCode(from: data) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: CRBTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                        .stroke(CRBTheme.Colors.cyan.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: CRBTheme.Colors.cyan.opacity(0.2), radius: 20)
        } else {
            RoundedRectangle(cornerRadius: CRBTheme.Radius.md)
                .fill(CRBTheme.Colors.cardBackground)
                .frame(width: size, height: size)
                .overlay(
                    Text("QR Error")
                        .foregroundColor(CRBTheme.Colors.error)
                )
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Create colored QR code (cyan on dark background)
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = scaledImage
        colorFilter.color0 = CIColor(color: UIColor(CRBTheme.Colors.background))
        colorFilter.color1 = CIColor(color: UIColor(CRBTheme.Colors.cyan))
        
        guard let coloredImage = colorFilter.outputImage,
              let cgImage = context.createCGImage(coloredImage, from: coloredImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: CRBTheme.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CRBTheme.Colors.cyan)
            }
            
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(CRBTheme.Colors.ink)
            
            Spacer()
        }
        .padding(.leading, 4)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: CRBTheme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(CRBTheme.Gradients.primary)
            
            Text(title)
                .font(CRBTheme.Typography.headline())
                .foregroundColor(CRBTheme.Colors.ink)
            
            Text(message)
                .font(CRBTheme.Typography.body())
                .foregroundColor(CRBTheme.Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, CRBTheme.Spacing.xxl)
        }
        .padding(.vertical, CRBTheme.Spacing.xxl * 2)
    }
}

// MARK: - Pill Badge
struct PillBadge: View {
    let text: String
    var color: Color = CRBTheme.Colors.cyan
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
