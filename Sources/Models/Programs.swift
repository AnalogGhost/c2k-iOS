enum Programs {

    static let idC25K  = "C25K"
    static let idC210K = "C210K"
    static let idB210K = "B210K"
    static let idOHR   = "OHR"
    static let idFiveKI = "5KI"

    static let c25K          = buildC25K()
    static let c210K         = buildC210K()
    static let b210K         = buildB210K()
    static let oneHourRunner = buildOneHourRunner()
    static let fiveKImprover = buildFiveKImprover()

    static func byId(_ id: String) -> WorkoutPlan {
        switch id {
        case idC25K:   return c25K
        case idC210K:  return c210K
        case idB210K:  return b210K
        case idOHR:    return oneHourRunner
        case idFiveKI: return fiveKImprover
        default: fatalError("Unknown program: \(id)")
        }
    }

    static func all() -> [WorkoutPlan] {
        [c25K, c210K, b210K, oneHourRunner, fiveKImprover]
    }

    // MARK: - Helpers

    private static func warmup()   -> Interval { Interval(type: .warmup,   durationSeconds: 300) }
    private static func cooldown() -> Interval { Interval(type: .cooldown, durationSeconds: 300) }
    private static func run(_ s: Int)  -> Interval { Interval(type: .run,  durationSeconds: s) }
    private static func walk(_ s: Int) -> Interval { Interval(type: .walk, durationSeconds: s) }

    private static func repeatRunWalk(_ times: Int, run runSec: Int, walk walkSec: Int) -> [Interval] {
        var result = [warmup()]
        for _ in 0..<times { result += [run(runSec), walk(walkSec)] }
        result.append(cooldown())
        return result
    }

    private static func day(_ week: Int, _ day: Int, _ intervals: [Interval]) -> WorkoutDay {
        WorkoutDay(week: week, day: day, intervals: intervals)
    }

    private static func uniformWeek(_ week: Int, _ intervals: [Interval]) -> [WorkoutDay] {
        [day(week, 1, intervals), day(week, 2, intervals), day(week, 3, intervals)]
    }

    private static func continuousRun(_ week: Int, _ runSec: Int) -> [WorkoutDay] {
        uniformWeek(week, [warmup(), run(runSec), cooldown()])
    }

    // MARK: - C25K

    private static func buildC25K() -> WorkoutPlan {
        let weeks: [[WorkoutDay]] = [
            uniformWeek(1, repeatRunWalk(8, run: 60, walk: 90)),
            uniformWeek(2, repeatRunWalk(6, run: 90, walk: 120)),
            uniformWeek(3, [warmup(), run(90), walk(90), run(180), walk(180),
                                     run(90), walk(90), run(180), walk(180), cooldown()]),
            uniformWeek(4, [warmup(), run(180), walk(90), run(300), walk(150),
                                     run(180), walk(90), run(300), cooldown()]),
            [
                day(5, 1, repeatRunWalk(3, run: 300, walk: 180)),
                day(5, 2, [warmup(), run(480), walk(300), run(480), walk(300), cooldown()]),
                day(5, 3, [warmup(), run(1200), cooldown()]),
            ],
            [
                day(6, 1, [warmup(), run(300), walk(180), run(480), walk(180), run(300), cooldown()]),
                day(6, 2, [warmup(), run(600), walk(180), run(600), walk(180), cooldown()]),
                day(6, 3, [warmup(), run(1320), cooldown()]),
            ],
            continuousRun(7, 1500),
            continuousRun(8, 1680),
            continuousRun(9, 1800),
        ]
        return WorkoutPlan(
            programId: idC25K,
            displayName: "Couch to 5K",
            description: "9-week program to run 5K. Start here — no fitness required.",
            weeks: weeks,
            prerequisite: nil
        )
    }

    // MARK: - C210K

    private static func buildC210K() -> WorkoutPlan {
        var weeks = c25K.weeks
        weeks += [
            uniformWeek(10, repeatRunWalk(3, run: 600, walk: 120)),
            uniformWeek(11, [warmup(), run(900), walk(180), run(900), walk(180), cooldown()]),
            uniformWeek(12, [warmup(), run(2400), walk(300), run(600), cooldown()]),
            continuousRun(13, 3000),
            continuousRun(14, 3600),
        ]
        return WorkoutPlan(
            programId: idC210K,
            displayName: "Couch to 10K",
            description: "14-week program to run 10K. Continues where C25K ends.",
            weeks: weeks,
            prerequisite: "After completing C25K"
        )
    }

    // MARK: - B210K

    private static func buildB210K() -> WorkoutPlan {
        let weeks: [[WorkoutDay]] = [
            uniformWeek(1, repeatRunWalk(3, run: 600, walk: 90)),
            uniformWeek(2, [warmup(), run(900), walk(120), run(900), cooldown()]),
            uniformWeek(3, [warmup(), run(1200), walk(120), run(900), cooldown()]),
            uniformWeek(4, [warmup(), run(1500), walk(120), run(1200), cooldown()]),
            uniformWeek(5, [warmup(), run(1800), walk(120), run(1200), cooldown()]),
            continuousRun(6, 3600),
        ]
        return WorkoutPlan(
            programId: idB210K,
            displayName: "Bridge to 10K",
            description: "6-week bridge for C25K graduates not ready to jump straight to C210K.",
            weeks: weeks,
            prerequisite: "After completing C25K"
        )
    }

    // MARK: - One Hour Runner

    private static func buildOneHourRunner() -> WorkoutPlan {
        let runDurations = [1980, 2100, 2220, 2400, 2580, 2700, 2820, 3000, 3120, 3300, 3420, 3480, 3600]
        let weeks = runDurations.enumerated().map { i, secs in continuousRun(i + 1, secs) }
        return WorkoutPlan(
            programId: idOHR,
            displayName: "One Hour Runner",
            description: "13-week progression from 30 to 60 minutes of continuous running.",
            weeks: weeks,
            prerequisite: "After completing B210K or C25K"
        )
    }

    // MARK: - 5K Improver

    private static func buildFiveKImprover() -> WorkoutPlan {
        let weeks: [[WorkoutDay]] = [
            uniformWeek(1, repeatRunWalk(5, run: 180, walk: 90)),
            uniformWeek(2, repeatRunWalk(4, run: 300, walk: 120)),
            uniformWeek(3, repeatRunWalk(3, run: 420, walk: 120)),
            uniformWeek(4, [warmup(), run(600), walk(180), run(600), walk(180), run(300), cooldown()]),
            uniformWeek(5, [warmup(), run(900), walk(180), run(720), cooldown()]),
            uniformWeek(6, repeatRunWalk(2, run: 900, walk: 180)),
            uniformWeek(7, [warmup(), run(1200), walk(180), run(720), cooldown()]),
            continuousRun(8, 1800),
        ]
        return WorkoutPlan(
            programId: idFiveKI,
            displayName: "5K Improver",
            description: "8-week speed and stamina program for runners who can already complete 5K.",
            weeks: weeks,
            prerequisite: "For runners who can already complete 5K"
        )
    }
}
