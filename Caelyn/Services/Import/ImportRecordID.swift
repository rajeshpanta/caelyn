import Foundation
import CryptoKit

/// Gives a row from a file the same kind of stable identity a HealthKit sample
/// gets from its UUID.
///
/// Derived from source, day and field — deliberately **not** from the value. That
/// choice is what makes the three re-import cases behave sensibly:
///
///   • the same file twice → same id, same value → recognised as already merged;
///   • a corrected re-export → same id, new value → updates in place;
///   • a different app's file → different id → goes through the normal conflict
///     rules instead of impersonating the first app's record.
enum ImportRecordID {

    /// Namespace prefix so an id can never collide with a real HealthKit UUID.
    private static let namespace = "caelyn.import.v1"

    static func make(source: ImportSourceID, dayKey: String, fieldKey: String) -> UUID {
        let seed = "\(namespace)|\(source.rawValue)|\(dayKey)|\(fieldKey)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        // Shape it as a v4-looking UUID so nothing downstream is surprised by it.
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                           bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11],
                           bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
