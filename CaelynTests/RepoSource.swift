import Foundation
import XCTest

/// Reading Caelyn's own source, for the audits that assert on it.
///
/// **Why these need a shared reader.** A handful of tests check the source
/// directly rather than the behaviour: that no reader derives a day from an
/// instant, that the entitlements actually carry Sign in with Apple, that a
/// promise is worded the same on both import routes. They are the right tool
/// for invariants that are invisible at runtime until a specific user hits them.
///
/// They also only work where the repository is. Run the suite on a physical
/// device and `#filePath` points at a path on the build machine that does not
/// exist on the phone, so every one of them fails with `NSCocoaErrorDomain 260`
/// — twenty-six red tests that say nothing about the app. That is worse than
/// useless: it buries real device failures in noise, and it teaches whoever sees
/// it next that a red device run is normal.
///
/// So they skip when the tree is unreachable, and only there. On the machine
/// that has the source they run exactly as before.
enum RepoSource {

    /// The repository root, or `nil` when the source is not reachable from here.
    static var root: URL? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // CaelynTests
            .deletingLastPathComponent()      // repo root
        return FileManager.default.fileExists(atPath: root.appending(path: "Caelyn").path)
            ? root : nil
    }

    /// Read one file relative to the repository root.
    ///
    /// Throws `XCTSkip` rather than an error when the source tree is not present,
    /// so a device run reports these as skipped instead of failed.
    static func read(_ relativePath: String) throws -> String {
        guard let root else {
            throw XCTSkip("source tree not reachable from this host (device run)")
        }
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }
}
