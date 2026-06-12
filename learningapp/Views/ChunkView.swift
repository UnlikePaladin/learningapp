import SwiftUI

struct ChunkView: View {
    let chunk: Chunk
    var onQuizMe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chunk.summary)
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 8) {
                ForEach(chunk.keyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .padding(.top, 6)
                            .foregroundStyle(.blue)
                        Text(point)
                            .font(.body)
                    }
                }
            }

            Button {
                onQuizMe()
            } label: {
                Label("Quiz Me", systemImage: "brain.head.profile")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}
