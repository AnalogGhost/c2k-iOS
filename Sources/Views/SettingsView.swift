import SwiftUI
import AVFoundation
import UIKit

struct SettingsView: View {
    @Environment(UserPreferences.self) private var prefs

    @State private var weightText: String = ""
    @State private var hapticsPreview = HapticsPreview()
    @State private var voiceTester = VoiceTester()
    @State private var pendingRestartLanguage: AppLanguage?
    @State private var languageBeforeChange: AppLanguage?

    var body: some View {
        @Bindable var prefs = prefs

        List {
            Section(String(localized: "settings_language_section")) {
                Picker(String(localized: "settings_language_label"), selection: $prefs.appLanguage) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .disabled(WorkoutManager.shared.isRunning)
                .onChange(of: prefs.appLanguage) { oldValue, newValue in
                    guard newValue != oldValue, !languageAlreadyActive(newValue, previous: oldValue) else { return }
                    languageBeforeChange = oldValue
                    pendingRestartLanguage = newValue
                }

                Button(String(localized: "settings_language_open_ios_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote)
            }

            Section("Voice") {
                Toggle("Voice announcements", isOn: $prefs.ttsEnabled)

                if prefs.ttsEnabled {
                    Toggle("Countdown warnings", isOn: $prefs.countdownWarnings)

                    if prefs.countdownWarnings {
                        SecondsSlider(label: String(localized: "First warning"), seconds: $prefs.countdownWarning1, range: 3...30)
                        SecondsSlider(label: String(localized: "Second warning"), seconds: $prefs.countdownWarning2, range: 3...30)
                    }

                    Toggle(String(localized: "Mid-run encouragement"), isOn: $prefs.midIntervalCues)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Voice speed")
                            Spacer()
                            Text(String(format: "%.1f×", prefs.ttsSpeechRate))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $prefs.ttsSpeechRate, in: 0.7...1.3, step: 0.1)
                        HStack {
                            Text("Slow").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Fast").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Voice volume")
                            Spacer()
                            Text(String(format: "%.0f%%", prefs.ttsVolume * 100))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $prefs.ttsVolume, in: 0.2...1.0, step: 0.2)
                        HStack {
                            Text("Quiet").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("Loud").font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Button(String(localized: "settings_tts_test_button")) {
                            voiceTester.speakTest(
                                rate: prefs.ttsSpeechRate,
                                volume: prefs.ttsVolume,
                                language: prefs.appLanguage.bcp47 ?? Locale.preferredLanguages.first
                            )
                        }
                        .disabled(voiceTester.status == .playing || voiceTester.status == .initializing)
                        .accessibilityIdentifier("settings-test-voice")

                        if let text = voiceTester.status.localizedText {
                            Text(text)
                                .font(.caption)
                                .foregroundStyle(voiceTester.status.isFailure ? Color.red : Color.secondary)
                        }
                        if voiceTester.status.isFailure {
                            Text("settings_tts_test_help")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button(String(localized: "settings_tts_open_ios_settings")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.footnote)
                        }
                    }
                }
            }

            Section("Workout") {
                Toggle("Vibrate on interval change", isOn: $prefs.vibrationEnabled)
                if prefs.vibrationEnabled {
                    Picker(String(localized: "settings_vibration_strength"), selection: $prefs.vibrationStrength) {
                        ForEach(VibrationStrength.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: prefs.vibrationStrength) { _, newValue in
                        hapticsPreview.preview(newValue)
                    }
                }
                Toggle("Treadmill mode (disables GPS)", isOn: $prefs.treadmillMode)
                Toggle("GPS tracking", isOn: $prefs.gpsEnabled)
                    .disabled(prefs.treadmillMode)
                Toggle("Keep screen on during workout", isOn: $prefs.keepScreenOn)
            }

            Section("Weight") {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Not set", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                        .onChange(of: weightText) { _, newValue in
                            if let parsed = Double(newValue), parsed > 0 {
                                prefs.weightKg = prefs.weightUnit.toKg(parsed)
                            } else if newValue.isEmpty {
                                prefs.weightKg = nil
                            }
                        }
                    Picker("Unit", selection: $prefs.weightUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                Text("Used only to estimate calories burned. Never leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            weightText = prefs.weightKg.map { formatWeight(prefs.weightUnit.fromKg($0)) } ?? ""
        }
        .onChange(of: prefs.weightUnit) { _, newUnit in
            weightText = prefs.weightKg.map { formatWeight(newUnit.fromKg($0)) } ?? ""
        }
        .alert(
            String(localized: "settings_language_restart_title"),
            isPresented: Binding(
                get: { pendingRestartLanguage != nil },
                set: { if !$0 { pendingRestartLanguage = nil } }
            )
        ) {
            Button(String(localized: "settings_language_restart_now"), role: .destructive) {
                exit(0)
            }
            Button("Cancel", role: .cancel) {
                if let previous = languageBeforeChange { prefs.appLanguage = previous }
                pendingRestartLanguage = nil
                languageBeforeChange = nil
            }
        } message: {
            Text("settings_language_restart_body")
        }
    }

    // True when the picked language is already what the app is running in, so no restart
    // prompt is needed.
    private func languageAlreadyActive(_ selected: AppLanguage, previous: AppLanguage) -> Bool {
        if let code = selected.bcp47 {
            return code == LanguageController.activeBundleLanguage
        }
        // .system: already active only if there was no override to begin with.
        return previous == .system
    }

    private func formatWeight(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded()
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}

private struct SecondsSlider: View {
    let label: String
    @Binding var seconds: Int
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(seconds) \(String(localized: "s"))").foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(seconds) },
                    set: { seconds = Int($0.rounded()) }
                ),
                in: range,
                step: 1
            )
        }
    }
}

// Previews the interval-change haptic when the strength picker changes. Spins up a
// CHHapticEngine on first use and shuts it down after a short idle so Settings never
// holds the engine open.
@MainActor
final class HapticsPreview {
    private let player = HapticsPlayer()
    private var idleShutdown: Task<Void, Never>?

    func preview(_ strength: VibrationStrength) {
        player.configure(strength: strength)
        player.start()
        player.play(.intervalChange)
        idleShutdown?.cancel()
        idleShutdown = Task { [weak player] in
            try? await Task.sleep(for: .seconds(2))
            player?.stop()
        }
    }
}
