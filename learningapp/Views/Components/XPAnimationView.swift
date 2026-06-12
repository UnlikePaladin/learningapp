import SwiftUI

struct XPAnimationView: View {
    let xpAmount: Int
    @Binding var isShowing: Bool

    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        if isShowing {
            Text("+\(xpAmount) XP")
                .font(.headline.bold())
                .foregroundStyle(.purple)
                .offset(y: offset)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2)) {
                        offset = -60
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        isShowing = false
                        offset = 0
                        opacity = 1
                    }
                }
        }
    }
}
