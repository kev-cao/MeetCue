import Foundation

public enum OverlayState: Equatable, Sendable {
    case waiting
    case alert
    case snoozed(until: Date)
    case pill
    case dismissed
    case notesCard
    case hidden
    case done
}

public enum OverlayEvent: Equatable, Sendable {
    case alertTime(quiet: Bool)
    case snooze(until: Date)
    case snoozeElapsed
    case moveToCorner
    case expand
    /// `afterStart` is whether the meeting had started when the user dismissed it.
    case dismiss(afterStart: Bool)
    case join
    case startTime
    case hide
    case show
    case meetingEnded
}

/// Settings and note state that decide whether a meeting gets the notes card.
public struct NotesPolicy: Equatable, Sendable {
    public var showAtStart: Bool
    public var onlyWithNotes: Bool
    public var hideAtEnd: Bool
    public var hasNotes: Bool

    public init(showAtStart: Bool = true, onlyWithNotes: Bool = true, hideAtEnd: Bool = true, hasNotes: Bool) {
        self.showAtStart = showAtStart
        self.onlyWithNotes = onlyWithNotes
        self.hideAtEnd = hideAtEnd
        self.hasNotes = hasNotes
    }

    /// Whether a card would have anything to show.
    var hasCardContent: Bool { hasNotes || !onlyWithNotes }
    /// Whether the card appears without the user asking for it.
    var wantsCard: Bool { showAtStart && hasCardContent }
}

public enum OverlayReducer {
    /// The next state for one meeting. Events that don't apply leave the state unchanged.
    public static func reduce(_ state: OverlayState, _ event: OverlayEvent, notes: NotesPolicy) -> OverlayState {
        let cardOrDone: OverlayState = notes.wantsCard ? .notesCard : .done
        let cardOnRequest: OverlayState = notes.hasCardContent ? .notesCard : .done
        switch (state, event) {
        case (.done, .show):
            return cardOnRequest
        case (.done, _):
            return .done
        case (.notesCard, .meetingEnded), (.hidden, .meetingEnded):
            return notes.hideAtEnd ? .done : state
        case (_, .meetingEnded):
            return .done
        case (.waiting, .alertTime(let quiet)):
            return quiet ? .dismissed : .alert
        case (.alert, .snooze(let until)):
            return .snoozed(until: until)
        case (.snoozed, .snoozeElapsed), (.snoozed, .startTime):
            return .alert
        case (.alert, .moveToCorner):
            return .pill
        case (.pill, .expand):
            return .alert
        case (.alert, .dismiss(let afterStart)), (.pill, .dismiss(let afterStart)):
            return afterStart ? cardOrDone : .dismissed
        case (.waiting, .join), (.alert, .join), (.snoozed, .join), (.pill, .join), (.dismissed, .join), (.hidden, .join):
            return cardOnRequest
        case (.waiting, .startTime), (.pill, .startTime), (.dismissed, .startTime):
            return cardOrDone
        case (.notesCard, .hide):
            return .hidden
        case (.hidden, .show):
            return .notesCard
        default:
            return state
        }
    }
}
