import Foundation
import XCTest

@testable import LongNoteCore

/// Filesystem tests for `FileArticleStore`, run against a throwaway temp dir.
final class FileArticleStoreTests: XCTestCase {

  private var tempDirectory: URL!
  private var store: FileArticleStore!

  override func setUpWithError() throws {
    tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("LongNoteTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    store = FileArticleStore(rootDirectory: tempDirectory)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDirectory)
    tempDirectory = nil
    store = nil
  }

  func testSaveAndLoadRoundTrip() throws {
    let article = Article(title: "Draft", paragraphs: [.empty(.body)])
    try store.save(article)

    let loaded = try store.load(article.id)
    XCTAssertEqual(loaded, article)
  }

  func testLoadMissingReturnsNil() throws {
    XCTAssertNil(try store.load(UUID()))
  }

  func testLoadAllSortedNewestFirst() throws {
    let older = Article(
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let newer = Article(
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
    try store.save(older)
    try store.save(newer)

    let all = try store.loadAll()
    XCTAssertEqual(all.map(\.id), [newer.id, older.id])
  }

  func testLoadAllIgnoresUnrelatedFiles() throws {
    let unrelated = tempDirectory.appendingPathComponent("README.txt")
    try "junk".write(to: unrelated, atomically: true, encoding: .utf8)

    try store.save(Article(title: "real"))
    XCTAssertEqual(try store.loadAll().count, 1)
  }

  func testDeleteRemovesDocument() throws {
    let article = Article(title: "to go")
    try store.save(article)
    try store.delete(article.id)

    XCTAssertNil(try store.load(article.id))
    XCTAssertTrue(try store.loadAll().isEmpty)
  }

  func testDeleteMissingIsNoOp() throws {
    XCTAssertNoThrow(try store.delete(UUID()))
  }

  func testImageStorageLayout() throws {
    let article = Article(title: "with image")
    try store.save(article)

    let data = Data([0x01, 0x02, 0x03, 0x04])
    let url = try store.saveImage(data, for: article.id, fileName: "pic.jpg")

    XCTAssertEqual(url, store.imageURL(for: article.id, fileName: "pic.jpg"))
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    let loaded = try store.loadImage("pic.jpg", for: article.id)
    XCTAssertEqual(loaded, data)
    XCTAssertNil(try store.loadImage("nope.jpg", for: article.id))
  }

  func testDeleteRemovesImagesToo() throws {
    let article = Article(title: "image owner")
    try store.save(article)
    try store.saveImage(Data([0xAA]), for: article.id, fileName: "pic.jpg")

    try store.delete(article.id)
    XCTAssertFalse(
      FileManager.default.fileExists(
        atPath: store.imageURL(for: article.id, fileName: "pic.jpg").path))
  }
}
