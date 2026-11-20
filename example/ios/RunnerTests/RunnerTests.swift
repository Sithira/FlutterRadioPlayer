import MediaPlayer
import XCTest

@testable import flutter_radio_player_ios

private func fixture(_ name: String) throws -> [[String: Any]] {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("test_fixtures/\(name)"))
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    return try XCTUnwrap(json["cases"] as? [[String: Any]])
}

private func sources(_ value: Any?) -> [RadioSourceInfo] {
    (value as? [[String: Any]] ?? []).map {
        RadioSourceInfo(
            url: $0["url"] as! String,
            id: $0["id"] as? String,
            title: $0["title"] as? String,
            artwork: $0["artwork"] as? String,
            headers: $0["headers"] as? [String: String] ?? [:]
        )
    }
}

class SharedTablesTests: XCTestCase {
    func testSelectionCases() throws {
        for testCase in try fixture("selection_cases.json") {
            let name = testCase["name"] as! String
            let selection = selectSource(
                old: sources(testCase["old"]),
                oldIndex: testCase["oldIndex"] as? Int,
                new: sources(testCase["new"]),
                initialIndex: testCase["initialIndex"] as? Int,
                id: { $0.id },
                sameStream: { $0.sameStream(as: $1) }
            )
            XCTAssertEqual(selection.index, testCase["expectedIndex"] as? Int, name)
            XCTAssertEqual(selection.keepStream, testCase["expectedStream"] as? String == "keep", name)
        }
    }

    func testURLCases() throws {
        for testCase in try fixture("url_cases.json") {
            let input = testCase["input"] as! String
            XCTAssertEqual(playableURL(input) != nil, testCase["valid"] as! Bool, "\"\(input)\"")
        }
    }

    func testStatusCases() throws {
        for testCase in try fixture("status_cases.json") {
            let inputs = testCase["inputs"] as! [String: Bool]
            let facts = PlayerFacts(
                hasSources: inputs["hasSources"]!,
                reconnectPending: inputs["reconnectPending"]!,
                failed: inputs["failed"]!,
                playRequested: inputs["playRequested"]!,
                rendering: inputs["rendering"]!
            )
            XCTAssertEqual(status(of: facts).rawValue, testCase["expected"] as! String, testCase["name"] as! String)
        }
    }
}

@MainActor
class RadioPlayerCoreTests: XCTestCase {
    func testTwoObservationsReceiveEverySnapshotInOrder() throws {
        let core = RadioPlayerCore.acquire()
        try core.setSources([])
        var first: [RadioPlayerSnapshot] = []
        var second: [RadioPlayerSnapshot] = []
        let a = core.observe { first.append($0) }
        let b = core.observe { second.append($0) }

        let list = [
            RadioSourceInfo(url: "https://a.example/s", title: "A"),
            RadioSourceInfo(url: "https://b.example/s", title: "B"),
        ]
        let afterSet = try core.setSources(list, initialIndex: 1)
        let afterVolume = core.setVolume(0.3)
        let afterEmpty = try core.setSources([])

        XCTAssertEqual(first, [afterSet, afterVolume, afterEmpty])
        XCTAssertEqual(second, first)
        XCTAssertEqual(afterSet.status, .paused)
        XCTAssertEqual(afterSet.currentSource, list[1])
        XCTAssertEqual(afterEmpty.status, .idle)
        a.invalidate()
        withExtendedLifetime(b) {}
    }

    func testOutOfRangeIndexThrowsAndChangesNothing() throws {
        let core = RadioPlayerCore.acquire()
        let before = try core.setSources([RadioSourceInfo(url: "https://a.example/s")])
        XCTAssertThrowsError(try core.play(at: 3)) { XCTAssertTrue($0 is RadioPlayerIndexError) }
        XCTAssertThrowsError(try core.setSources([], initialIndex: 0))
        XCTAssertEqual(core.snapshot, before)
        try core.setSources([])
    }

    func testInvalidURLFailsWithoutNetwork() throws {
        let core = RadioPlayerCore.acquire()
        try core.setSources([RadioSourceInfo(url: "not a url")])
        let snapshot = try core.play()
        XCTAssertEqual(snapshot.status, .error)
        XCTAssertEqual(snapshot.error?.code, .invalidSource)
        try core.setSources([])
    }

    func testReleasedObservationStopsReceiving() throws {
        let core = RadioPlayerCore.acquire()
        var count = 0
        var observation: RadioPlayerObservation? = core.observe { _ in count += 1 }
        try core.setSources([RadioSourceInfo(url: "https://a.example/s")])
        XCTAssertEqual(count, 1)
        observation = nil
        try core.setSources([])
        XCTAssertEqual(count, 1)
        XCTAssertNil(observation)
    }

    func testSetSourcesPublishesNothingBeforePlay() throws {
        let core = RadioPlayerCore.acquire()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try core.setSources([RadioSourceInfo(url: "https://a.example/s", title: "A")])
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        try core.play()
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "A")
        core.stop()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        try core.setSources([])
    }

    func testRemoteCommandsFollowListAndWrapAround() throws {
        let core = RadioPlayerCore.acquire()
        let center = MPRemoteCommandCenter.shared()
        let list = (0..<3).map { RadioSourceInfo(url: "https://s\($0).example/s") }
        try core.setSources(list, initialIndex: 2)
        try core.play()
        XCTAssertTrue(center.nextTrackCommand.isEnabled)
        XCTAssertFalse(center.changePlaybackPositionCommand.isEnabled)
        core.setOptions(RadioPlayerOptionsInfo(wrapAround: false))
        XCTAssertFalse(center.nextTrackCommand.isEnabled)
        XCTAssertTrue(center.previousTrackCommand.isEnabled)
        core.setOptions(RadioPlayerOptionsInfo())
        try core.setSources([list[0]])
        try core.play()
        XCTAssertFalse(center.nextTrackCommand.isEnabled)
        XCTAssertFalse(center.previousTrackCommand.isEnabled)
        try core.setSources([])
    }

    func testPlayOrPauseUsesPlayIntentAndNextKeepsIt() throws {
        let core = RadioPlayerCore.acquire()
        try core.setSources((0..<2).map { RadioSourceInfo(url: "https://s\($0).example/s") })
        XCTAssertEqual(core.playOrPause().status, .loading)
        XCTAssertEqual(core.next().status, .loading)
        XCTAssertEqual(core.playOrPause().status, .paused)
        XCTAssertEqual(core.next().status, .paused)
        XCTAssertEqual(core.snapshot.currentIndex, 0)
        try core.setSources([])
    }

}
