import Foundation

/// Whether a search result's title is what was searched for (#374). Plenty of sources answer a search with loosely
/// related titles; the ones that match come first, and the rest stay behind "Show Other Results" (#770).
public enum TitleMatch {
    nonisolated(unsafe) private static let normalizedCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 5000
        return cache
    }()

    /// Lower case, half-width, simplified, with spaces and punctuation gone.
    public static func normalize(_ text: String) -> String {
        if let cached = normalizedCache.object(forKey: text as NSString) { return cached as String }
        var value = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        value = value.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? value
        let normalized = String(value.lowercased().filter { $0.isLetter || $0.isNumber })
        normalizedCache.setObject(normalized as NSString, forKey: text as NSString)
        return normalized
    }

    private static let season = try! NSRegularExpression(pattern: "(第[一二三四五六七八九十百零0-9]+[季部期]|s[0-9]+|season[0-9]+)$")

    private struct Wanted {
        let full: String
        let core: String

        init?(_ keyword: String) {
            full = TitleMatch.normalize(keyword)
            guard !full.isEmpty else { return nil }
            let range = NSRange(full.startIndex..., in: full)
            if let found = TitleMatch.season.firstMatch(in: full, range: range),
               let cut = Range(found.range, in: full), cut.lowerBound != full.startIndex {
                core = String(full[..<cut.lowerBound])
            } else {
                core = full
            }
        }

        func matches(_ title: String) -> Bool { matchesNormalized(TitleMatch.normalize(title)) }

        func matchesNormalized(_ name: String) -> Bool {
            if name.contains(full) || (core != full && name.contains(core)) { return true }
            guard core.count >= 3 else { return false }
            var remaining = core[...]
            for character in name {
                if character == remaining.first {
                    remaining = remaining.dropFirst()
                    if remaining.isEmpty { return true }
                }
            }
            return false
        }
    }

    /// The title holds the keyword, or, for a keyword of three characters or more, all of its characters in order.
    public static func matches(title: String, keyword: String) -> Bool {
        Wanted(keyword).map { $0.matches(title) } ?? true
    }

    /// The items whose title matches and the rest, each in their original order.
    public static func split<T>(_ items: [T], keyword: String, title: (T) -> String) -> (matching: [T], other: [T]) {
        guard let wanted = Wanted(keyword) else { return (items, []) }
        var matching: [T] = [], other: [T] = []
        matching.reserveCapacity(items.count / 2)
        other.reserveCapacity(items.count / 2)
        for item in items {
            if wanted.matches(title(item)) { matching.append(item) } else { other.append(item) }
        }
        return (matching, other)
    }

    public static func ordered<T>(_ items: [T], keyword: String, title: (T) -> String) -> [T] {
        let parts = split(items, keyword: keyword, title: title)
        return parts.matching + parts.other
    }
}
