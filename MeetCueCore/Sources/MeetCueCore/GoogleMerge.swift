import Foundation

public enum GoogleMerge {
    /// The Mac's meetings followed by Google's. A Google meeting that is also on the Mac is dropped,
    /// and gives each Mac copy its join link and reply; the Mac's time, title and location stay.
    public static func merge(local: [Meeting], google: [Meeting]) -> [Meeting] {
        let byID = Dictionary(google.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let localIDs = Set(local.map(\.id))
        let enriched = local.map { meeting -> Meeting in
            guard let match = byID[meeting.id] else { return meeting }
            var meeting = meeting
            meeting.joinLink = match.joinLink ?? meeting.joinLink
            if match.myStatus != .unknown {
                meeting.myStatus = match.myStatus
            }
            return meeting
        }
        return enriched + google.filter { !localIDs.contains($0.id) }
    }
}
