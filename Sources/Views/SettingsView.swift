import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(UserPreferences.self) private var prefs

    var body: some View {
        @Bindable var prefs = prefs

        List {
            Section("Voice") {
                Toggle("Voice announcements", isOn: $prefs.ttsEnabled)

                if prefs.ttsEnabled {
                    Toggle("Countdown warnings (10s, 5s)", isOn: $prefs.countdownWarnings)
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
                }
            }

            Section("Workout") {
                Toggle("Vibrate on interval change", isOn: $prefs.vibrationEnabled)
                Toggle("GPS tracking", isOn: $prefs.gpsEnabled)
                Toggle("Keep screen on during workout", isOn: $prefs.keepScreenOn)
            }
        }
        .navigationTitle("Settings")
    }
}
