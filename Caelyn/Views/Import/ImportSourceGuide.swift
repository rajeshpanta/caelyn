import Foundation

/// What to tell her about getting a file out of each app.
///
/// The instructions are the feature. Caelyn can read a Clue export perfectly, but
/// that is worth nothing if she never finds the button that produces one — and
/// both Clue and Flo bury it. None of this mentions a file format, because which
/// format it is happens to be Caelyn's problem, not hers.
struct ImportSourceGuide {

    /// Where picking this row leads.
    enum Route: Equatable {
        /// Straight to Apple Health — there is nothing to explain first.
        case appleHealth
        /// Instructions, then the file browser.
        case fileAfterInstructions
        /// Instructions, then Apple Health. For an app that can hand its history
        /// to Health but has to be switched on inside that app first, so sending
        /// her to Apple Health cold would find nothing and look broken.
        case appleHealthAfterInstructions
    }

    /// Stable identity for this row.
    ///
    /// Derived from the title, never from `source` — two rows can legitimately
    /// share a source (Apple Health handles both its own row and Period Tracker's),
    /// and keying identity on the source would collapse them into one as far as
    /// SwiftUI and VoiceOver are concerned.
    var key: String {
        title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    /// Shown on the picker row. Stored rather than derived, because a row can
    /// name the app she is leaving while routing through Apple Health.
    let title: String
    /// Which importer ultimately handles it.
    let source: ImportSourceID
    let route: Route
    let subtitle: String
    let icon: String
    /// Numbered steps. Empty for sources that need none.
    let steps: [String]
    /// Anything she should know before she starts.
    let note: String?
    /// The button at the end of the instructions.
    let actionLabel: String

    static let all: [ImportSourceGuide] = [appleHealth, clue, flo, periodTracker, caelyn, another]

    /// The order on the picker: what most people are switching from, first.
    static let pickable: [ImportSourceGuide] = [appleHealth, clue, flo, periodTracker, another, caelyn]

    static let appleHealth = ImportSourceGuide(
        title: "Apple Health",
        source: .appleHealth,
        route: .appleHealth,
        subtitle: "Cycle and fertility history already on your iPhone",
        icon: "heart.text.square.fill",
        steps: [],
        note: "Nothing leaves your iPhone. Caelyn reads what's already stored there and shows you what it found before adding anything.",
        actionLabel: "Continue"
    )

    /// **Period Tracker by GP Apps** — the big magenta flower with a yellow centre.
    /// GP International LLC, `com.gpapps.ptrackerlite`, v12.1.1.
    ///
    /// Not to be confused with ABISHKKING / Simple Design's "Period Tracker Period
    /// Calendar", whose icon is a pink diary with a small white flower on it. The
    /// two are easy to mix up and the subtitle exists to stop her picking wrong.
    ///
    /// **Why Apple Health rather than a file.** GP Apps genuinely does produce an
    /// emailed backup file — their support pages tell people to tap the attachment
    /// to restore, and refer to "your backup file" — so unlike most trackers there
    /// really is a portable artifact. But its format is documented nowhere: no
    /// published schema, no open-source parser, no reverse-engineered example.
    /// Guessing at it would risk silently mis-reading years of reproductive
    /// history. Their App Store listing states HealthKit support, and Caelyn
    /// already reads sixteen types out of Health, so that is the route until one
    /// real backup file can be examined.
    static let periodTracker = ImportSourceGuide(
        title: "Period Tracker",
        source: .appleHealth,
        route: .appleHealthAfterInstructions,
        subtitle: "By GP Apps — the big pink flower — through Apple Health",
        icon: "camera.macro",
        steps: [
            "Open Period Tracker and go to its Settings.",
            "Find the Health or Apple Health option — it may sit under Data or General.",
            "Turn it on, and allow it to write your cycle data when iOS asks.",
            "Give it a minute to hand everything over.",
            "Come back here and Caelyn will show you what it found."
        ],
        note: "This is the app by GP Apps with the big pink flower, not the pink diary one. Apple Health is the way across: your periods, temperatures, cervical mucus, ovulation and pregnancy tests and symptoms can travel this way. Your written notes, moods and weight can't — Apple Health has nowhere to put them. Caelyn will show you exactly what it found before anything is added.",
        actionLabel: "Continue to Apple Health"
    )

    static let clue = ImportSourceGuide(
        title: "Clue",
        source: .clue,
        route: .fileAfterInstructions,
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
        note: "Clue doesn't record where each cycle started. Caelyn works that out from your bleeding days.",
        actionLabel: "Choose the file"
    )

    static let flo = ImportSourceGuide(
        title: "Flo",
        source: .flo,
        route: .fileAfterInstructions,
        subtitle: "The dates of your past periods",
        icon: "calendar.circle.fill",
        steps: [
            "Open Flo and tap your picture, then Help.",
            "Scroll down and tap Contact us.",
            "Ask them to send you your data.",
            "Flo emails you two files. Save the one ending in .json.",
            "Come back here and pick it."
        ],
        note: "Flo's file records when your periods were, but not how heavy each day was. Caelyn will show you exactly what it found before anything is added.",
        actionLabel: "Choose the file"
    )

    static let caelyn = ImportSourceGuide(
        title: "Caelyn backup",
        source: .caelyn,
        route: .fileAfterInstructions,
        subtitle: "A backup you exported from Caelyn",
        icon: "arrow.counterclockwise.circle.fill",
        steps: [
            "Find the file you saved from Settings, then Export data.",
            "Pick it here."
        ],
        note: "Everything comes back exactly as you had it.",
        actionLabel: "Choose the file"
    )

    static let another = ImportSourceGuide(
        title: "Another app",
        source: .genericCSV,
        route: .fileAfterInstructions,
        subtitle: "Almost anything with dates in it",
        icon: "square.and.arrow.down.fill",
        steps: [
            "Export your history from the app you use now.",
            "Save the file to Files, or open it from your email.",
            "Pick it here."
        ],
        note: "Caelyn works out what the file is on its own, and brings across everything it recognises. It'll tell you what it couldn't.",
        actionLabel: "Choose the file"
    )

    /// True when the instructions end at the file browser.
    var needsAFile: Bool { route == .fileAfterInstructions }

    /// True when the row shows instructions before doing anything.
    var hasInstructions: Bool { route != .appleHealth }
}
