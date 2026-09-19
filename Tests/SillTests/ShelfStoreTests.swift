import XCTest
@testable import FeatureShelf

final class ShelfStoreTests: XCTestCase {
    private var temp: URL!
    private var root: URL { temp.appendingPathComponent("Shelf") }

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temp)
    }

    private func makeFile(_ name: String, bytes: Int) throws -> URL {
        let url = temp.appendingPathComponent(name)
        try Data(repeating: 7, count: bytes).write(to: url)
        return url
    }

    func testCopyInSurvivesDeletingTheOriginal() throws {
        let store = ShelfStore(root: root)
        let original = try makeFile("report.pdf", bytes: 100)
        let item = try ShelfStore.copyIn(original, root: root)
        store.insert(item)
        try FileManager.default.removeItem(at: original)

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.url(for: item).path))
        XCTAssertEqual(item.fileName, "report.pdf")
        XCTAssertEqual(item.byteSize, 100)
    }

    func testCopyInFolderCountsNestedBytes() throws {
        let folder = temp.appendingPathComponent("Folder")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Sub"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 30).write(to: folder.appendingPathComponent("a"))
        try Data(repeating: 1, count: 20).write(to: folder.appendingPathComponent("Sub/b"))
        let item = try ShelfStore.copyIn(folder, root: root)
        XCTAssertEqual(item.byteSize, 50)
    }

    func testManifestRoundTrips() throws {
        let store = ShelfStore(root: root)
        let item = try ShelfStore.copyIn(try makeFile("a.txt", bytes: 5), root: root)
        store.insert(item)
        store.setPinned(true, ids: [item.id])

        let reloaded = ShelfStore(root: root)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items.first?.id, item.id)
        XCTAssertEqual(reloaded.items.first?.isPinned, true)
    }

    func testMissingFilesAreDroppedOnLoad() throws {
        let store = ShelfStore(root: root)
        let item = try ShelfStore.copyIn(try makeFile("a.txt", bytes: 5), root: root)
        store.insert(item)
        try FileManager.default.removeItem(at: root.appendingPathComponent(item.id.uuidString))
        XCTAssertTrue(ShelfStore(root: root).items.isEmpty)
    }

    func testClearKeepsPinned() throws {
        let store = ShelfStore(root: root)
        let keep = try ShelfStore.copyIn(try makeFile("keep", bytes: 1), root: root)
        let drop = try ShelfStore.copyIn(try makeFile("drop", bytes: 1), root: root)
        store.insert(keep)
        store.insert(drop)
        store.setPinned(true, ids: [keep.id])

        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.id), [keep.id])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(drop.id.uuidString).path))
    }

    func testPruneByCountRemovesOldestUnpinnedFirst() throws {
        let store = ShelfStore(root: root)
        let base = Date(timeIntervalSince1970: 1000)
        let oldPinned = ShelfItem(fileName: "p", byteSize: 1, addedAt: base, isPinned: true)
        let old = ShelfItem(fileName: "o", byteSize: 1, addedAt: base.addingTimeInterval(1))
        let mid = ShelfItem(fileName: "m", byteSize: 1, addedAt: base.addingTimeInterval(2))
        let new = ShelfItem(fileName: "n", byteSize: 1, addedAt: base.addingTimeInterval(3))
        [oldPinned, old, mid, new].forEach(store.insert)

        let removed = store.prune(maxItems: 2, maxBytes: .max)
        XCTAssertEqual(removed.map(\.id), [old.id, mid.id])
        XCTAssertEqual(Set(store.items.map(\.id)), [oldPinned.id, new.id])
    }

    func testPruneByBytes() throws {
        let store = ShelfStore(root: root)
        let base = Date(timeIntervalSince1970: 1000)
        let big = ShelfItem(fileName: "big", byteSize: 900, addedAt: base)
        let small = ShelfItem(fileName: "small", byteSize: 200, addedAt: base.addingTimeInterval(1))
        store.insert(big)
        store.insert(small)

        store.prune(maxItems: 100, maxBytes: 1000)
        XCTAssertEqual(store.items.map(\.id), [small.id])
    }

    func testPinnedItemsAreNeverPruned() throws {
        let store = ShelfStore(root: root)
        let pinned = ShelfItem(fileName: "p", byteSize: 5000, isPinned: true)
        store.insert(pinned)
        XCTAssertTrue(store.prune(maxItems: 0, maxBytes: 10).isEmpty)
        XCTAssertEqual(store.items.count, 1)
    }

    func testWriteStoresData() throws {
        let item = try ShelfStore.write(Data("hello".utf8), fileName: "Snippet.txt", root: root)
        let url = ShelfStore.url(for: item, root: root)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "hello")
        XCTAssertEqual(item.byteSize, 5)
    }
}
