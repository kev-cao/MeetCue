import MeetCueCore
import SwiftUI

/// The day and week views: an hour grid with each day's meetings, all-day events above it, and a
/// red line at the current time.
struct TimeGrid: View {
    static let hourHeight: CGFloat = 56
    static let gutter: CGFloat = 56
    /// The hour scrolled to the top when the grid appears, with room above for its label.
    static let firstVisibleHour = 8

    let model: CalendarWindowModel

    var body: some View {
        let days = model.days
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.gutter)
                ForEach(days, id: \.self) { day in
                    DayHeader(model: model, day: day)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40)
            if days.contains(where: { !model.allDayMeetings(on: $0).isEmpty }) {
                HStack(alignment: .top, spacing: 0) {
                    Text("all-day")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .frame(width: Self.gutter - 8, alignment: .trailing)
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 2) {
                            ForEach(model.allDayMeetings(on: day)) { meeting in
                                AllDayChip(model: model, meeting: meeting)
                            }
                        }
                        .padding(.horizontal, 3)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                .padding(.vertical, 4)
            }
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    HStack(alignment: .top, spacing: 0) {
                        HourLabels(model: model)
                        ForEach(days, id: \.self) { day in
                            DayColumn(model: model, day: day)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(alignment: .top) { HourLines().padding(.top, 10).padding(.leading, Self.gutter) }
                }
                .onAppear { proxy.scrollTo(Self.firstVisibleHour, anchor: UnitPoint(x: 0, y: 0.02)) }
            }
        }
    }
}

private struct DayHeader: View {
    let model: CalendarWindowModel
    let day: Date

    var body: some View {
        let today = model.isToday(day)
        Button {
            model.go(to: day, mode: .day)
        } label: {
            HStack(spacing: 6) {
                Text(model.weekdayLabel(day))
                    .foregroundStyle(today ? Color.red : Color.secondary)
                Text(model.dayNumber(day))
                    .fontWeight(.semibold)
                    .foregroundStyle(today ? Color.white : Color.primary)
                    .frame(minWidth: 24, minHeight: 24)
                    .background { if today { Circle().fill(Color.red) } }
            }
            .font(.system(size: 13))
            .monospacedDigit()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HourLabels: View {
    let model: CalendarWindowModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hour == 0 ? "" : model.hourLabel(hour))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .offset(y: -7)
                    .frame(width: TimeGrid.gutter - 8, height: TimeGrid.hourHeight, alignment: .topTrailing)
                    .id(hour)
            }
        }
        .padding(.trailing, 8)
    }
}

private struct HourLines: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { _ in
                VStack(spacing: 0) {
                    Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: TimeGrid.hourHeight)
            }
        }
    }
}

private struct DayColumn: View {
    let model: CalendarWindowModel
    let day: Date

    var body: some View {
        let height = TimeGrid.hourHeight * 24
        GeometryReader { geometry in
            let width = geometry.size.width - 6
            ZStack(alignment: .topLeading) {
                ForEach(model.placed(on: day), id: \.meeting.id) { placed in
                    let start = max(0, model.hours(of: placed.meeting.start, on: day))
                    let end = min(24, model.hours(of: placed.meeting.end, on: day))
                    let columnWidth = width / CGFloat(placed.columns)
                    EventBlock(model: model, meeting: placed.meeting, height: max(CGFloat(end - start) * TimeGrid.hourHeight - 2, 20))
                        .frame(width: columnWidth - 2)
                        .offset(x: 3 + CGFloat(placed.column) * columnWidth, y: CGFloat(start) * TimeGrid.hourHeight + 1)
                }
                if model.isToday(day) {
                    let now = model.hours(of: model.currentTime(), on: day)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.red).frame(height: 2)
                        Circle().fill(Color.red).frame(width: 8, height: 8).offset(x: -4)
                    }
                    .offset(y: CGFloat(now) * TimeGrid.hourHeight - 1)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: height)
        .background(model.isToday(day) ? Color.accentColor.opacity(0.035) : .clear)
        .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1) }
    }
}

/// A meeting on the grid, in its calendar's color, with a note icon when it has notes.
struct EventBlock: View {
    let model: CalendarWindowModel
    let meeting: Meeting
    let height: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let selected = model.selected?.id == meeting.id
        let color = Color(model.color(for: meeting))
        Button {
            model.select(meeting)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(height < 36 ? 1 : 2)
                if height >= 36 {
                    Text(model.timeRange(for: meeting))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .lineLimit(1)
                        .opacity(0.85)
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, model.hasNotes(meeting) ? 18 : 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(selected ? Color.white : Self.ink(color, dark: colorScheme == .dark))
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? color : color.opacity(colorScheme == .dark ? 0.3 : 0.16))
                    .shadow(color: selected ? color.opacity(0.35) : .clear, radius: 6, y: 3)
            }
            .overlay(alignment: .topTrailing) {
                if model.hasNotes(meeting) {
                    Image(systemName: "note.text")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(5)
                        .foregroundStyle(selected ? Color.white : Self.ink(color, dark: colorScheme == .dark))
                        .accessibilityLabel("Has notes")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(height: height)
        .accessibilityLabel("\(meeting.title), \(model.timeRange(for: meeting))\(model.hasNotes(meeting) ? ", has notes" : "")")
    }

    /// The calendar color, darkened in light mode and lightened in dark mode, so text on its tint stays readable.
    static func ink(_ color: Color, dark: Bool) -> Color {
        color.mix(with: dark ? .white : .black, by: dark ? 0.45 : 0.4)
    }
}

private struct AllDayChip: View {
    let model: CalendarWindowModel
    let meeting: Meeting
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = Color(model.color(for: meeting))
        Button {
            model.select(meeting)
        } label: {
            Text(meeting.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 18, alignment: .leading)
                .foregroundStyle(model.selected?.id == meeting.id ? Color.white : EventBlock.ink(color, dark: colorScheme == .dark))
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(model.selected?.id == meeting.id ? color : color.opacity(colorScheme == .dark ? 0.3 : 0.18)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The month view: every week of the month, up to three meetings a day.
struct MonthGrid: View {
    static let visibleMeetings = 3

    let model: CalendarWindowModel

    var body: some View {
        let days = model.days
        let weeks = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(weeks[0], id: \.self) { day in
                    Text(model.weekdayLabel(day))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 10)
                }
            }
            .frame(height: 28)
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        MonthCell(model: model, day: day)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1) }
            }
        }
    }
}

private struct MonthCell: View {
    let model: CalendarWindowModel
    let day: Date

    var body: some View {
        let meetings = model.allDayMeetings(on: day) + model.timedMeetings(on: day)
        let today = model.isToday(day)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Spacer()
                Button {
                    model.go(to: day, mode: .day)
                } label: {
                    Text(model.dayNumber(day))
                        .font(.system(size: 12, weight: today ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(today ? Color.white : model.isInAnchorMonth(day) ? Color.primary : Color.secondary)
                        .frame(minWidth: 22, minHeight: 22)
                        .background { if today { Circle().fill(Color.red) } }
                }
                .buttonStyle(.plain)
            }
            ForEach(meetings.prefix(MonthGrid.visibleMeetings)) { meeting in
                Button {
                    model.select(meeting)
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(Color(model.color(for: meeting))).frame(width: 6, height: 6)
                        Text(meeting.title).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 4)
                    .frame(height: 18)
                    .background(RoundedRectangle(cornerRadius: 4).fill(model.selected?.id == meeting.id ? Color.accentColor.opacity(0.18) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(meeting.isAllDay ? meeting.title : "\(model.startTime(for: meeting)) \(meeting.title)")
                .accessibilityLabel(meeting.isAllDay ? meeting.title : "\(meeting.title), \(model.startTime(for: meeting))")
            }
            if meetings.count > MonthGrid.visibleMeetings {
                Text("\(meetings.count - MonthGrid.visibleMeetings) more")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(model.isInAnchorMonth(day) ? Color.clear : Color.primary.opacity(0.025))
        .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1) }
    }
}
