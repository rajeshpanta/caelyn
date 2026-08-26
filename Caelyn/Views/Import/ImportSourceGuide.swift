import Foundation

/// What to tell her about getting a file out of each app.
///
/// The instructions are the feature. Caelyn can read a Clue export perfectly, but
/// that is worth nothing if she never finds the button that produces one — and
/// both Clue and Flo bury it. None of this mentions a file format, because which
/// format it is happens to be Caelyn's problem, not hers.
struct ImportSourceGuide {

    let source: ImportSourceID
    let subtitle: String
    let icon: String
    /// Numbered steps for getting the file. Empty for sources that need none.
    let steps: [String]
    /// Anything she should know before she starts.
    let note: String?

    static let all: [ImportSourceGuide] = [appleHealth, clue, flo, caelyn, another]

    /// The order on the picker: what most people are switching from, first.
    static let pickable: [ImportSourceGuide] = [appleHealth, clue, flo, another, caelyn]

    static let appleHealth = ImportSourceGuide(
        source: .appleHealth,
        subtitle: "Cycle and fertility history already on your iPhone",
        icon: "heart.text.square.fill",
        steps: [],
        note: "Nothing leaves your iPhone. Caelyn reads what's already stored there and shows you what it found before adding anything."
    )

    static let clue = ImportSourceGuide(
        source: .clue,
        subtitle: "Your full tracking history",
        icon: "drop.circle.fill",
        steps: [
            "Open Clue and tap the menu at the top right of your cycle view.",
            "Go to Settings, then tap Request data.",
            "Keep the password Clue shows you — you'll need it.",
            "Open the email from Clue and download the file. The link stops working after three days.",
            "The download is a zip. Touch and hold it in Files and choose Uncompress.",
            "Come back here and pick the file called measurements."
        ],
        note: "Clue doesn't record where each cycle started. Caelyn works that out from your bleeding days."
    )

    static let flo = ImportSourceGuide(
        source: .flo,
        subtitle: "The dates of your past periods",
        icon: "calendar.circle.fill",
        steps: [
            "Open Flo and tap your picture, then Help.",
            "Scroll down and tap Contact us.",
            "Ask them to send you your data.",
            "Flo emails you two files. Save the one ending in .json.",
            "Come back here and pick it."
        ],
        note: "Flo's file records when your periods were, but not how heavy each day was. Caelyn will show you exactly what it found before anything is added."
    )

    static let caelyn = ImportSourceGuide(
        source: .caelyn,
        subtitle: "A backup you exported from Caelyn",
        icon: "arrow.counterclockwise.circle.fill",
        steps: [
            "Find the file you saved from Settings, then Export data.",
            "Pick it here."
        ],
        note: "Everything comes back exactly as you had it."
    )

    static let another = ImportSourceGuide(
        source: .genericCSV,
        subtitle: "Almost anything with dates in it",
        icon: "square.and.arrow.down.fill",
        steps: [
            "Export your history from the app you use now.",
            "Save the file to Files, or open it from your email.",
            "Pick it here."
        ],
        note: "Caelyn works out what the file is on its own, and brings across everything it recognises. It'll tell you what it couldn't."
    )

    /// Title shown on the picker row.
    var title: String { source.displayName }

    /// True when picking this leads to the file browser rather than to Apple Health.
    var needsAFile: Bool { source != .appleHealth }
}
