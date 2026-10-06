import CoreData
import SwiftData
import XCTest
@testable import Caelyn

/// CloudKit **Production** never grows a field on its own. Development creates one
/// only when a record carrying a non-nil value for it is exported, so any attribute
/// nobody happened to fill in while testing simply never existed — and once
/// Production is missing a field, every export that touches it fails while the
/// account and the store both look perfectly healthy.
///
/// That is how build 15 shipped with fifteen fields and the deletion-tombstone
/// record type absent from Production. These two tests close the gap from both ends.
@MainActor
final class CloudKitSchemaTests: XCTestCase {

    /// Every attribute SwiftData will mirror must already exist in the deployed
    /// Production schema. Adding a property to a model without deploying it fails
    /// here, on a simulator, instead of silently in a stranger's iCloud.
    func testEveryMirroredAttributeIsDeployedToProduction() throws {
        // The schema Production is known to carry, exported with `cktool` and committed.
        let schema = try RepoSource.read("docs/cloudkit-production-schema.ckdb")
        let model = try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(
            for: [CycleEntry.self, UserProfile.self]))

        var missing: [String] = []
        for entity in model.entities {
            let name = try XCTUnwrap(entity.name)
            let block = try XCTUnwrap(Self.recordTypeBlock("CD_\(name)", in: schema),
                                      "record type CD_\(name) is not in the deployed schema")
            for attribute in entity.attributesByName.keys
                where !block.contains("CD_\(attribute) ") {
                missing.append("CD_\(name).CD_\(attribute)")
            }
        }
        XCTAssertNotNil(Self.recordTypeBlock(CloudDeletionTombstone.recordType, in: schema),
                        "the deletion tombstone record type is not in the deployed schema")
        XCTAssertEqual(missing.sorted(), [],
                       "these fields are not in CloudKit Production; run testInitializeDevelopmentSchema on a device, export Development, review, and import it to Production (docs/PHASE6_CLOUDKIT_SETUP.md §4)")
    }

    /// Creates every record type and field in the **Development** environment from
    /// the real model, using Apple's `initializeCloudKitSchema`. Opt-in only — it
    /// writes to iCloud — and it needs a signed-in device:
    ///
    ///     xcodebuild test … -only-testing:CaelynTests/CloudKitSchemaTests/testInitializeDevelopmentSchema
    ///         TEST_RUNNER_CAELYN_INIT_CLOUDKIT_SCHEMA=1
    func testInitializeDevelopmentSchema() throws {
        guard ProcessInfo.processInfo.environment["CAELYN_INIT_CLOUDKIT_SCHEMA"] == "1" else {
            throw XCTSkip("writes to the CloudKit Development environment; opt in with CAELYN_INIT_CLOUDKIT_SCHEMA=1")
        }
        let model = try XCTUnwrap(NSManagedObjectModel.makeManagedObjectModel(
            for: [CycleEntry.self, UserProfile.self]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("schema-init-\(UUID().uuidString).store")
        let description = NSPersistentStoreDescription(url: url)
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(containerIdentifier: Persistence.cloudKitContainerID)
        description.shouldAddStoreAsynchronously = false

        let container = NSPersistentCloudKitContainer(name: "CaelynSchema", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema(options: [])
    }

    private static func recordTypeBlock(_ type: String, in schema: String) -> String? {
        guard let start = schema.range(of: "RECORD TYPE \(type) (") else { return nil }
        guard let end = schema.range(of: ");", range: start.upperBound..<schema.endIndex) else { return nil }
        return String(schema[start.lowerBound..<end.upperBound])
    }
}
