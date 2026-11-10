import MeetCueCore
import SwiftUI

struct GeneralPane: View {
    let model: SettingsModel

    var body: some View {
        @Bindable var settings = model.settings
        let login = model.launchAtLogin
        Form {
            Section {
                Toggle("Launch at login", isOn: Binding(get: { login.isOn }, set: { login.setOn($0) }))
                if login.needsApproval {
                    LabeledContent {
                        Button("Open Login Items…") { login.openSystemSettings() }
                    } label: {
                        Text("Waiting for your approval")
                        Text("Allow MeetCue in System Settings › General › Login Items.")
                    }
                }
                if let error = login.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            Section("Menu bar") {
                Picker("Show in menu bar", selection: $settings.menuBarContent) {
                    ForEach(MenuBarSettings.Content.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Group {
                    Picker(selection: $settings.titleLength) {
                        ForEach(AppSettings.titleLengths, id: \.self) { Text("\($0) characters").tag($0) }
                    } label: {
                        Text("Title length")
                        Text("Longer titles scroll inside this width.")
                    }
                    Picker("Scroll long titles", selection: $settings.titleScroll) {
                        ForEach(MenuBarSettings.Scroll.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                }
                .disabled(settings.menuBarContent != .timeAndTitle)
            }
            Section("Keyboard shortcuts") {
                ShortcutRow(title: "Show or hide notes card", keys: "⌥⌘N")
                ShortcutRow(title: "Join current or next meeting", keys: "⌥⌘J")
                ShortcutRow(title: "Open MeetCue", keys: "⌥⌘O")
            }
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let keys: String

    var body: some View {
        LabeledContent(title) {
            Text(keys)
                .monospacedDigit()
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.06)))
                .foregroundStyle(.primary)
        }
    }
}

struct AlertsPane: View {
    @Bindable var model: SettingsModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Picker("Show alert", selection: $settings.leadTime) {
                    ForEach(AppSettings.leadTimes, id: \.self) { Text("\(Self.minutes($0)) before").tag($0) }
                }
                Picker("Snooze length", selection: $settings.snoozeLength) {
                    ForEach(AppSettings.snoozeLengths, id: \.self) { Text(Self.minutes($0)).tag($0) }
                }
                Picker("Sound", selection: $settings.alertSound) {
                    ForEach(AlertSound.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: settings.alertSound) { _, sound in sound.play() }
                Picker("Show on", selection: $settings.alertDisplays) {
                    ForEach(AlertDisplays.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Skip events I've declined", isOn: $settings.skipDeclined)
            } header: {
                Text("Full-screen alert")
            } footer: {
                Text("All-day events never alert. Choose which calendars alert in Calendars.")
                    .foregroundStyle(.secondary)
            }
            Section("Notes card") {
                Toggle("Show notes when a meeting starts", isOn: $settings.showNotesAtStart)
                Toggle("Only for meetings that have notes", isOn: $settings.notesOnlyWithNotes)
                Toggle("Hide when the meeting ends", isOn: $settings.hideNotesAtEnd)
            }
            Section("Quiet mode") {
                Picker(selection: $model.quietPreset) {
                    Text("Off").tag(QuietMode.Preset?.none)
                    ForEach(QuietMode.Preset.allCases) { Text($0.title).tag(QuietMode.Preset?.some($0)) }
                } label: {
                    Text("Quiet mode")
                    Text("Silences the full-screen alert. Notes cards still appear.")
                }
            }
        }
    }

    /// "1 minute" or "5 minutes".
    static func minutes(_ count: Int) -> String {
        count == 1 ? "1 minute" : "\(count) minutes"
    }
}

struct CalendarsPane: View {
    let model: SettingsModel

    var body: some View {
        Form {
            if model.store.access != .granted {
                Section {
                    Text("MeetCue needs access to your calendars to list them. Allow it from the menu bar.")
                        .foregroundStyle(.secondary)
                }
            }
            if let google = model.google {
                GoogleSection(model: model, account: google)
            }
            ForEach(model.calendarGroups) { group in
                Section {
                    ForEach(group.calendars) { calendar in
                        CalendarSwitchesRow(model: model, calendar: calendar)
                    }
                } header: {
                    HStack {
                        Text(group.account)
                        Spacer()
                        Group {
                            Text("Show").frame(width: CalendarSwitchesRow.switchWidth)
                            Text("Alert").frame(width: CalendarSwitchesRow.switchWidth)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    }
                }
            }
            Section {
            } footer: {
                Text("Hidden calendars leave the menu bar, alerts and the calendar window. Calendars with alerts off still show the notes card. Add or remove accounts in System Settings › Internet Accounts.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct GoogleSection: View {
    let model: SettingsModel
    let account: GoogleAccount

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                switch account.state {
                case .connected:
                    Button("Disconnect", action: model.disconnectGoogle)
                case .connecting:
                    ProgressView().controlSize(.small)
                case .needsReconnect:
                    Button("Reconnect…", action: model.connectGoogle)
                case .disconnected, .unavailable:
                    Button("Connect…", action: model.connectGoogle)
                }
            }
            if let problem = account.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.multicolor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Google Calendar")
        }
    }

    private var title: String {
        switch account.state {
        case .connected: account.email.map { "Connected as \($0)" } ?? "Connected"
        case .connecting: "Waiting for Google…"
        case .needsReconnect: "Signed out by Google"
        case .disconnected, .unavailable: "Not connected"
        }
    }

    private var detail: String {
        switch account.state {
        case .connected, .connecting:
            "Meetings on your primary Google calendar show in MeetCue with their Meet links and your replies, even if the account isn't on this Mac."
        case .needsReconnect:
            "Google meetings that aren't on this Mac are hidden until you reconnect."
        case .disconnected, .unavailable:
            "Show meetings from your primary Google calendar, with Meet links and your replies, even if the account isn't on this Mac. MeetCue only reads your events."
        }
    }
}

private struct CalendarSwitchesRow: View {
    static let switchWidth: CGFloat = 50

    let model: SettingsModel
    let calendar: CalendarInfo

    var body: some View {
        let visible = model.isVisible(calendar.id)
        HStack(spacing: 10) {
            Circle()
                .fill(Color(calendar.color))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(calendar.title)
                .lineLimit(1)
            Spacer()
            Toggle("Show \(calendar.title)", isOn: Binding(get: { visible }, set: { model.setVisible($0, calendarID: calendar.id) }))
                .labelsHidden()
                .frame(width: Self.switchWidth)
            Toggle("Alerts for \(calendar.title)", isOn: Binding(get: { model.alertsOn(calendar.id) }, set: { model.setAlertsOn($0, calendarID: calendar.id) }))
                .labelsHidden()
                .frame(width: Self.switchWidth)
                .disabled(!visible)
        }
    }
}

struct NotesPane: View {
    let model: SettingsModel

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle(isOn: $settings.carryOver) {
                    Text("Carry over unchecked topics")
                    Text("For recurring meetings, unchecked task items move to the next occurrence.")
                }
                Picker("Open notes in", selection: $settings.notesEditorMode) {
                    ForEach(CalendarWindowModel.EditorMode.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Storage") {
                if let path = model.notesFolderPath {
                    LabeledContent {
                        Button("Show in Finder") { model.showNotesInFinder() }
                    } label: {
                        Text("Notes are saved on this Mac")
                        Text(path)
                    }
                }
                LabeledContent {
                    Button("Export…") { model.chooseExportFolder() }
                } label: {
                    Text("Export all notes as Markdown files")
                    Text(model.exportStatus ?? "One file per note, named by date and meeting title.")
                }
            }
        }
    }
}

struct AppearancePane: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Appearance")
                    Spacer()
                    SegmentedCapsule(options: AppearanceMode.allCases, selection: settings.appearance, label: \.title) {
                        settings.appearance = $0
                    }
                }
            }
            Section {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Glass opacity")
                        Slider(value: $settings.glassOpacity, in: 0...1) {
                            Text("Glass opacity")
                        }
                        .labelsHidden()
                        HStack {
                            Text("Clear")
                            Spacer()
                            Text("\(Int((settings.glassOpacity * 100).rounded()))%").monospacedDigit()
                            Spacer()
                            Text("Opaque")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("Starts from your system Liquid Glass setting (Clear or Tinted). Applies to the alert, corner pill and notes card.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    GlassPreview(opacity: settings.glassOpacity)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Glass")
            } footer: {
                Text("When Reduce transparency is on in System Settings › Accessibility, MeetCue is always opaque.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A small card of glass over a desktop and some text, at the chosen opacity.
private struct GlassPreview: View {
    let opacity: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.44, green: 0.63, blue: 1), Color(red: 0.95, green: 0.78, blue: 0.86), Color(red: 1, green: 0.62, blue: 0.44)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                ForEach([70.0, 110, 90], id: \.self) { width in
                    Capsule().fill(Color(white: 0.11)).frame(width: width, height: 10)
                }
            }
            .padding(EdgeInsets(top: 16, leading: 14, bottom: 0, trailing: 0))
            Text("1:58")
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassSurface(.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .environment(\.glassOpacity, opacity)
                .padding(EdgeInsets(top: 30, leading: 30, bottom: 14, trailing: 14))
        }
        .frame(width: 180, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}
