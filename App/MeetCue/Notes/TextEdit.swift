import Foundation

/// The smallest edit that turns one text into another, for applying outside changes to an open
/// editor without disturbing the caret, scroll position or undo history.
enum TextEdit {
    struct Change: Equatable {
        /// UTF-16 range of the old text to replace.
        var range: NSRange
        var replacement: String
    }

    /// Nil when the texts are equal. Never splits a surrogate pair.
    static func minimalChange(from old: String, to new: String) -> Change? {
        let old = Array(old.utf16)
        let new = Array(new.utf16)
        guard old != new else { return nil }
        let limit = min(old.count, new.count)
        var prefix = 0
        while prefix < limit, old[prefix] == new[prefix] { prefix += 1 }
        if prefix > 0, UTF16.isLeadSurrogate(old[prefix - 1]) { prefix -= 1 }
        var suffix = 0
        while suffix < limit - prefix, old[old.count - 1 - suffix] == new[new.count - 1 - suffix] { suffix += 1 }
        if suffix > 0, UTF16.isTrailSurrogate(old[old.count - suffix]) { suffix -= 1 }
        let replacement = String(decoding: new[prefix..<(new.count - suffix)], as: UTF16.self)
        return Change(range: NSRange(location: prefix, length: old.count - prefix - suffix), replacement: replacement)
    }

    /// Where `selection` lands once `change` has been applied: positions before it stay, positions
    /// after it shift, and positions inside it move to its end.
    static func selection(_ selection: NSRange, through change: Change, newLength: Int) -> NSRange {
        let replacedEnd = NSMaxRange(change.range)
        let insertedEnd = change.range.location + (change.replacement as NSString).length
        func map(_ position: Int) -> Int {
            if position <= change.range.location { return position }
            if position >= replacedEnd { return position + insertedEnd - replacedEnd }
            return insertedEnd
        }
        let start = map(selection.location)
        let end = map(NSMaxRange(selection))
        return clamped(NSRange(location: start, length: end - start), toLength: newLength)
    }

    static func clamped(_ range: NSRange, toLength length: Int) -> NSRange {
        let start = min(max(range.location, 0), length)
        let end = min(max(NSMaxRange(range), start), length)
        return NSRange(location: start, length: end - start)
    }
}
