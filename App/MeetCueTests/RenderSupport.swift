import AppKit
import SwiftUI
import Testing
@testable import MeetCue

/// Draws `view` through AppKit at twice its size, with solid glass, and writes it as a PNG to the
/// directory in the environment variable `directoryVariable`, if set. `ImageRenderer` leaves a
/// `ScrollView`'s content blank and can't draw AppKit controls, so views with those render here.
@MainActor
func renderHosted(
    _ view: some View,
    size: CGSize = CGSize(width: 1280, height: 800),
    dark: Bool = false,
    named name: String,
    directoryVariable: String = "MEETCUE_SNAPSHOT_DIR"
) throws {
    let root = view
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.solidGlass, true)
        .environment(\.colorScheme, dark ? .dark : .light)
    let host = NSHostingView(rootView: root)
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let bitmap = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ))
    bitmap.size = size
    host.cacheDisplay(in: host.bounds, to: bitmap)
    guard let directory = ProcessInfo.processInfo.environment[directoryVariable] else { return }
    let data = try #require(bitmap.representation(using: .png, properties: [:]))
    try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
}

/// Stands in for the desktop and windows behind an overlay.
struct Wallpaper: View {
    let dark: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: dark
                    ? [Color(red: 0.10, green: 0.13, blue: 0.28), Color(red: 0.30, green: 0.14, blue: 0.32)]
                    : [Color(red: 0.62, green: 0.76, blue: 1.0), Color(red: 0.99, green: 0.80, blue: 0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RoundedRectangle(cornerRadius: 20)
                .fill(dark ? Color(white: 0.15) : .white)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach([0.4, 0.62, 0.55, 0.7, 0.3, 0.66, 0.48], id: \.self) { fraction in
                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                                .frame(height: 9)
                                .scaleEffect(x: fraction, anchor: .leading)
                        }
                    }
                    .padding(40)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(EdgeInsets(top: 100, leading: 120, bottom: 60, trailing: 120))
        }
    }
}
