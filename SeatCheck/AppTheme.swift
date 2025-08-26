import SwiftUI

// MARK: - App Theme
struct AppTheme {
    // MARK: - Colors
    struct Colors {
        // Primary Colors
        static let primary = Color.blue
        static let primaryLight = Color.blue.opacity(0.8)
        static let primaryDark = Color.blue.opacity(1.2)
        
        // Secondary Colors
        static let secondary = Color.gray
        static let secondaryLight = Color.gray.opacity(0.3)
        static let secondaryDark = Color.gray.opacity(0.7)
        
        // Success Colors
        static let success = Color.green
        static let successLight = Color.green.opacity(0.8)
        static let successBackground = Color.green.opacity(0.1)
        
        // Warning Colors
        static let warning = Color.orange
        static let warningLight = Color.orange.opacity(0.8)
        static let warningBackground = Color.orange.opacity(0.1)
        
        // Error Colors
        static let error = Color.red
        static let errorLight = Color.red.opacity(0.8)
        static let errorBackground = Color.red.opacity(0.1)
        
        // Background Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)
        
        // Text Colors
        static let textPrimary = Color(.label)
        static let textSecondary = Color(.secondaryLabel)
        static let textTertiary = Color(.tertiaryLabel)
        
        // Accent Colors
        static let accent = Color.purple
        static let accentLight = Color.purple.opacity(0.8)
        static let accentBackground = Color.purple.opacity(0.1)
        
        // Session Type Colors
        static let ride = Color.blue
        static let cafe = Color.orange
        static let classroom = Color.green
        static let flight = Color.purple
        static let custom = Color.gray
    }
    
    // MARK: - Typography
    struct Typography {
        // Font Sizes
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let title2 = Font.title2
        static let title3 = Font.title3
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
        
        // Font Weights
        static let bold = Font.Weight.bold
        static let semibold = Font.Weight.semibold
        static let medium = Font.Weight.medium
        static let regular = Font.Weight.regular
        static let light = Font.Weight.light
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
        static let full: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Animations
    struct Animations {
        static let quick = Animation.easeInOut(duration: 0.2)
        static let standard = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.5)
        static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.3, dampingFraction: 0.6)
    }
}

// MARK: - Shadow Structure
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions
extension View {
    // MARK: - Shadow Modifiers
    func shadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func shadowSmall() -> some View {
        self.shadow(AppTheme.Shadows.small)
    }
    
    func shadowMedium() -> some View {
        self.shadow(AppTheme.Shadows.medium)
    }
    
    func shadowLarge() -> some View {
        self.shadow(AppTheme.Shadows.large)
    }
    
    // MARK: - Background Modifiers
    func primaryBackground() -> some View {
        self.background(AppTheme.Colors.background)
    }
    
    func secondaryBackground() -> some View {
        self.background(AppTheme.Colors.secondaryBackground)
    }
    
    func tertiaryBackground() -> some View {
        self.background(AppTheme.Colors.tertiaryBackground)
    }
    

    
    // MARK: - Corner Radius Modifiers
    func cornerRadiusSm() -> some View {
        self.cornerRadius(AppTheme.CornerRadius.sm)
    }
    
    func cornerRadiusMd() -> some View {
        self.cornerRadius(AppTheme.CornerRadius.md)
    }
    
    func cornerRadiusLg() -> some View {
        self.cornerRadius(AppTheme.CornerRadius.lg)
    }
    
    func cornerRadiusXl() -> some View {
        self.cornerRadius(AppTheme.CornerRadius.xl)
    }
    
    func cornerRadiusFull() -> some View {
        self.cornerRadius(AppTheme.CornerRadius.full)
    }
    
    // MARK: - Animation Modifiers
    func animateQuick() -> some View {
        self.animation(AppTheme.Animations.quick, value: UUID())
    }
    
    func animateStandard() -> some View {
        self.animation(AppTheme.Animations.standard, value: UUID())
    }
    
    func animateSlow() -> some View {
        self.animation(AppTheme.Animations.slow, value: UUID())
    }
    
    func animateSpring() -> some View {
        self.animation(AppTheme.Animations.spring, value: UUID())
    }
    
    func animateBouncy() -> some View {
        self.animation(AppTheme.Animations.bouncy, value: UUID())
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.primary)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadowMedium()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animateStandard()
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadowSmall()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animateStandard()
    }
}

struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundColor(.white)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.success)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadowMedium()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animateStandard()
    }
}

// MARK: - Card Style
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.secondaryBackground)
            .cornerRadius(AppTheme.CornerRadius.lg)
            .shadowMedium()
    }
}

extension View {
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppTheme.Spacing.lg) {
        Button("Primary Button") { }
            .buttonStyle(PrimaryButtonStyle())
        
        Button("Secondary Button") { }
            .buttonStyle(SecondaryButtonStyle())
        
        Button("Success Button") { }
            .buttonStyle(SuccessButtonStyle())
        
        Text("Card Content")
            .cardStyle()
    }
    .padding()
    .primaryBackground()
}
