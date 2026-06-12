import SwiftUI

struct AppendContentView: View {
    let material: StudyMaterial
    let onAppend: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Adding to: \(material.title.isEmpty ? "Untitled" : material.title)")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $newText)
                    .border(Color.secondary.opacity(0.3))
                    .frame(minHeight: 200)
            }
            .padding()
            .navigationTitle("Add Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        onAppend(newText)
                        dismiss()
                    }
                    .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
