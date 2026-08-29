import XCTest
@testable import DJMemoryCore

final class LibrarySelectionTests: XCTestCase {
    func testRetainsWhenStillVisible() {
        let id = UUID()
        let kept = LibrarySelection.retainingIfPresent(id, among: [id, UUID()])
        XCTAssertEqual(kept, id)
    }

    func testClearsWhenHiddenByFilter() {
        let selected = UUID()
        let visible = [UUID(), UUID()]
        XCTAssertNil(LibrarySelection.retainingIfPresent(selected, among: visible))
    }

    func testClearsWhenRemovedOnRefresh() {
        let gone = UUID()
        XCTAssertNil(LibrarySelection.retainingIfPresent(gone, among: [UUID()] as [UUID]))
    }

    func testNilSelectionStaysNil() {
        XCTAssertNil(LibrarySelection.retainingIfPresent(nil as UUID?, among: [UUID()]))
    }

    func testFilterThenRetainMatchesSearchHide() {
        let keep = LibrarySessionSummary(
            archive: archive(filename: "Keep.wav"),
            matchedTracklist: nil,
            context: SetContext(sessionID: UUID(), venue: "Room 2")
        )
        let drop = LibrarySessionSummary(
            archive: archive(filename: "Drop.wav"),
            matchedTracklist: nil
        )
        let filtered = LibrarySessionSearch().filter(
            [keep, drop],
            query: "room 2",
            appDisplayName: { _ in "Serato DJ Pro" }
        )
        XCTAssertEqual(
            LibrarySelection.retainingIfPresent(keep.id, among: filtered.map(\.id)),
            keep.id
        )
        XCTAssertNil(LibrarySelection.retainingIfPresent(drop.id, among: filtered.map(\.id)))
    }

    func testDateFilterClearsAbsentSelection() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 9, hour: 12))!
        let today = LibrarySessionSummary(
            archive: archive(filename: "Today.wav", detectedAt: now),
            matchedTracklist: nil
        )
        let older = LibrarySessionSummary(
            archive: archive(
                filename: "Older.wav",
                detectedAt: calendar.date(byAdding: .day, value: -3, to: now)!
            ),
            matchedTracklist: nil
        )
        let filtered = LibrarySessionSearch().filter(
            [today, older],
            query: "",
            dateFilter: .today,
            appDisplayName: { _ in "Serato DJ Pro" },
            calendar: calendar,
            now: now
        )
        XCTAssertEqual(
            LibrarySelection.retainingIfPresent(today.id, among: filtered.map(\.id)),
            today.id
        )
        XCTAssertNil(LibrarySelection.retainingIfPresent(older.id, among: filtered.map(\.id)))
    }

    private func archive(
        filename: String,
        detectedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> ArchiveMetadata {
        ArchiveMetadata(
            sessionID: UUID(),
            sourceAppID: "serato",
            detectedAt: detectedAt,
            completedAt: detectedAt.addingTimeInterval(20),
            sourcePath: "/Source/\(filename)",
            archivePath: "/Archive/\(filename)",
            fileSize: 100,
            originalFilename: filename,
            durationSeconds: 60
        )
    }
}
