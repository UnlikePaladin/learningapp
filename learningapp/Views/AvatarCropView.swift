import SwiftUI
import UIKit

/// Lets the user pan and pinch a giraffe asset inside a square canvas with a circular
/// crop overlay. On save, renders the canvas to a PNG and returns the bytes via `onSave`.
/// The image is intentionally rendered at a square size (not pre-cropped to a circle) so
/// downstream consumers (Firebase, etc.) get a full-resolution square they can mask.
struct AvatarCropView: View {
    let sourceAvatarID: String
    let backgroundID: String
    /// Optional starting image (e.g., a previously saved crop) used for re-editing.
    let initialImage: UIImage?
    let onCancel: () -> Void
    let onSave: (Data) -> Void

    /// Side length of the rendered output PNG (and the editor's canvas).
    private let renderSize: CGFloat = 320

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color("Darkgreen"))
                Spacer()
                Text("Frame Avatar")
                    .font(.headline)
                Spacer()
                Button("Save") { saveCrop() }
                    .font(.headline.bold())
                    .foregroundStyle(Color("Darkgreen"))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()

            // Crop canvas
            cropCanvas
                .gesture(combinedGesture)

            Text("Pinch to zoom · drag to reposition · double-tap to reset")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { resetTransform() }
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(Color("Darkgreen"))
                        .background(Color("Lightgreen").opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button { saveCrop() } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)

            Spacer()
        }
        .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
        .onAppear { resetTransform() }
    }

    // MARK: - Canvas

    private var cropCanvas: some View {
        ZStack {
            // Background fill
            Rectangle()
                .fill(AvatarBackground.color(for: backgroundID))

            // The image being cropped — pan + scale go here
            sourceImage
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { resetTransform() }
                }

            // Circle crop overlay (visual guide only — the saved file is the full square)
            Circle()
                .stroke(Color.white.opacity(0.95), lineWidth: 3)
                .background(
                    Rectangle()
                        .fill(.black.opacity(0.0))
                )
        }
        .frame(width: renderSize, height: renderSize)
        .clipped()
        .overlay(
            Rectangle().stroke(Color("Darkgreen").opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sourceImage: Image {
        if let initialImage { return Image(uiImage: initialImage) }
        return Image(sourceAvatarID)
    }

    // MARK: - Gestures

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(0.5, min(4.0, lastScale * value))
                }
                .onEnded { _ in lastScale = scale },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }

    private func resetTransform() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }

    // MARK: - Render

    private func saveCrop() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2  // 2x output for retina
        format.opaque = false
        let canvasSize = CGSize(width: renderSize, height: renderSize)
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        let baseImage: UIImage = initialImage ?? UIImage(named: sourceAvatarID) ?? UIImage()
        let bgColor = UIColor(AvatarBackground.color(for: backgroundID))

        let png = renderer.image { ctx in
            // Background fill
            bgColor.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))

            // Aspect-fit the image into the canvas first (matches scaledToFit behavior).
            let imageAspect = baseImage.size.width / max(baseImage.size.height, 1)
            var fitSize = canvasSize
            if imageAspect > 1 {
                fitSize = CGSize(width: canvasSize.width, height: canvasSize.width / imageAspect)
            } else if imageAspect < 1 {
                fitSize = CGSize(width: canvasSize.height * imageAspect, height: canvasSize.height)
            }

            // Apply scale + offset around the canvas center.
            let drawWidth = fitSize.width * scale
            let drawHeight = fitSize.height * scale
            let drawRect = CGRect(
                x: (canvasSize.width - drawWidth) / 2 + offset.width,
                y: (canvasSize.height - drawHeight) / 2 + offset.height,
                width: drawWidth,
                height: drawHeight
            )
            baseImage.draw(in: drawRect)
        }.pngData() ?? Data()

        onSave(png)
    }
}
