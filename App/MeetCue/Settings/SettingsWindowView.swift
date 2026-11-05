import SwiftUI

/// The Settings window: a floating glass sidebar of sections and the selected section's form.
struct SettingsWindowView: View {
    static let size = CGSize(width: 860, height: 620)

    let model: SettingsModel

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(model: model)
                .frame(width: 220)
                .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 0))
            VStack(alignment: .leading, spacing: 0) {
                Text(model.section.title)
                    .font(.system(size: 22, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 28)
                    .frame(height: 60)
                Group {
                    switch model.section {
                    case .general: GeneralPane(model: model)
                    case .alerts: AlertsPane(model: model)
                    case .calendars: CalendarsPane(model: model)
                    case .notes: NotesPane(model: model)
                    case .appearance: AppearancePane(settings: model.settings)
                    }
                }
                .formStyle(.grouped)
                .toggleStyle(.switch)
                .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea()
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

extension SettingsModel.Section {
    var systemImage: String {
        switch self {
        case .general: "gearshape.fill"
        case .alerts: "bell.fill"
        case .calendars: "calendar"
        case .notes: "note.text"
        case .appearance: "circle.lefthalf.filled"
        }
    }

    /// The icon tile's color, as in System Settings.
    var tint: Color {
        switch self {
        case .general: Color(red: 0.56, green: 0.56, blue: 0.58)
        case .alerts: Color(red: 0.9, green: 0.22, blue: 0.18)
        case .calendars: Color(red: 0.04, green: 0.42, blue: 0.94)
        case .notes: Color(red: 0.95, green: 0.63, blue: 0)
        case .appearance: Color(red: 0.49, green: 0.36, blue: 0.84)
        }
    }
}

private struct SettingsSidebar: View {
    let model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Room for the window's traffic lights, which float over the sidebar.
            Color.clear.frame(height: 30)
            ForEach(SettingsModel.Section.allCases) { section in
                SidebarRow(section: section, isSelected: model.section == section) { model.section = section }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 10, bottom: 14, trailing: 10))
        .frame(maxHeight: .infinity, alignment: .top)
        .glassSurface(.sidebar, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SidebarRow: View {
    let section: SettingsModel.Section
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(section.tint))
                    .accessibilityHidden(true)
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.accentColor.opacity(0.16))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
