import SwiftUI

extension EnvironmentValues {
    /// Draws glass surfaces as solid translucent fills. `ImageRenderer` can't draw `glassEffect`,
    /// so tests that render overlays to images set it.
    @Entry var solidGlass = false
    /// The Glass opacity setting, from 0 (the glass as the system draws it) to 1 (opaque).
    @Entry var glassOpacity: Double = 0
}

enum GlassTint {
    /// How opaque the tint layer of a glass surface is: `base` raised toward 1 by the Glass opacity
    /// setting. Reduce transparency makes every surface opaque.
    static func opacity(base: Double, glassOpacity: Double, reduceTransparency: Bool) -> Double {
        reduceTransparency ? 1 : base + (1 - base) * glassOpacity
    }
}

enum GlassRole {
    /// The full-screen pane behind the alert card.
    case backdrop
    /// The alert card, the pill and the notes card.
    case card
    /// The calendar window's floating sidebar.
    case sidebar
}

extension View {
    /// Liquid Glass in `shape` with a tint layer as opaque as `glassOpacity`, or a solid fill when
    /// `solidGlass` is set or Reduce transparency is on.
    func glassSurface(_ role: GlassRole, in shape: some Shape) -> some View {
        modifier(GlassSurface(role: role, shape: shape))
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    let role: GlassRole
    let shape: S

    @Environment(\.solidGlass) private var solidGlass
    @Environment(\.glassOpacity) private var glassOpacity
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if solidGlass || reduceTransparency {
            content.background {
                shape
                    .fill(fill.opacity(GlassTint.opacity(base: translucency, glassOpacity: glassOpacity, reduceTransparency: reduceTransparency)))
                    .overlay(shape.stroke(edge, lineWidth: role == .backdrop ? 0 : 1))
                    .shadow(color: .black.opacity(shadowOpacity), radius: role == .card ? 28 : 6, y: role == .card ? 14 : 2)
            }
        } else {
            content
                .background { shape.fill(fill.opacity(glassOpacity)) }
                .glassEffect(.regular, in: shape)
        }
    }

    private var dark: Bool { colorScheme == .dark }

    private var fill: Color {
        switch role {
        case .backdrop: dark ? Color(white: 0.05) : Color(white: 0.94)
        case .card: dark ? Color(white: 0.19) : .white
        case .sidebar: dark ? Color(white: 0.17) : Color(red: 0.93, green: 0.935, blue: 0.96)
        }
    }

    private var shadowOpacity: Double {
        switch role {
        case .backdrop: 0
        case .card: 0.22
        case .sidebar: 0.08
        }
    }

    private var translucency: Double {
        switch role {
        case .backdrop: dark ? 0.72 : 0.62
        case .card: dark ? 0.88 : 0.84
        case .sidebar: dark ? 0.9 : 0.85
        }
    }

    private var edge: Color {
        dark ? .white.opacity(0.14) : .white.opacity(0.9)
    }
}

/// The alert's capsule buttons: a filled accent button for Join, quiet tinted ones for the rest.
struct CapsuleButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 22)
            .frame(height: 44)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(Capsule().fill(prominent ? Color.accentColor : Color.primary.opacity(0.08)))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// The pill's and the notes card's round icon buttons.
struct CircleButtonStyle: ButtonStyle {
    var prominent = false
    var diameter: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: diameter * 0.4, weight: .semibold))
            .frame(width: diameter, height: diameter)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(Circle().fill(prominent ? Color.accentColor : Color.primary.opacity(0.08)))
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
