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

    /// Period Tracker / Period Calendar — the pink diary with the white flower,
    /// by ABISHKKING on the App Store and Simple Design on Google Play.
    ///
    /// **There is no file to import.** Its only export is a PDF report for a
    /// doctor, and its backup moves data between devices rather than producing
    /// something a person can hand to another app. What it does have — stated on
    /// its own App Store listing for the current version — is Apple Health sync,
    /// and Caelyn already reads sixteen types out of Health. So the route is
    /// through Health, and the instructions exist because the switch lives inside
    /// Period Tracker: send her to Apple Health without flipping it first and
    /// Caelyn would correctly report finding nothing, which reads as broken.
    static let periodTracker = ImportSourceGuide(
        title: "Period Tracker",
        source: .appleHealth,
        route: .appleHealthAfterInstructions,
        subtitle: "The pink one with the flower — comes across through Apple Health",
        icon: "camera.macro",
        steps: [
            "Open Period Tracker and go to its Settings.",
            "Look for Apple Health — it may sit under Data, Sync, or More.",
            "Turn the sync on, and allow it to write your cycle data when iOS asks.",
            "Give it a minute to hand everything over.",
            "Come back here and Caelyn will show you what it found."
        ],
        note: "Period Tracker has no export file, so Apple Health is the way across. Your periods, temperatures, cervical mucus, ovulation and pregnancy tests and symptoms can all travel this way — notes, moods and weight can't, because Apple Health has nowhere to put them. Caelyn will show you exactly what it found before anything is added.",
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
