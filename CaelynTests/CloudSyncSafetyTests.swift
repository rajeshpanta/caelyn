import SwiftData
import XCTest
@testable import Caelyn

/// The tests that have to pass before a single byte of her history is allowed near
/// CloudKit. Every one of them is about the same promise: turning sync on is not
/// allowed to lose, duplicate, or invent anything.
@MainActor
final class CloudSyncSafetyTests: XCTestCase {

    // MARK: - The store-identity proof

    /// **The single most important assertion in this release.**
    ///
    /// Enabling sync swaps `cloudKitDatabase: .none` for `.private(...)`. If that
    /// also changed the file on disk, an existing user would relaunch into an empty
    /// store and conclude that Caelyn had eaten years of her history. It doesn't —
    /// the configuration keeps the same default URL and only changes how the store
    /// is mirrored — and this test is here so that stays true.
    func testEnablingSyncOpensTheSameStoreFileAndNotABlankOne() {
        let local = ModelConfiguration(schema: Persistence.schema,
                                       isStoredInMemoryOnly: false,
                                       cloudKitDatabase: .none)
        let synced = ModelConfiguration(schema: Persistence.schema,
                                        isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .private(Persistence.cloudKitContainerID))

        XCTAssertEqual(local.url, synced.url,
                       "Turning sync on must reuse the existing store file. A different URL here means every upgrading user opens a blank Caelyn.")
    }

    /// The schema CloudKit will mirror is exactly the schema the app already ships.
    /// If a model were added to one and not the other, sync would quietly drop it.
    func testSyncMirrorsEveryModelTheAppPersists() {
        let names = Set(Persistence.schema.entities.map(\.name))
        XCTAssertEqual(names, ["CycleEntry", "UserProfile"],
                       "A model was added or removed without deciding whether it syncs.")
    }

    // MARK: - CloudKit model compatibility

    /// CloudKit refuses unique constraints, and SwiftData surfaces that as a store
    /// that will not open. The models were built without them; this keeps it that way.
    func testNoModelDeclaresAUniqueConstraint() throws {
        for entity in Persistence.schema.entities {
            for property in entity.properties {
                guard let attribute = property as? Schema.Attribute else { continue }
                XCTAssertFalse(attribute.isUnique,
                               "\(entity.name).\(attribute.name) is unique — CloudKit cannot mirror this store.")
            }
        }
    }

    /// CloudKit makes every attribute optional on the server, so a non-optional
    /// property with no default cannot round-trip. Both models were written with
    /// defaults throughout; a new property added without one would break sync for
    /// everybody, silently, at launch.
    func testEveryStoredPropertyCanSurviveACloudRoundTrip() throws {
        for entity in Persistence.schema.entities {
            for property in entity.properties {
                guard let attribute = property as? Schema.Attribute else { continue }
                XCTAssertTrue(attribute.isOptional || attribute.defaultValue != nil,
                              "\(entity.name).\(attribute.name) is required and has no default — CloudKit cannot rehydrate it.")
            }
        }
    }

    /// Relationships have their own CloudKit rules (must be optional, must have an
    /// inverse). Caelyn has none, which is why those rules cannot be broken. If one
    /// ever appears, this test is the reminder to go and read them.
    func testThereAreStillNoRelationshipsToGetWrong() {
        for entity in Persistence.schema.entities {
            XCTAssertTrue(entity.relationships.isEmpty,
                          "\(entity.name) gained a relationship — check the CloudKit optional/inverse rules before shipping.")
        }
    }

    // MARK: - Sync is off until she says so

    /// Nothing syncs by default. A privacy-first app does not start uploading
    /// reproductive health because it was updated.
    func testSyncIsOffUntilSheTurnsItOn() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: Persistence.syncEnabledKey)
        defaults.removeObject(forKey: Persistence.syncEnabledKey)
        XCTAssertFalse(Persistence.isSyncEnabled, "A fresh install must not sync.")
        if let previous { defaults.set(previous, forKey: Persistence.syncEnabledKey) }
    }

    /// The container is private. A public database would publish her cycle history
    /// to every user of the app.
    func testTheContainerIsTheUsersPrivateOne() {
        XCTAssertEqual(Persistence.cloudKitContainerID,
                       "iCloud.smallpanta-icould.com.caelynperiodtracker")
        // `.private` is the only database Caelyn ever names. This asserts the
        // literal in Persistence, so switching to `.public` fails here first.
        let source = Persistence.syncDatabaseDescription
        XCTAssertEqual(source, "private")
    }
}
