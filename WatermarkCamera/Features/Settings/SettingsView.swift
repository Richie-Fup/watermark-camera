import SwiftUI

struct SettingsView: View {
    @AppStorage("temperatureUnit") private var temperatureUnit: String = defaultUnit

    private static var defaultUnit: String {
        Locale.current.measurementSystem == .us ? "fahrenheit" : "celsius"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Watermark Preferences") {
                    Picker("Temperature Unit", selection: $temperatureUnit) {
                        Text("Celsius °C").tag("celsius")
                        Text("Fahrenheit °F").tag("fahrenheit")
                    }
                }

                Section {
                    // WeatherKit 归属声明（Apple 要求）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.body)
                            Text("Apple Weather")
                                .font(.body)
                            Spacer()
                            Link(destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!) {
                                HStack(spacing: 2) {
                                    Text("Legal")
                                    Image(systemName: "arrow.up.right").font(.caption2)
                                }
                                .font(.caption)
                            }
                        }
                        Text("Weather data is provided by Apple Weather via WeatherKit. It is only used locally to generate watermarks when you capture, and is never uploaded to third-party servers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Weather Data")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    Text("All location and weather data is used only on-device to generate watermarks and is never uploaded to any third-party server.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // Guideline 5.1.1(i)：隐私政策须在 App 内易于访问；用户协议一并放入 Legal 便于查阅
                Section("Legal") {
                    Link(destination: URL(string: "https://richie-fup.github.io/common-pages/watermark-camera/privacy.html")!) {
                        legalRow(title: "Privacy Policy")
                    }
                    Link(destination: URL(string: "https://richie-fup.github.io/common-pages/watermark-camera/terms.html")!) {
                        legalRow(title: "Terms of Use")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("EVOXIA")
                            .font(.headline)
                        Text("EVOXIA builds premium software, AI applications, and end-to-end digital solutions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://evoxia.cn/")!) {
                            HStack(spacing: 4) {
                                Text("Visit Website")
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Developer")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func legalRow(title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
