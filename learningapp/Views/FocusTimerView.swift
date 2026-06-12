import SwiftUI
#if os(iOS)
import UIKit
#endif

struct FocusTimerView: View {
    @State private var selectedMinutes = 25
    @State private var remainingSeconds = 25 * 60
    @State private var isRunning = false
    @State private var timer: Timer?

    private let durations = [5, 15, 25]

    private var progress: Double {
        let total = Double(selectedMinutes * 60)
        return 1 - Double(remainingSeconds) / total
    }

    private var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Duration picker
            Picker("Duration", selection: $selectedMinutes) {
                ForEach(durations, id: \.self) { d in
                    Text("\(d) min").tag(d)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isRunning)
            .onChange(of: selectedMinutes) { _, newValue in
                remainingSeconds = newValue * 60
            }

            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Text(timeString)
                    .font(.system(.title, design: .monospaced).bold())
            }
            .frame(width: 120, height: 120)

            // Controls
            HStack(spacing: 24) {
                Button(isRunning ? "Pause" : "Start") {
                    isRunning ? pause() : start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Reset", action: reset)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding()
    }

    private func start() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                pause()
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
            }
        }
    }

    private func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func reset() {
        pause()
        remainingSeconds = selectedMinutes * 60
    }
}

#Preview {
    FocusTimerView()
}
