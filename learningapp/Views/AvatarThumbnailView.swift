import SwiftUI

/// Renders the user's avatar inside a circular frame. Prefers the custom cropped image
/// (`customAvatarData`) when present; falls back to the named giraffe asset.
struct AvatarThumbnailView: View {
    let avatarID: String
    let backgroundID: String
    let customData: Data?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AvatarBackground.color(for: backgroundID))
            if let data = customData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(avatarID)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.05)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
