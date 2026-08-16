import SwiftUI

/// First-run wizard / gear-icon settings panel. Uses a local draft that's
/// only committed to UserDefaults on Save; Cancel discards it. This is
/// distinct from the native Cmd+, Settings window (SettingsView), which is
/// immediate-apply - same fields, two different interaction models because
/// this view also has to carry the "welcome, first run" flow that a
/// Settings scene can't (it doesn't auto-open on launch).
struct SetupView: View {
    let isFirstRun: Bool
    var onDismiss: () -> Void

    @State private var draft: AppSettings

    init(isFirstRun: Bool, onDismiss: @escaping () -> Void) {
        self.isFirstRun = isFirstRun
        self.onDismiss = onDismiss
        _draft = State(initialValue: SettingsStore.load())
    }

    var body: some View {
        Form {
            Section {
                Text(isFirstRun ? "Welcome to GOD Lister" : "Listing Settings")
                    .font(.title2.bold())
                Text(isFirstRun
                    ? "Let's set your default options. You can change these again later from the settings button."
                    : "Update your default options below.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Depth") {
                Stepper(value: $draft.defaultDepth, in: -1...99) {
                    HStack {
                        Text("Depth")
                        Spacer()
                        Text("\(draft.defaultDepth)").foregroundStyle(.secondary)
                    }
                }
                Text("0 = just the selected folder's own name. 1 = files and folders directly inside it. Higher = that many levels deep. -1 = no limit, scan everything.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Xbox 360 GOD recognition") {
                Toggle("Recognize GOD game folders (an 8-character Title ID name) and label them with the game's name", isOn: $draft.godRecognition)
                Text("Uses a bundled Title ID lookup table. IDs not in the table are left as their raw folder name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Also label content-type folders inside a detected game folder (DLC, Title Updates, Arcade, etc.)", isOn: $draft.contentTypeRecognition)
                    .disabled(!draft.godRecognition)
                Text("Uses a fixed, offline table of known STFS content-type codes. Individual DLC files inside a DLC folder are also labeled with their DLC name, using a bundled catalog lookup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ask for these options") {
                Picker("", selection: $draft.askEveryTime) {
                    Text("Every time I run this program").tag(true)
                    Text("Just once — use these defaults from now on").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section("Full Disk Access") {
                FDAStatusView()
            }

            HStack {
                if !isFirstRun {
                    Button("Cancel") { onDismiss() }
                }
                Spacer()
                Button("Save") {
                    SettingsStore.save(draft)
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .onChange(of: draft.godRecognition) { _, stillOn in
            if !stillOn { draft.contentTypeRecognition = false }
        }
        .frame(minWidth: 480, minHeight: 480)
    }
}
