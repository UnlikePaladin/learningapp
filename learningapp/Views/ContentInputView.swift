import SwiftUI
import SwiftData
import VisionKit

enum InputMode: String, CaseIterable {
    case camera = "Camera"
    case paste = "Paste"
}

struct ContentInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((StudyMaterial) -> Void)?

    @State private var mode: InputMode = .paste
    @State private var text = ""
    @State private var showUnsupportedAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Input Mode", selection: $mode) {
                    ForEach(InputMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch mode {
                case .camera:
                    #if os(iOS)
                    if DataScannerViewController.isSupported {
                        DataScannerView(recognizedText: $text)
                    } else {
                        unavailableView
                    }
                    #else
                    unavailableView
                    #endif
                case .paste:
                    TextEditor(text: $text)
                        .padding()
                }
            }
            .navigationTitle("Add Material")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let sourceType: SourceType = mode == .camera ? .camera : .paste
                        let material = StudyMaterial(rawText: text, sourceType: sourceType)
                        PersistenceService.save(material, context: modelContext)
                        onSave?(material)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Camera Not Available", isPresented: $showUnsupportedAlert) {
                Button("OK") { mode = .paste }
            } message: {
                Text("Text scanning is not supported on this device.")
            }
            .onChange(of: mode) { _, newValue in
                #if os(iOS)
                if newValue == .camera && !DataScannerViewController.isSupported {
                    showUnsupportedAlert = true
                }
                #else
                if newValue == .camera {
                    showUnsupportedAlert = true
                }
                #endif
            }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView(
            "Scanner Not Available",
            systemImage: "camera.fill",
            description: Text("Text scanning is not supported on this device. Use paste mode instead.")
        )
    }
}

#if os(iOS)
struct DataScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(recognizedText: $recognizedText)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        @Binding var recognizedText: String

        init(recognizedText: Binding<String>) {
            _recognizedText = recognizedText
        }

        nonisolated func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                let transcript = text.transcript
                Task { @MainActor in
                    if self.recognizedText.isEmpty {
                        self.recognizedText = transcript
                    } else {
                        self.recognizedText += "\n" + transcript
                    }
                }
            default:
                break
            }
        }
    }
}
#endif
