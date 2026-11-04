import MeetCueCore
import SwiftUI

/// The floating glass sidebar: a mini month and the calendars by account.
struct CalendarSidebar: View {
    let model: CalendarWindowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            // Room for the window's traffic lights, which float over the sidebar.
            Color.clear.frame(height: 18)
            MiniMonth(model: model)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(model.calendarGroups) { group in
                        Text(group.account)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(EdgeInsets(top: group == model.calendarGroups.first ? 0 : 12, leading: 4, bottom: 4, trailing: 4))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(group.calendars) { calendar in
                            CalendarRow(model: model, calendar: calendar)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassSurface(.sidebar, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CalendarRow: View {
    let model: CalendarWindowModel
    let calendar: CalendarInfo

    var body: some View {
        let visible = model.isVisible(calendar.id)
        Button {
            model.setVisible(!visible, calendarID: calendar.id)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(visible ? Color(calendar.color) : .clear)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color(calendar.color), lineWidth: 1.5)
                    if visible {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 14, height: 14)
                Text(calendar.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 28)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(calendar.title)
        .accessibilityValue(visible ? "shown" : "hidden")
    }
}

/// The anchor's month, with today in red and the days on screen highlighted. Clicking a day goes to it.
private struct MiniMonth: View {
    let model: CalendarWindowModel

    var body: some View {
        let days = CalendarGrid.days(.month, containing: model.anchor, calendar: model.calendar)
        let shown = Set(model.days)
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        VStack(alignment: .leading, spacing: 6) {
            Text(model.monthTitle(model.anchor))
                .font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 4)
            HStack(spacing: 0) {
                ForEach(Array(weeks[0].enumerated()), id: \.offset) { _, day in
                    Text(model.weekdayInitial(day))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        Button {
                            model.go(to: day)
                        } label: {
                            Text(model.dayNumber(day))
                                .font(.system(size: 11, weight: model.isToday(day) ? .bold : .regular))
                                .monospacedDigit()
                                .foregroundStyle(model.isToday(day) ? Color.white : model.isInAnchorMonth(day) ? Color.primary : Color.secondary.opacity(0.6))
                                .frame(width: 24, height: 22)
                                .background { if model.isToday(day) { Capsule().fill(Color.red) } }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background {
                    if model.mode != .month, week.contains(where: shown.contains) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.primary.opacity(0.07))
                    }
                }
            }
        }
    }
}
