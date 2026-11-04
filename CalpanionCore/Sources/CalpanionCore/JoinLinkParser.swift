import Foundation

public enum JoinLinkParser {
    public struct Result: Equatable, Sendable {
        public let joinLink: JoinLink?
        public let location: String?
    }

    /// Finds the event's video link and returns the location with video links
    /// removed. The URL field wins over the location, which wins over the notes.
    public static func parse(url: URL?, location: String?, notes: String?) -> Result {
        let locationLinks = videoLinks(in: location ?? "")
        let fieldLink = url.flatMap { url in service(for: url).map { JoinLink(url: url, service: $0) } }
        let joinLink = fieldLink ?? locationLinks.first?.link ?? videoLinks(in: notes ?? "").first?.link
        return Result(joinLink: joinLink, location: cleanLocation(location, removing: locationLinks.map(\.range)))
    }

    public static func service(for url: URL) -> VideoService? {
        guard let host = url.host()?.lowercased() else { return nil }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") { return .zoom }
        if host == "meet.google.com" { return .meet }
        if host == "teams.microsoft.com" || host == "teams.live.com" { return .teams }
        return nil
    }

    private static func videoLinks(in text: String) -> [(link: JoinLink, range: NSRange)] {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return [] }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let url = match.url, let service = service(for: url) else { return nil }
            return (JoinLink(url: url, service: service), match.range)
        }
    }

    private static func cleanLocation(_ location: String?, removing ranges: [NSRange]) -> String? {
        guard let location else { return nil }
        let text = NSMutableString(string: location)
        for range in ranges.sorted(by: { $0.location > $1.location }) {
            text.replaceCharacters(in: range, with: "")
        }
        let edges = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;|·-"))
        let cleaned = (text as String).trimmingCharacters(in: edges)
        return cleaned.isEmpty ? nil : cleaned
    }
}
