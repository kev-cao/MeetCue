import SwiftUI

extension EnvironmentValues {
    /// Draws glass surfaces as solid translucent fills. `ImageRenderer` can't draw `glassEffect`,
    /// so tests that render overlays to images set it.
    @Entry var solidGlass = false
}

enum GlassRole {
    /// The full-screen pane behind the alert card.
    case backdrop
    /// The alert card and the pill.
    case card
}

extension View {
    /// Liquid Glass in `shape`, or a solid fill when `solidGlass` is set or Reduce transparency is on.
    func glassSurface(_ role: GlassRole, in shape: some Shape) -> some View {
        modifier(GlassSurface(role: role, shape: shape))
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    let role: GlassRole
    let shape: S

    @Environment(\.solidGlass) private var solidGlass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if solidGlass || reduceTransparency {
            content.background {
                shape
                    .fill(fill.opacity(reduceTransparency ? 1 : translucency))
                    .overlay(shape.stroke(edge, lineWidth: role == .card ? 1 : 0))
                    .shadow(color: .black.opacity(role == .card ? 0.22 : 0), radius: 28, y: 14)
            }
        } else {
            content.glassEffect(.regular, in: shape)
        }
    }

    private var dark: Bool { colorScheme == .dark }

    private var fill: Color {
        switch role {
        case .backdrop: dark ? Color(white: 0.05) : Color(white: 0.94)
        case .card: dark ? Color(white: 0.19) : .white
        }
    }

    private var translucency: Double {
        switch role {
        case .backdrop: dark ? 0.72 : 0.62
        case .card: dark ? 0.88 : 0.84
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

/// The pill's round icon buttons.
struct CircleButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 32, height: 32)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(Circle().fill(prominent ? Color.accentColor : Color.primary.opacity(0.08)))
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
