import Foundation

/// External URLs surfaced from the app. Centralized so they can never drift
/// between paywall, Settings, and App Store Connect metadata.
///
/// Both pages are hosted on GitHub Pages from the `docs/` folder of the Caelyn
/// repo. Editing the markup in `docs/privacy.html` / `docs/terms.html` and
/// pushing to the publishing branch updates the live page within ~1 minute —
/// no app update required for legal copy revisions. Make sure the App Store
/// Connect Privacy Policy URL field matches `privacyPolicy` below.
enum AppURLs {
    static let privacyPolicy = URL(string: "https://rajeshpanta.github.io/caelyn/privacy.html")!
    static let termsOfUse    = URL(string: "https://rajeshpanta.github.io/caelyn/terms.html")!
}
