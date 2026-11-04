import Foundation
import Observation

/// Settles the overlays at each deadline with a single timer, and whenever the meetings or quiet
/// mode change. The app delegate also calls `refresh()` on wake, clock, time zone and day changes.
@MainActor
final class AlertScheduler {
    private let model: OverlayModel
    /// Runs after every refresh, so work due at meeting ends, like carrying notes over, runs on time.
    var onRefresh: (@MainActor () -> Void)?
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    init(model: OverlayModel) {
        self.model = model
    }

    func start() {
        trackInputs()
        trackSchedule()
        refresh()
    }

    func refresh() {
        model.refresh()
        apply(model.schedule)
        onRefresh?()
    }

    /// The timer is re-armed on every refresh, not only when the wake date changes, because a
    /// timer armed before a clock change can fire at the wrong wall-clock time.
    private func apply(_ schedule: OverlaySchedule) {
        timer?.invalidate()
        timer = nil
        if let wake = schedule.wake {
            let timer = Timer(fire: wake, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        if schedule.holdsActivity, activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Waiting to show a meeting alert"
            )
        } else if !schedule.holdsActivity, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
    }

    private func trackInputs() {
        withObservationTracking {
            _ = model.store.meetings
            _ = model.store.filter
            _ = model.quiet.until
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.refresh()
                self?.trackInputs()
            }
        }
    }

    /// Alert and pill actions refresh the model directly, so the schedule can change without a call to `refresh()`.
    private func trackSchedule() {
        withObservationTracking {
            _ = model.schedule
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.apply(self.model.schedule)
                self.trackSchedule()
            }
        }
    }
}
