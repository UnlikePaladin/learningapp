import SwiftUI

struct SplashView: View {
    @State private var giraffeOffset: CGFloat = 60
    @State private var giraffeOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 1, green: 0.961, blue: 0.914)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("happy_giraffe")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260)
                    .offset(y: giraffeOffset)
                    .opacity(giraffeOpacity)

                Text("Lerny")
                    .font(.custom("Georgia", size: 61))
                    .foregroundStyle(Color(red: 0.294, green: 0.490, blue: 0.286))
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.35)) {
                giraffeOffset = 0
                giraffeOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                titleOpacity = 1
            }
        }
    }
}

#Preview {
    SplashView()
}
