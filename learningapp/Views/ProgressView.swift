import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Query(sort: \SessionResult.date, order: .reverse) private var sessions: [SessionResult]

    private var totalQuestions: Int { sessions.reduce(0) { $0 + $1.questionsAnswered } }
    private var totalCorrect: Int { sessions.reduce(0) { $0 + $1.correctCount } }
    private var accuracy: Double { totalQuestions > 0 ? Double(totalCorrect) / Double(totalQuestions) * 100 : 0 }
    private var xp: Int { totalCorrect * 10 + (totalQuestions - totalCorrect) * 5 }

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

    private var last7Days: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let count = sessions.filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.questionsAnswered }
            return (day, count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak & XP header
                    HStack(spacing: 20) {
                        statCard(icon: "flame.fill", color: .orange, value: "\(streak)", label: "Day Streak")
                        statCard(icon: "star.fill", color: .purple, value: "\(xp)", label: "XP Earned")
                    }

                    // Accuracy & Questions
                    HStack(spacing: 20) {
                        statCard(icon: "checkmark.circle.fill", color: .green, value: String(format: "%.0f%%", accuracy), label: "Accuracy")
                        statCard(icon: "questionmark.circle.fill", color: .blue, value: "\(totalQuestions)", label: "Questions")
                    }

                    // 7-day chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Last 7 Days")
                            .font(.headline)

                        Chart(last7Days, id: \.date) { item in
                            BarMark(
                                x: .value("Day", item.date, unit: .day),
                                y: .value("Questions", item.count)
                            )
                            .foregroundStyle(.blue.gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .frame(height: 160)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                    if sessions.isEmpty {
                        ContentUnavailableView("No sessions yet", systemImage: "chart.bar", description: Text("Complete a study session to see your progress here."))
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ProgressDashboardView()
        .modelContainer(for: SessionResult.self, inMemory: true)
}
