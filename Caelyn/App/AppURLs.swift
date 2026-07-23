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
    static let support       = URL(string: "https://rajeshpanta.github.io/caelyn/support.html")!

    /// Where users email issues. Also referenced in the hosted support/privacy pages.
    static let supportEmail  = "rajesh.panta08@gmail.com"

    /// A pre-filled "email us" link — one tap opens Mail with a subject + the app
    /// version, so bug reports arrive with the context needed to debug them.
    static func supportMailto(appVersion: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "mailto"
        comps.path = supportEmail
        comps.queryItems = [
            URLQueryItem(name: "subject", value: "Caelyn Support"),
            URLQueryItem(name: "body", value: "\n\n—\nSent from Caelyn \(appVersion) · \(ProcessInfo.processInfo.operatingSystemVersionString)")
        ]
        return comps.url ?? support
    }
}
