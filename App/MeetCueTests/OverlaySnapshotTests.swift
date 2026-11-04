import AppKit
import Foundation
import MeetCueCore
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the alert and the pill with solid glass, since `ImageRenderer` can't draw Liquid Glass.
/// Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running `xcodebuild test` to also write them as PNGs.
@MainActor
struct OverlaySnapshotTests {
    let source = FakeCalendarSource()

    func model(at time: Date, events: [EventSnapshot]) -> OverlayModel {
        source.snapshots = events
        let store = MeetingStore(source: source, now: { time }, calendar: AppFixtures.calendar)
        store.refresh()
        let model = OverlayModel(
            store: store,
            quiet: QuietMode(storage: InMemoryQuietStorage()),
            dismissed: DismissedAlerts(storage: InMemoryDismissedAlertStorage()),
            clock: { time },
            calendar: AppFixtures.calendar,
            locale: Locale(identifier: "en_US"),
            openURL: { _ in }
        )
        model.refresh()
        return model
    }

    var teamSync: EventSnapshot {
        AppFixtures.event(start: AppFixtures.at(14, 30), location: "Room 4B; https://meet.google.com/abc-defg-hij")
    }

    @Test func rendersAlert() throws {
        let now = AppFixtures.at(14, 28, second: 18)
        let model = model(at: now, events: [teamSync])
        #expect(model.alertMeetings.count == 1)
        for dark in [false, true] {
            try render(AlertScreenContent(model: model, now: now), dark: dark, named: dark ? "alert-dark" : "alert-light")
        }
    }

    @Test func rendersStackedAndStartedAlerts() throws {
        let review = AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), series: "series-2", location: "https://acme.zoom.us/j/1")
        let stackedAt = AppFixtures.at(14, 28, second: 18)
        try render(AlertScreenContent(model: model(at: stackedAt, events: [teamSync, review]), now: stackedAt), dark: false, named: "alert-stacked")
        let lateAt = AppFixtures.at(14, 30, second: 42)
        try render(AlertScreenContent(model: model(at: lateAt, events: [teamSync]), now: lateAt), dark: true, named: "alert-started")
    }

    private func render(_ view: some View, size: CGSize = CGSize(width: 1280, height: 800), dark: Bool, named name: String) throws {
        let screen = ZStack {
            Wallpaper(dark: dark)
            view
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.solidGlass, true)
        .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: screen)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width == Int(size.width) * 2)
        guard let directory = ProcessInfo.processInfo.environment["MEETCUE_SNAPSHOT_DIR"] else { return }
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}

/// Stands in for the desktop and windows behind an overlay.
private struct Wallpaper: View {
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
