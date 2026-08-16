import SwiftUI

/// Native Cmd+, Settings window - immediate-apply (every change saves right
/// away), the idiomatic macOS Settings interaction model. Same fields as
/// SetupView's wizard, deliberately no Save/Cancel here.
struct SettingsView: View {
    @State private var settings = SettingsStore.load()

    var body: some View {
        Form {
            Section("Depth") {
                Stepper(value: $settings.defaultDepth, in: -1...99) {
                    HStack {
                        Text("Depth")
                        Spacer()
                        Text("\(settings.defaultDepth)").foregroundStyle(.secondary)
                    }
                }
                Text("0 = just the selected folder's own name. 1 = files and folders directly inside it. Higher = that many levels deep. -1 = no limit, scan everything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Xbox 360 GOD recognition") {
                Toggle("Recognize GOD game folders (an 8-character Title ID name) and label them with the game's name", isOn: $settings.godRecognition)
                Toggle("Also label content-type folders inside a detected game folder (DLC, Title Updates, Arcade, etc.)", isOn: $settings.contentTypeRecognition)
                    .disabled(!settings.godRecognition)
            }

            Section("Ask for these options") {
                Picker("", selection: $settings.askEveryTime) {
                    Text("Every time I run this program").tag(true)
                    Text("Just once — use these defaults from now on").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section("Full Disk Access") {
                FDAStatusView()
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.godRecognition) { _, stillOn in
            if !stillOn { settings.contentTypeRecognition = false }
        }
        .onChange(of: settings) { _, newValue in
            SettingsStore.save(newValue)
        }
        .frame(width: 480)
        .padding()
    }
}
