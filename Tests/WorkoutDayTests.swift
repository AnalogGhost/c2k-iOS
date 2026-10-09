import XCTest
@testable import CtoK

final class WorkoutDayTests: XCTestCase {

    private func day(_ intervals: Interval...) -> WorkoutDay {
        WorkoutDay(week: 1, day: 1, intervals: intervals)
    }

    private func shape(_ day: WorkoutDay) -> [String] {
        day.intervals.map { "\($0.type.rawValue):\($0.durationSeconds)" }
    }

    func testWithoutWarmupCooldownDropsWarmupAndCooldownOnly() {
        let original = day(
            Interval(type: .warmup, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .walk, durationSeconds: 90),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .cooldown, durationSeconds: 300)
        )
        XCTAssertEqual(original.withoutWarmupCooldown().intervals.map(\.type), [.run, .walk, .run])
    }

    func testWithoutWarmupCooldownPreservesOrderAndDurationsOfRemainingIntervals() {
        let original = day(
            Interval(type: .warmup, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .walk, durationSeconds: 90)
        )
        XCTAssertEqual(shape(original.withoutWarmupCooldown()), ["run:60", "walk:90"])
    }

    func testWithoutWarmupCooldownPreservesWeekAndDay() {
        let original = WorkoutDay(week: 3, day: 2, intervals: [Interval(type: .run, durationSeconds: 60)])
        let result = original.withoutWarmupCooldown()
        XCTAssertEqual(result.week, 3)
        XCTAssertEqual(result.day, 2)
    }

    func testWithoutWarmupCooldownIsANoOpWhenThereIsNoWarmupOrCooldown() {
        let original = day(Interval(type: .run, durationSeconds: 60), Interval(type: .walk, durationSeconds: 90))
        XCTAssertEqual(shape(original.withoutWarmupCooldown()), shape(original))
    }

    func testWithoutWarmupCooldownReducesTotalDurationByExactlyTheWarmupAndCooldownTime() {
        let original = day(
            Interval(type: .warmup, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .cooldown, durationSeconds: 300)
        )
        XCTAssertEqual(original.withoutWarmupCooldown().totalDurationSeconds, original.totalDurationSeconds - 600)
    }

    // Every program day ships a warm-up, a cool-down, and at least one run interval in between
    // (WorkoutManager relies on this: WorkoutEngine.start() indexes intervals[0], so an empty
    // result would crash it). If a future program ever violated this, it would silently produce
    // an empty — and crashing — day whenever this preference is on, so this guards it directly
    // against the real program data rather than just the hand-built fixtures above.
    func testWithoutWarmupCooldownNeverEmptiesARealProgramDay() {
        for plan in Programs.all() {
            for day in plan.weeks.flatMap({ $0 }) {
                let result = day.withoutWarmupCooldown()
                XCTAssertFalse(result.intervals.isEmpty,
                               "\(plan.programId) W\(day.week)D\(day.day) had no run/walk intervals left")
                XCTAssertFalse(result.intervals.contains { $0.type == .warmup || $0.type == .cooldown },
                               "\(plan.programId) W\(day.week)D\(day.day) still had a warm-up/cool-down left")
            }
        }
    }

    // MARK: - WorkoutPlan.workoutDay(week:day:skipWarmupCooldown:)

    func testPlanWorkoutDayReturnsThePlanDayUnchangedWhenNotSkipping() {
        let plan = Programs.byId(Programs.idC25K)
        let result = plan.workoutDay(week: 2, day: 3, skipWarmupCooldown: false)
        XCTAssertEqual(shape(result), shape(plan.weeks[1][2]))
        XCTAssertEqual(result.intervals.first?.type, .warmup)
        XCTAssertEqual(result.intervals.last?.type, .cooldown)
    }

    func testPlanWorkoutDayDropsWarmupAndCooldownWhenSkipping() {
        let plan = Programs.byId(Programs.idC25K)
        let full = plan.weeks[0][0]
        let result = plan.workoutDay(week: 1, day: 1, skipWarmupCooldown: true)
        XCTAssertEqual(shape(result), shape(full.withoutWarmupCooldown()))
        XCTAssertEqual(result.intervals.first?.type, .run)
        XCTAssertEqual(result.intervals.count, full.intervals.count - 2)
        XCTAssertLessThan(result.totalDurationSeconds, full.totalDurationSeconds)
    }

    func testPlanWorkoutDayUsesOneBasedWeekAndDayForEveryProgramDay() {
        for plan in Programs.all() {
            for (weekIdx, days) in plan.weeks.enumerated() {
                for dayIdx in days.indices {
                    let result = plan.workoutDay(week: weekIdx + 1, day: dayIdx + 1, skipWarmupCooldown: false)
                    XCTAssertEqual(result.week, weekIdx + 1, plan.programId)
                    XCTAssertEqual(result.day, dayIdx + 1, plan.programId)
                }
            }
        }
    }
}
