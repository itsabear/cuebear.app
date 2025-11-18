//
//  CueListTests.swift
//  Cue Bear Tests
//
//  Unit tests for CueList functionality
//

import XCTest
@testable import Cue_Bear

class CueListTests: XCTestCase {

    func testDefaultCueList() {
        let list = CueList.defaultMain
        XCTAssertEqual(list.name, "Main")
        XCTAssertTrue(list.songs.isEmpty)
        XCTAssertTrue(list.isValid)
    }

    func testCueListValidation() {
        let validList = CueList(name: "Test", songs: [])
        XCTAssertTrue(validList.isValid)

        let invalidList = CueList(name: "   ", songs: [])
        XCTAssertFalse(invalidList.isValid)

        let emptyList = CueList(name: "", songs: [])
        XCTAssertFalse(emptyList.isValid)
    }

    func testCueListTouch() {
        var list = CueList(name: "Test", songs: [])
        let originalDate = list.modifiedAt

        // Wait a bit
        Thread.sleep(forTimeInterval: 0.1)

        list.touch()
        XCTAssertGreaterThan(list.modifiedAt, originalDate)
    }

    func testCueListEquality() {
        let id = UUID()
        let list1 = CueList(id: id, name: "Test", songs: [])
        let list2 = CueList(id: id, name: "Test", songs: [])

        XCTAssertEqual(list1, list2)
    }

    func testCueListCodable() throws {
        let originalList = CueList(name: "Test", songs: [])

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalList)

        let decoder = JSONDecoder()
        let decodedList = try decoder.decode(CueList.self, from: data)

        XCTAssertEqual(originalList.id, decodedList.id)
        XCTAssertEqual(originalList.name, decodedList.name)
        XCTAssertEqual(originalList.songs.count, decodedList.songs.count)
    }

    func testCueListTemplates() {
        let templates = CueList.templates

        XCTAssertFalse(templates.isEmpty)
        XCTAssertTrue(templates.contains(where: { $0.name == "Main Show" }))
        XCTAssertTrue(templates.contains(where: { $0.name == "Rehearsal" }))
        XCTAssertTrue(templates.contains(where: { $0.name == "Backup" }))

        // All templates should be valid
        for template in templates {
            XCTAssertTrue(template.isValid)
        }
    }
}
