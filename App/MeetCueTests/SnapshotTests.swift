import AppKit
import Foundation
import SwiftUI
import Testing
@testable import MeetCue

/// Renders the menu bar label. Set `TEST_RUNNER_MEETCUE_SNAPSHOT_DIR` when running
/// `xcodebuild test` to also write them as PNGs for a visual check.
@MainActor
struct SnapshotTests {
    let source = FakeCalendarSource()
    let testDefaults = TestDefaults()

    func model(at time: Date) -> MenuBarModel {
        source.snapshots = [
            AppFixtures.event("PITR design review", start: AppFixtures.at(14, 30), location: "Room 4B; https://acme.zoom.us/j/1"),
        ]
        let store = MeetingStore(source: source, now: { time }, calendar: AppFixtures.calendar)
        store.refresh()
        return MenuBarModel(store: store, quiet: QuietMode(defaults: testDefaults.defaults), clock: { time }, calendar: AppFixtures.calendar, locale: Locale(identifier: "en_US"))
    }

    @Test func rendersLabel() throws {
        try render(MenuBarLabel(model: model(at: AppFixtures.at(14, 6))).background(.white), named: "menubar-label")
    }

    private func render(_ view: some View, named name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width > 0)
        guard let directory = ProcessInfo.processInfo.environment["MEETCUE_SNAPSHOT_DIR"] else { return }
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }
}
