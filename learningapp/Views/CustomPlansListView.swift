import SwiftUI
import SwiftData

struct CustomPlansListView: View {
    @Query(sort: \CustomStudyPlan.dateCreated, order: .reverse) private var plans: [CustomStudyPlan]
    @Query private var lessons: [Lesson]
    @Environment(\.modelContext) private var modelContext

    @State private var showingCreate = false

    private let cardColors: [Color] = [
        Color("Darkgreen"), Color("Orange"), Color("Lightgreen"), Color("Red")
    ]

    var body: some View {
        NavigationStack {
            Group {
                if plans.isEmpty {
                    VStack(spacing: 24) {
                        ContentUnavailableView(
                            "No plans yet",
                            systemImage: "list.clipboard",
                            description: Text("Group lessons together and quiz across all of them.")
                        )
                        if !lessons.isEmpty {
                            Button {
                                showingCreate = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                    Text("Create First Plan")
                                        .font(.title3.bold())
                                }
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(.white)
                                .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                } else {
                    List {
                        ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                            NavigationLink {
                                PlanDetailView(plan: plan)
                            } label: {
                                planCard(plan, index: index)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        }
                        .onDelete(perform: deletePlans)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                GiraffeBannerView(
                    title: "Study Plans",
                    subtitle: "Organized learning",
                    giraffeImage: "normal_giraffe"
                )
            }
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Plan", systemImage: "plus") {
                        showingCreate = true
                    }
                    .disabled(lessons.isEmpty)
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView()
            }
        }
    }

    private func planCard(_ plan: CustomStudyPlan, index: Int) -> some View {
        let color = cardColors[index % cardColors.count]

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                    Text(plan.lessonIDs.count == 1 ? "1 lesson" : "\(plan.lessonIDs.count) lessons")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(color, in: RoundedRectangle(cornerRadius: 16))
    }

    private func deletePlans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(plans[index])
        }
        try? modelContext.save()
    }
}
