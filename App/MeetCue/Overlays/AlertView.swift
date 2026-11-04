import MeetCueCore
import SwiftUI

struct AlertScreen: View {
    let model: OverlayModel

    var body: some View {
        TimelineView(.periodic(from: .wholeSecond, by: 1)) { _ in
            AlertScreenContent(model: model, now: model.currentTime())
        }
    }
}

/// A glass pane over the whole display with the alert card in the middle.
struct AlertScreenContent: View {
    let model: OverlayModel
    let now: Date

    var body: some View {
        ZStack {
            Color.clear.glassSurface(.backdrop, in: Rectangle())
            if !model.alertMeetings.isEmpty {
                AlertCard(model: model, meetings: model.alertMeetings, now: now)
            }
        }
        .ignoresSafeArea()
    }
}

/// The countdown, one or more meetings stacked, and the actions. `meetings` is non-empty, earliest first;
/// the countdown follows the first.
struct AlertCard: View {
    let model: OverlayModel
    let meetings: [Meeting]
    let now: Date

    private var first: Meeting { meetings[0] }
    private var canJoin: Bool { meetings.contains { $0.joinLink != nil } }

    var body: some View {
        VStack(spacing: 22) {
            CountdownHeader(title: first.title, countdown: AlertText.countdown(to: first.start, now: now))
            if meetings.count == 1 {
                MeetingSummary(model: model, meeting: first)
            } else {
                stackedRows
            }
            actions
            footer
        }
        .padding(EdgeInsets(top: 40, leading: 44, bottom: 32, trailing: 44))
        .frame(width: 600)
        .glassSurface(.card, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private static let visibleRows = 3
    private static let rowHeight: CGFloat = 92

    @ViewBuilder private var stackedRows: some View {
        let rows = VStack(spacing: 10) {
            ForEach(meetings) { meeting in
                StackedMeetingRow(model: model, meeting: meeting)
            }
        }
        if meetings.count > Self.visibleRows {
            ScrollView {
                rows
            }
            .frame(maxHeight: CGFloat(Self.visibleRows) * Self.rowHeight)
        } else {
            rows
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Dismiss") { model.dismissAlert() }
                .buttonStyle(CapsuleButtonStyle())
            // The pill only counts down to the start, so it can't take a meeting that has started.
            if meetings.allSatisfy({ now < $0.start }) {
                Button("Move to corner", systemImage: "arrow.down.right.and.arrow.up.left") { model.moveAlertToCorner() }
                    .buttonStyle(CapsuleButtonStyle())
            }
            if meetings.count == 1, first.joinLink != nil {
                Button("Join meeting", systemImage: "video.fill") { model.join(first.id) }
                    .buttonStyle(CapsuleButtonStyle(prominent: true))
                    .accessibilityLabel("Join \(first.title)")
            }
        }
        .padding(.top, 6)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Snooze \(Int(model.timing.snoozeLength / 60)) min") { model.snoozeAlert() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .fontWeight(.medium)
            Text("·").accessibilityHidden(true)
            Text(canJoin ? "esc to dismiss · ↩ to join" : "esc or ↩ to dismiss")
                .accessibilityHidden(true)
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
}

private struct CountdownHeader: View {
    let title: String
    let countdown: Countdown

    private var spokenLabel: String {
        let time = Self.spoken(clock: countdown.clock)
        return countdown.hasStarted ? "\(title) started \(time) ago" : "\(title) starts in \(time)"
    }

    /// "1:42" as "1 minute 42 seconds", and "1:05:03" as "1 hour 5 minutes 3 seconds".
    private static func spoken(clock: String) -> String {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        let units = ["hour", "minute", "second"].suffix(parts.count)
        return zip(parts, units)
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
            .joined(separator: " ")
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(countdown.hasStarted ? "Started" : "Starts in")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(countdown.clock)
                    .font(.system(size: 104, weight: .semibold))
                    .kerning(-3)
                    .monospacedDigit()
                if countdown.hasStarted {
                    Text("ago")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct MeetingSummary: View {
    let model: OverlayModel
    let meeting: Meeting

    var body: some View {
        VStack(spacing: 12) {
            Text(meeting.title)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            MeetingFacts(model: model, meeting: meeting)
                .font(.system(size: 16))
            TopicCount(count: model.topicCount(for: meeting))
        }
    }
}

private struct StackedMeetingRow: View {
    let model: OverlayModel
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(meeting.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                MeetingFacts(model: model, meeting: meeting)
                    .font(.system(size: 14))
                TopicCount(count: model.topicCount(for: meeting))
            }
            Spacer(minLength: 0)
            if meeting.joinLink != nil {
                Button("Join", systemImage: "video.fill") { model.join(meeting.id) }
                    .buttonStyle(CapsuleButtonStyle(prominent: true))
                    .accessibilityLabel("Join \(meeting.title)")
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

/// "2:30 – 3:00 PM" and "Room 4B · Zoom", each with its icon.
private struct MeetingFacts: View {
    let model: OverlayModel
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 18) {
            Label(model.timeRange(for: meeting), systemImage: "clock")
                .monospacedDigit()
            if let place = meeting.placeLine {
                Label(place, systemImage: meeting.joinLink == nil ? "mappin.and.ellipse" : "video")
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// "2 topics to bring up". Hidden when there are none.
private struct TopicCount: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Label(count == 1 ? "1 topic to bring up" : "\(count) topics to bring up", systemImage: "list.bullet.clipboard")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .foregroundStyle(Color.accentColor)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
    }
}

extension Date {
    /// The current time rounded down to a whole second, so per-second timelines tick when the clock text changes.
    static var wholeSecond: Date {
        Date(timeIntervalSinceReferenceDate: Date().timeIntervalSinceReferenceDate.rounded(.down))
    }
}
