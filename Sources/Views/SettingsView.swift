import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(UserPreferences.self) private var prefs

    @State private var weightText: String = ""

    var body: some View {
        @Bindable var prefs = prefs

        List {
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
                }
            }

            Section("Workout") {
                Toggle("Vibrate on interval change", isOn: $prefs.vibrationEnabled)
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
