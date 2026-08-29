import Foundation

/// Decides what Caelyn is allowed to call her, and refuses everything else.
///
/// This exists as a pure value type with no dependencies because getting it wrong
/// is uniquely embarrassing: "Good morning, nil", "Welcome back,
/// x7f3k2@privaterelay.appleid.com", or a cheerful greeting to an empty string are
/// all worse than simply not using a name. Every greeting in the app goes through
/// `PersonalName.usable(_:)`, and the answer is an optional on purpose — `nil`
/// means "say the warm, nameless version", which is what 1.2 already said.
enum PersonalName {

    /// The longest name Caelyn will render inline. Past this a greeting stops
    /// reading as friendly and starts wrapping across the header.
    static let maxLength = 24

    /// Returns a name safe to greet her by, or nil if there isn't one.
    ///
    /// Rejects, in order: nothing at all, whitespace-only, anything shaped like an
    /// email address (which is how Apple's private relay and most real addresses
    /// arrive), control characters, and absurd lengths. Everything else is trimmed
    /// and returned as she typed it — including names with spaces, hyphens and
    /// apostrophes, which are ordinary in real names and must not be mangled.
    static func usable(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // An address is never a name. Apple hands back a private-relay address when
        // she chooses Hide My Email, and greeting her by it would both look broken
        // and put an identifier on screen she deliberately hid.
        guard !looksLikeAnEmailAddress(trimmed) else { return nil }

        // Newlines and control characters would break the header layout.
        guard !trimmed.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            return nil
        }

        // A name has to contain at least one letter. "..." or "123" is not a name.
        guard trimmed.contains(where: { $0.isLetter }) else { return nil }

        guard trimmed.count <= maxLength else { return nil }
        return trimmed
    }

    /// True for anything shaped like an address, including Apple's private relay.
    ///
    /// Deliberately broad: an `@` anywhere is enough. A real name never contains
    /// one, so there is no cost to over-rejecting here and a real cost to letting
    /// one through.
    static func looksLikeAnEmailAddress(_ value: String) -> Bool {
        if value.contains("@") { return true }
        return value.lowercased().hasSuffix("privaterelay.appleid.com")
    }

    /// Builds the name Apple's `PersonNameComponents` describes, preferring the
    /// given name because "Good morning, Maya" is what a friend says and
    /// "Good morning, Maya Okonkwo" is what a dentist's receptionist says.
    static func fromApple(givenName: String?, familyName: String?) -> String? {
        if let given = usable(givenName) { return given }
        // No given name — a lone family name is still better than nothing, but only
        // if it passes the same checks.
        return usable(familyName)
    }
}
