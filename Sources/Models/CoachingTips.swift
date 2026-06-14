enum CoachingTips {

    private static let c25k: [Int: String] = [
        1: "Run at a pace where you can still talk. The walk breaks are part of the training.",
        2: "You made it through week 1 — your body is already adapting. Keep the pace easy.",
        3: "Longer intervals this week. Focus on steady breathing: in for 2 steps, out for 2.",
        4: "Four different run lengths today. This builds mental toughness as much as fitness.",
        5: "Day 3 this week is the famous milestone: 20 minutes of continuous running. You've earned it.",
        6: "You're over the halfway mark. The long runs are building your aerobic base.",
        7: "25 minutes continuous. Not everyone gets this far — you're a runner now.",
        8: "28 minutes. The goal is almost in reach. Don't speed up — save it for next week.",
        9: "This is graduation week. 30 minutes, then celebrate!",
    ]

    private static let c210k: [Int: String] = [
        10: "Back to intervals to rebuild your base for the longer distance. Stay easy.",
        11: "Longer combined efforts. Keep the pace conversational throughout.",
        12: "40 minutes of running with a short break. Relax and don't race.",
        13: "50 minutes. If you can do this, a 10K finish is within reach.",
        14: "60 minutes — your 10K graduation run. Go get it!",
    ]

    private static let b210k: [Int: String] = [
        1: "Re-establishing the habit after C25K. Run easy, no need to push yet.",
        2: "Two longer blocks with a short rest. Aim for an even pace across both runs.",
        3: "Increasing total volume. Focus on consistent effort across both intervals.",
        4: "Nearly 45 minutes of running. You're building real 10K fitness.",
        5: "50 minutes this week. The full 60-minute graduation run is one week away.",
        6: "60 minutes — the B210K finish line. Well done!",
    ]

    private static let ohr: [Int: String] = [
        1:  "33 minutes of comfortable, easy running. Don't worry about pace, just finish.",
        4:  "40 minutes. Each week you're building genuine endurance.",
        7:  "Nearly 50 minutes. You're well past the average runner's comfort zone.",
        10: "55 minutes. The one-hour goal is one good week away.",
        13: "60 minutes — this is it. You are an hour runner!",
    ]

    private static let fiveKi: [Int: String] = [
        1: "Short, hard efforts build leg speed. Push a little harder than your usual 5K pace.",
        2: "5-minute intervals are the sweet spot for building aerobic power.",
        4: "Combination workout: longer intervals with a finishing run. This builds race stamina.",
        6: "Two 15-minute runs — solid aerobic work that will translate directly to a faster 5K.",
        8: "Graduation run: 30 minutes at 5K effort. See how far you get — it should feel good.",
    ]

    static func tip(programId: String, week: Int) -> String? {
        switch programId {
        case Programs.idC25K:   return c25k[week]
        case Programs.idC210K:  return c210k[week]
        case Programs.idB210K:  return b210k[week]
        case Programs.idOHR:    return ohr[week]
        case Programs.idFiveKI: return fiveKi[week]
        default: return nil
        }
    }
}
