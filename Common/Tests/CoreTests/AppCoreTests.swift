import XCTest
@testable import CommonCore

final class AppCoreTests: XCTestCase {
    func testMondayWeekIncludesBothSidesOfNewYear() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 12, day: 30)))
        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 5)))
        let nextMonday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 6)))

        XCTAssertEqual(sunday.mondayWeekStart(calendar: calendar), monday)
        XCTAssertTrue(sunday.isInMondayWeek(of: monday, calendar: calendar))
        XCTAssertFalse(nextMonday.isInMondayWeek(of: monday, calendar: calendar))
    }

    func testMondayWeekAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let sunday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 30)))
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 3, day: 24)))

        XCTAssertEqual(sunday.mondayWeekStart(calendar: calendar), monday)
    }

    func testExample() throws {
        // XCTest Documentation
        // https://developer.apple.com/documentation/xctest

        // Defining Test Cases and Test Methods
        // https://developer.apple.com/documentation/xctest/defining_test_cases_and_test_methods
    }
}
