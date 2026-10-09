import XCTest
@testable import CtoK

// Covers the strings added with the Android 1.2.18–1.2.20 features: that every shipped
// language has them, that their placeholders format, and that the text built from them
// (spoken reminder, lock-screen subtitle) comes out right.
@MainActor
final class ParityStringsTests: XCTestCase {

    private static let languages = ["en", "de", "es", "fr", "gl", "pt-BR", "ru", "tr"]

    private func bundle(_ language: String, file: StaticString = #filePath, line: UInt = #line) -> Bundle? {
        let app = Bundle(for: WorkoutManager.self)
        guard let path = app.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else {
            XCTFail("No \(language).lproj in the app bundle", file: file, line: line)
            return nil
        }
        return bundle
    }

    private func string(_ key: String, _ language: String) -> String? {
        guard let bundle = bundle(language) else { return nil }
        let value = bundle.localizedString(forKey: key, value: "\u{1}missing", table: nil)
        return value == "\u{1}missing" ? nil : value
    }

    // MARK: - Coverage

    func testPlainStringsExistInEveryLanguage() {
        let keys = [
            "history_week_section_this_week", "history_month_section_this_month",
            "settings_skip_warmup_cooldown", "settings_skip_warmup_cooldown_caption",
            "settings_periodic_time_cues", "settings_periodic_time_cue_interval",
        ]
        for language in Self.languages {
            for key in keys {
                let value = string(key, language)
                XCTAssertNotNil(value, "\(key) missing in \(language)")
                XCTAssertFalse(value?.isEmpty ?? true, "\(key) empty in \(language)")
                XCTAssertFalse(value?.contains("%") ?? false, "\(key) in \(language) has a stray placeholder")
            }
        }
    }

    func testOnlyEnglishKeepsTheEnglishWording() {
        // Guards against a language silently falling back to the English text.
        let key = "settings_skip_warmup_cooldown"
        let english = string(key, "en")
        XCTAssertEqual(english, "Skip warm-up and cool-down")
        for language in Self.languages where language != "en" {
            XCTAssertNotEqual(string(key, language), english, language)
        }
    }

    func testComparisonLinesFormatBothPlaceholdersInEveryLanguage() {
        for language in Self.languages {
            for key in ["history_week_last_week", "history_month_last_month"] {
                guard let format = string(key, language) else { XCTFail("\(key) missing in \(language)"); continue }
                let text = String(format: format, "6.3", "51:00")
                XCTAssertTrue(text.contains("6.3"), "\(key)/\(language): \(text)")
                XCTAssertTrue(text.contains("51:00"), "\(key)/\(language): \(text)")
                XCTAssertFalse(text.contains("%"), "\(key)/\(language): \(text)")
                XCTAssertLessThan(text.range(of: "6.3")!.lowerBound, text.range(of: "51:00")!.lowerBound,
                                  "\(key)/\(language): distance should come before duration")
            }
        }
        XCTAssertEqual(String(format: string("history_week_last_week", "en") ?? "", "6.3", "51:00"),
                       "Last week: 6.3 km · 51:00")
        XCTAssertEqual(String(format: string("history_month_last_month", "en") ?? "", "13.9", "1:52:00"),
                       "Last month: 13.9 km · 1:52:00")
    }

    func testTimeRemainingFormatsItsDurationInEveryLanguage() {
        for language in Self.languages {
            guard let format = string("tts_time_remaining", language) else {
                XCTFail("tts_time_remaining missing in \(language)"); continue
            }
            let text = String(format: format, "DURATION")
            XCTAssertTrue(text.contains("DURATION"), "\(language): \(text)")
            XCTAssertNotEqual(text, "DURATION", "\(language) should add wording around the duration")
            XCTAssertFalse(text.contains("%"), "\(language): \(text)")
        }
    }

    func testRunsRemainingFormatsItsCountInEveryLanguage() {
        for language in Self.languages {
            guard let format = string("notification_runs_remaining", language) else {
                XCTFail("notification_runs_remaining missing in \(language)"); continue
            }
            for count in [0, 1, 2, 5, 21] {
                let text = String(format: format, locale: Locale(identifier: language), count)
                XCTAssertTrue(text.contains("\(count)"), "\(language)/\(count): \(text)")
                XCTAssertFalse(text.contains("%"), "\(language)/\(count): \(text)")
                XCTAssertGreaterThan(text.count, "\(count)".count, "\(language)/\(count): \(text)")
            }
        }
    }

    func testRunsRemainingPicksSingularAndPlural() {
        func text(_ language: String, _ count: Int) -> String {
            String(format: string("notification_runs_remaining", language) ?? "missing",
                   locale: Locale(identifier: language), count)
        }
        XCTAssertEqual(text("en", 1), "1 run left")
        XCTAssertEqual(text("en", 2), "2 runs left")
        XCTAssertEqual(text("en", 0), "0 runs left")
        XCTAssertEqual(text("de", 1), "1 Lauf übrig")
        XCTAssertEqual(text("de", 2), "2 Läufe übrig")
        XCTAssertEqual(text("es", 1), "1 carrera restante")
        XCTAssertEqual(text("es", 3), "3 carreras restantes")
        XCTAssertEqual(text("ru", 2), "Осталось пробежек: 2")
        XCTAssertEqual(text("tr", 4), "4 koşu kaldı")
    }

    func testWorkoutCountLabelFollowsEachLanguagesPluralRules() {
        // The catalog forms are "<n> <label>"; see workoutsLabel(count:), which drops the number.
        func label(_ language: String, _ count: Int) -> String {
            // Plural rules come from the formatting locale, not the bundle the string was loaded from.
            let counted = String(format: string("history_stats_workouts", language) ?? "missing",
                                 locale: Locale(identifier: language), count)
            guard let space = counted.firstIndex(of: " ") else {
                XCTFail("\(language)/\(count): expected '<n> <label>', got \(counted)"); return counted
            }
            XCTAssertNotNil(counted[..<space].rangeOfCharacter(from: .decimalDigits), "\(language)/\(count): \(counted)")
            return String(counted[counted.index(after: space)...])
        }
        XCTAssertEqual(label("en", 1), "workout")
        XCTAssertEqual(label("en", 0), "workouts")
        XCTAssertEqual(label("en", 2), "workouts")
        XCTAssertEqual(label("de", 1), "Trainingseinheit")
        XCTAssertEqual(label("de", 3), "Trainingseinheiten")
        XCTAssertEqual(label("fr", 1), "séance")
        XCTAssertEqual(label("fr", 2), "séances")
        // Russian has three forms; a singular/plural switch showed "2 тренировок".
        XCTAssertEqual(label("ru", 1), "тренировка")
        XCTAssertEqual(label("ru", 2), "тренировки")
        XCTAssertEqual(label("ru", 4), "тренировки")
        XCTAssertEqual(label("ru", 5), "тренировок")
        XCTAssertEqual(label("ru", 11), "тренировок")
        XCTAssertEqual(label("ru", 21), "тренировка")
        XCTAssertEqual(label("ru", 22), "тренировки")
        XCTAssertEqual(label("ru", 0), "тренировок")
        for language in Self.languages {
            for count in [0, 1, 2, 5, 1000] {
                XCTAssertFalse(label(language, count).isEmpty, "\(language)/\(count)")
            }
        }
    }

    func testWorkoutsLabelNeverShowsTheNumber() {
        for count in [0, 1, 2, 5, 21, 1000, 12345] {
            let label = workoutsLabel(count: count)
            XCTAssertFalse(label.isEmpty, "\(count)")
            XCTAssertNil(label.rangeOfCharacter(from: .decimalDigits), "\(count): \(label)")
            XCTAssertFalse(label.contains("%") || label.contains("history_stats"), "\(count): \(label)")
            XCTAssertFalse(label.hasPrefix(" ") || label.hasSuffix(" "), "\(count): '\(label)'")
        }
        XCTAssertNotEqual(workoutsLabel(count: 1), workoutsLabel(count: 2))
    }

    // MARK: - Text built from them

    func testSpokenDurationCoversSecondsMinutesAndBoth() {
        let seconds = Interval.spokenDuration(seconds: 45)
        let minutes = Interval.spokenDuration(seconds: 120)
        let both = Interval.spokenDuration(seconds: 90)
        XCTAssertTrue(seconds.contains("45"))
        XCTAssertTrue(minutes.contains("2"))
        XCTAssertFalse(minutes.contains("0"), "A whole number of minutes shouldn't mention zero seconds")
        XCTAssertTrue(both.contains("1") && both.contains("30"))
        for text in [seconds, minutes, both] {
            XCTAssertFalse(text.contains("%"), text)
            XCTAssertFalse(text.contains("tts_duration"), text)
        }
    }

    func testIntervalAnnouncementStillSpeaksItsDuration() {
        // `announcement` was refactored onto spokenDuration; the run/walk wording must be unchanged.
        let run = Interval(type: .run, durationSeconds: 90)
        XCTAssertEqual(run.announcement,
                       String(format: NSLocalizedString("tts_interval_run", comment: ""), Interval.spokenDuration(seconds: 90)))
        let walk = Interval(type: .walk, durationSeconds: 60)
        XCTAssertEqual(walk.announcement,
                       String(format: NSLocalizedString("tts_interval_walk", comment: ""), Interval.spokenDuration(seconds: 60)))
        XCTAssertEqual(Interval(type: .warmup, durationSeconds: 300).announcement,
                       NSLocalizedString("tts_interval_warmup", comment: ""))
    }

    func testPeriodicReminderSpeaksTheRemainingDuration() {
        let tts = TTSManager()
        for seconds in [30, 60, 90] {
            let text = tts.text(for: .periodicTimeRemaining(seconds))
            let duration = Interval.spokenDuration(seconds: seconds)
            XCTAssertTrue(text.contains(duration), text)
            XCTAssertNotEqual(text, duration, "Should say the time is *remaining*, not just the duration")
            XCTAssertFalse(text.contains("%") || text.contains("tts_time_remaining"), text)
        }
        // Distinct from the countdown warning, which is seconds-only wording.
        XCTAssertNotEqual(tts.text(for: .periodicTimeRemaining(90)), tts.text(for: .countdownWarning(90)))
    }

    func testNowPlayingSubtitleShowsProgressAndRunsLeft() {
        func snapshot(index: Int, total: Int, runsLeft: Int) -> WorkoutState.ActiveSnapshot {
            .init(currentInterval: Interval(type: .run, durationSeconds: 60), nextInterval: nil,
                  intervalIndex: index, totalIntervals: total, remainingRunIntervals: runsLeft,
                  secondsRemainingInInterval: 30, elapsedSessionSeconds: 30, sessionId: UUID())
        }
        let progress = String(format: String(localized: "workout_interval_progress"), 3, 9)
        let runs = String.localizedStringWithFormat(NSLocalizedString("notification_runs_remaining", comment: ""), 4)
        let subtitle = WorkoutManager.nowPlayingSubtitle(snapshot(index: 2, total: 9, runsLeft: 4))
        XCTAssertEqual(subtitle, "\(progress)  •  \(runs)")
        XCTAssertTrue(subtitle.contains("3") && subtitle.contains("9") && subtitle.contains("4"))
        XCTAssertFalse(subtitle.contains("%") || subtitle.contains("notification_runs_remaining"), subtitle)

        // The count changes the text (so the lock screen actually updates as runs finish).
        XCTAssertNotEqual(subtitle, WorkoutManager.nowPlayingSubtitle(snapshot(index: 2, total: 9, runsLeft: 3)))
    }
}
