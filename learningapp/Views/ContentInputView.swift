import SwiftUI
import SwiftData
import VisionKit
import UniformTypeIdentifiers

enum InputMode: String, CaseIterable {
    case camera = "Camera"
    case paste = "Paste"
    case pdf = "PDF"
}

struct ContentInputView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((StudyMaterial) -> Void)?

    @State private var mode: InputMode = .paste
    @State private var text = ""
    @State private var showUnsupportedAlert = false
    @State private var showingFileImporter = false
    @State private var pdfFileName: String?
    @State private var pdfErrorMessage: String?

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
                case .pdf:
                    pdfPickerView
                }
            }
            .navigationTitle("Add Material")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let sourceType: SourceType
                        switch mode {
                        case .camera: sourceType = .camera
                        case .pdf: sourceType = .pdf
                        case .paste: sourceType = .paste
                        }
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
            .alert("PDF Error", isPresented: .init(get: { pdfErrorMessage != nil }, set: { if !$0 { pdfErrorMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(pdfErrorMessage ?? "")
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url):
                    if let extracted = PDFExtractor.extractText(from: url) {
                        text = extracted
                        pdfFileName = url.lastPathComponent
                    } else {
                        pdfErrorMessage = "Could not extract text from this PDF. It may be image-only or password-protected."
                    }
                case .failure(let error):
                    pdfErrorMessage = error.localizedDescription
                }
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

    private var pdfPickerView: some View {
        VStack(spacing: 16) {
            if text.isEmpty {
                ContentUnavailableView(
                    "Import a PDF",
                    systemImage: "doc.fill",
                    description: Text("Pick a PDF file to extract text and create a lesson.")
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(pdfFileName ?? "PDF Loaded", systemImage: "doc.fill")
                            .font(.headline)
                        Spacer()
                        Text("\(text.count) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Text("Review the extracted text below. Edit out anything irrelevant (branding, captions, etc.) before saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    TextEditor(text: $text)
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .background(.regularMaterial)
                }
            }

            Button {
                showingFileImporter = true
            } label: {
                Label(text.isEmpty ? "Choose PDF" : "Choose Different PDF", systemImage: "folder")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding(.top)
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
