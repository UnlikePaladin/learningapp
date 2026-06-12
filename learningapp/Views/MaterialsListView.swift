import SwiftUI
import SwiftData

struct MaterialsListView: View {
    @Query(sort: \StudyMaterial.dateAdded, order: .reverse) private var materials: [StudyMaterial]
    @Query private var chunks: [StoredChunk]
    @Environment(\.modelContext) private var modelContext
    @State private var showingInput = false
    @State private var appendingTo: StudyMaterial?
    @State private var isIngesting = false
    @State private var coordinator = StudyCoordinator()

    var body: some View {
        NavigationStack {
            Group {
                if materials.isEmpty {
                    ContentUnavailableView("No materials yet", systemImage: "book.closed", description: Text("Add study material to get started."))
                } else {
                    List {
                        ForEach(materials) { material in
                            NavigationLink {
                                StudySessionView(material: material)
                            } label: {
                                materialRow(material)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Add Content", systemImage: "plus.circle") {
                                    appendingTo = material
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteMaterials)
                    }
                }
            }
            .navigationTitle("Study")
            .toolbar {
                Button("Add Material", systemImage: "plus") {
                    showingInput = true
                }
            }
            .sheet(isPresented: $showingInput) {
                ContentInputView(onSave: { material in
                    isIngesting = true
                    Task {
                        await coordinator.ingestMaterial(material, context: modelContext)
                        isIngesting = false
                    }
                })
            }
            .sheet(item: $appendingTo) { material in
                AppendContentView(material: material) { newText in
                    Task {
                        await coordinator.appendContent(newText, to: material, context: modelContext)
                    }
                }
            }
            .overlay {
                if isIngesting {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Processing material...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func materialRow(_ material: StudyMaterial) -> some View {
        let chunkCount = chunks.filter { $0.materialID == material.id }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text(material.title.isEmpty ? String(material.rawText.prefix(50)) : material.title)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label("\(chunkCount) chunks", systemImage: "square.stack.3d.up")
                Text(material.dateAdded, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func deleteMaterials(at offsets: IndexSet) {
        for index in offsets {
            let material = materials[index]
            // Delete associated chunks
            let materialChunks = chunks.filter { $0.materialID == material.id }
            for chunk in materialChunks { modelContext.delete(chunk) }
            modelContext.delete(material)
        }
    }
}
