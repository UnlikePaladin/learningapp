import SwiftUI

struct SplashView: View {
    @State private var giraffeOffset: CGFloat = 80
    @State private var giraffeOpacity: Double = 0
    @State private var giraffeScale: CGFloat = 0.85
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var taglineOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.961, blue: 0.914)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image("clear_happy_giraffe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220)
                    .offset(y: giraffeOffset)
                    .opacity(giraffeOpacity)
                    .scaleEffect(giraffeScale)

                VStack(spacing: 6) {
                    Text("Lerny")
                        .font(.custom("Georgia", size: 58))
                        .foregroundStyle(Color(red: 0.294, green: 0.490, blue: 0.286))
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                    Text("Your learning companion")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.294, green: 0.490, blue: 0.286).opacity(0.7))
                        .opacity(taglineOpacity)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.65, bounce: 0.4)) {
                giraffeOffset = 0
                giraffeOpacity = 1
                giraffeScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                titleOffset = 0
                titleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.55)) {
                taglineOpacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
