import Foundation

@MainActor
final class ScanState: ObservableObject {
    @Published var root: String?
    @Published var outputPath: String?
    @Published var previewMode = false
    @Published var isRunning = false

    @Published var previewContent: String?
    @Published var previewSummary: ListingSummary?

    @Published var resultMessage: String?
    @Published var resultIsError = false
    @Published var lastRunNeededFullDiskAccess = false

    var canGenerate: Bool {
        guard root != nil else { return false }
        return previewMode || outputPath != nil
    }
}
