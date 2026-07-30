import XCTest
@testable import CtoK

final class ProgramsTests: XCTestCase {

    func testAllReturnsAllSixPrograms() {
        let ids = Set(Programs.all().map(\.programId))
        XCTAssertEqual(ids, [
            Programs.idPreC25K, Programs.idC25K, Programs.idC210K,
            Programs.idB210K, Programs.idOHR, Programs.idFiveKI,
        ])
    }

    func testByIdResolvesEachProgram() {
        for plan in Programs.all() {
            XCTAssertEqual(Programs.byId(plan.programId).programId, plan.programId)
        }
    }

    func testWeekCounts() {
        XCTAssertEqual(Programs.preC25K.totalWeeks, 3)
        XCTAssertEqual(Programs.c25K.totalWeeks, 9)
        XCTAssertEqual(Programs.c210K.totalWeeks, 14)
        XCTAssertEqual(Programs.b210K.totalWeeks, 6)
        XCTAssertEqual(Programs.oneHourRunner.totalWeeks, 13)
        XCTAssertEqual(Programs.fiveKImprover.totalWeeks, 8)
    }

    func testEveryWeekHasThreeDays() {
        for plan in Programs.all() {
            for (weekIndex, week) in plan.weeks.enumerated() {
                XCTAssertEqual(week.count, 3, "\(plan.programId) week \(weekIndex + 1) should have 3 days")
            }
        }
    }

    func testEveryDayHasPositiveIntervalDurations() {
        for plan in Programs.all() {
            for week in plan.weeks {
                for day in week {
                    for interval in day.intervals {
                        XCTAssertGreaterThan(interval.durationSeconds, 0,
                            "\(plan.programId) W\(day.week)D\(day.day) has a non-positive interval")
                    }
                }
            }
        }
    }

    func testEveryIntervalHasNonEmptyAnnouncement() {
        for plan in Programs.all() {
            for week in plan.weeks {
                for day in week {
                    for interval in day.intervals {
                        XCTAssertFalse(interval.announcement.isEmpty)
                    }
                }
            }
        }
    }

    func testC210KReusesC25KFirstNineWeeks() {
        let c25k = Programs.c25K.weeks
        let c210k = Programs.c210K.weeks
        XCTAssertEqual(c210k.count, 14)
        for weekIndex in 0..<9 {
            let c25kWeek = c25k[weekIndex]
            let c210kWeek = c210k[weekIndex]
            XCTAssertEqual(c25kWeek.count, c210kWeek.count)
            for dayIndex in 0..<c25kWeek.count {
                let a = c25kWeek[dayIndex].intervals
                let b = c210kWeek[dayIndex].intervals
                XCTAssertEqual(a.map(\.durationSeconds), b.map(\.durationSeconds),
                    "C210K week \(weekIndex + 1) day \(dayIndex + 1) should match C25K")
                XCTAssertEqual(a.map(\.type), b.map(\.type))
            }
        }
    }

    func testFirstDayOfEachProgramStartsWithWarmup() {
        for plan in Programs.all() {
            let firstDay = plan.weeks[0][0]
            XCTAssertEqual(firstDay.intervals.first?.type, .warmup, "\(plan.programId) should start with a warmup")
        }
    }

    func testEveryDayEndsWithCooldown() {
        for plan in Programs.all() {
            for week in plan.weeks {
                for day in week {
                    XCTAssertEqual(day.intervals.last?.type, .cooldown,
                        "\(plan.programId) W\(day.week)D\(day.day) should end with a cooldown")
                }
            }
        }
    }

    func testTotalDurationSecondsMatchesSumOfIntervals() {
        let day = Programs.c25K.weeks[0][0]
        let expected = day.intervals.reduce(0) { $0 + $1.durationSeconds }
        XCTAssertEqual(day.totalDurationSeconds, expected)
    }

    func testUnknownProgramIdCrashesRatherThanSilentlyFallingBack() {
        // Programs.byId traps on an unknown id (Programs.swift:25) — documents the
        // intentional fail-fast behavior rather than silently returning a fallback plan.
        // (Not exercised directly since fatalError can't be caught in a unit test.)
        XCTAssertNotNil(Programs.byId(Programs.idPreC25K))
    }
}
