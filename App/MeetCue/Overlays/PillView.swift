import MeetCueCore
import SwiftUI

struct PillStack: View {
    let model: OverlayModel

    var body: some View {
        Group {
            if model.pillMeetings.isEmpty && model.notice == nil {
                Color.clear
            } else {
                TimelineView(.periodic(from: .wholeSecond, by: 1)) { _ in
                    PillStackContent(model: model, now: model.currentTime())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .environment(\.glassOpacity, model.settings.glassOpacity)
    }
}

struct PillStackContent: View {
    static let width: CGFloat = 420
    static let rowHeight: CGFloat = 56
    static let spacing: CGFloat = 8
    /// Room around the capsules for their shadow, which the panel would otherwise clip.
    static let margin: CGFloat = 16

    /// The stack's size with `rows` capsules, pills and notice together.
    static func size(rows: Int) -> CGSize {
        let height = CGFloat(rows) * rowHeight + CGFloat(max(rows - 1, 0)) * spacing
        return CGSize(width: width + 2 * margin, height: height + 2 * margin)
    }

    let model: OverlayModel
    let now: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: Self.spacing) {
            ForEach(model.pillMeetings) { meeting in
                Pill(model: model, meeting: meeting, now: now)
            }
            if let notice = model.notice {
                Label(notice.text, systemImage: "calendar.badge.minus")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 18)
                    .frame(width: Self.width, height: Self.rowHeight, alignment: .leading)
                    .glassSurface(.card, in: Capsule())
            }
        }
        .padding(Self.margin)
    }
}

/// "Team Sync / Starts in 1:42 · Room 4B · Zoom" with a ring that fills up to the start.
private struct Pill: View {
    let model: OverlayModel
    let meeting: Meeting
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            ProgressRing(progress: AlertText.progress(toward: meeting.start, now: now, leadTime: model.timing.leadTime))
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.title)
                    .font(.system(size: 14, weight: .semibold))
                Text(AlertText.pillLine(for: meeting, now: now))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                if meeting.joinLink != nil {
                    Button("Join \(meeting.title)", systemImage: "video.fill") { model.join(meeting.id) }
                        .buttonStyle(CircleButtonStyle(prominent: true))
                        .help("Join \(meeting.title)")
                }
                Button("Expand alert", systemImage: "arrow.up.left.and.arrow.down.right") { model.expandPill() }
                    .buttonStyle(CircleButtonStyle())
                    .help("Expand alert")
                Button("Dismiss \(meeting.title)", systemImage: "xmark") { model.dismissPill(meeting.id) }
                    .buttonStyle(CircleButtonStyle())
                    .help("Dismiss \(meeting.title)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(width: PillStackContent.width, height: PillStackContent.rowHeight)
        .glassSurface(.card, in: Capsule())
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(1.5)
    }
}
