import SwiftUI
import SwiftData

struct StreakBadgeView: View {
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]

    private var streak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let first = uniqueDays.first, first >= today.addingTimeInterval(-86400) else { return 0 }
        var count = 1
        for i in 1..<uniqueDays.count {
            if calendar.dateComponents([.day], from: uniqueDays[i], to: uniqueDays[i-1]).day == 1 {
                count += 1
            } else { break }
        }
        return count
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak)")
                .font(.headline.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.15), in: Capsule())
    }
}
