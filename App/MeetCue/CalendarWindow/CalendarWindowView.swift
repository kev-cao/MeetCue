import AppKit
import MeetCueCore
import SwiftUI

/// The calendar window: a floating sidebar, the grid with its toolbar, and the inspector.
struct CalendarWindowView: View {
    let model: CalendarWindowModel

    var body: some View {
        HStack(spacing: 0) {
            CalendarSidebar(model: model)
                .frame(width: 236)
                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0))
            VStack(spacing: 0) {
                CalendarToolbar(model: model)
                if model.store.access == .granted {
                    switch model.mode {
                    case .day, .week: TimeGrid(model: model)
                    case .month: MonthGrid(model: model)
                    }
                } else {
                    CalendarAccessNotice(store: model.store)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            EventInspector(model: model)
                .frame(width: 340)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .background { MidnightWatcher(model: model) }
        .ignoresSafeArea()
        .frame(minWidth: 1000, minHeight: 640)
    }
}

/// Tells the model when the day changes, so a view of today follows it past midnight.
private struct MidnightWatcher: View {
    let model: CalendarWindowModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            Color.clear
                .onChange(of: context.date) { model.dayDidChange() }
        }
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}

/// "November 2026", Day / Week / Month, and previous, Today, next.
private struct CalendarToolbar: View {
    let model: CalendarWindowModel

    var body: some View {
        HStack(spacing: 12) {
            Text("\(Text(model.title.primary).fontWeight(.bold)) \(Text(model.title.secondary).foregroundStyle(.secondary))")
                .font(.system(size: 22))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            SegmentedCapsule(options: CalendarMode.allCases, selection: model.mode, label: \.title) { model.mode = $0 }
            HStack(spacing: 6) {
                Button("Previous", systemImage: "chevron.left") { model.step(-1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(ToolbarCapsuleStyle())
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Today") { model.goToToday() }
                    .buttonStyle(ToolbarCapsuleStyle())
                    .keyboardShortcut("t", modifiers: .command)
                Button("Next", systemImage: "chevron.right") { model.step(1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(ToolbarCapsuleStyle())
                    .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
    }
}

/// A row of options in a capsule, the selected one raised on a white pill.
struct SegmentedCapsule<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let label: (Option) -> String
    var compact = false
    let select: (Option) -> Void

    init(options: [Option], selection: Option, label: @escaping (Option) -> String, compact: Bool = false, select: @escaping (Option) -> Void) {
        self.options = options
        self.selection = selection
        self.label = label
        self.compact = compact
        self.select = select
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button(label(option)) { select(option) }
                    .buttonStyle(.plain)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .padding(.horizontal, compact ? 10 : 14)
                    .frame(height: compact ? 22 : 28)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
    }
}

struct ToolbarCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .frame(minWidth: 30, minHeight: 30)
            .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.05)))
            .contentShape(Capsule())
    }
}

private struct CalendarAccessNotice: View {
    let store: MeetingStore

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("MeetCue needs access to your calendars")
                .font(.headline)
            Text("Allow it in System Settings › Privacy & Security › Calendars.")
                .foregroundStyle(.secondary)
            Button("Open Privacy Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init(_ color: CalendarColor) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue)
    }
}
