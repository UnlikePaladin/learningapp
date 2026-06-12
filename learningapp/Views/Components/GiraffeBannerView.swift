import SwiftUI

struct GiraffeBannerView: View {
    let title: String
    let subtitle: String
    var giraffeImage: String = "clear_happy_giraffe"

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(subtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 24)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(giraffeImage)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
                .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 28,
                bottomTrailingRadius: 28,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(Color("Darkgreen"))
            .ignoresSafeArea(edges: .top)
        )
    }
}

#Preview {
    GiraffeBannerView(title: "Ready to Learn!", subtitle: "Let's keep going")
        .previewLayout(.sizeThatFits)
}
