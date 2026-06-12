import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var showingAvatarPicker = false
    @State private var showingNickname = false
    @State private var showingInterests = false
    @State private var nicknameText = ""

    private var profile: UserProfile {
        // Use the first existing profile, or seed a default one. We deliberately keep
        // a singleton-style profile rather than per-account.
        if let existing = profiles.first { return existing }
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner + avatar — kept above the ScrollView so the avatar's
                // downward overflow isn't covered by it.
                bannerHeader
                    .zIndex(1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        nicknameSection
                        Divider()
                        interestsSection
                        progressSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)  // space for avatar overflow
                    .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color("Darkgreen").opacity(0.05).ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAvatarPicker) {
                AvatarPickerSheet(
                    selectedAvatar: profile.avatarID,
                    selectedBackground: profile.avatarBackground,
                    onPickAvatar: { newID in
                        profile.avatarID = newID
                        try? modelContext.save()
                    },
                    onPickBackground: { newID in
                        profile.avatarBackground = newID
                        try? modelContext.save()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert("Edit Nickname", isPresented: $showingNickname) {
                TextField("Your nickname", text: $nicknameText)
                Button("Save") {
                    let trimmed = nicknameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    profile.nickname = trimmed
                    try? modelContext.save()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingInterests) {
                InterestsEditorSheet(selected: Set(profile.interests)) { newSelection in
                    profile.interests = Array(newSelection).sorted()
                    try? modelContext.save()
                    showingInterests = false
                }
            }
        }
    }

    // MARK: - Banner

    private var bannerHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color("Darkgreen"), Color("Lightgreen")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.18)],
                    startPoint: .top, endPoint: .bottom
                )
            )

            avatarCircle
                .offset(x: 20, y: 55)
        }
    }

    private var avatarCircle: some View {
        Button {
            showingAvatarPicker = true
        } label: {
            ZStack {
                Circle()
                    .fill(AvatarBackground.color(for: profile.avatarBackground))
                    .frame(width: 115, height: 115)
                    .shadow(radius: 4)
                Image(profile.avatarID)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 105, height: 105)
                    .clipShape(Circle())
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 115, height: 115)
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, Color("Darkgreen"))
                    .background(Circle().fill(.white).frame(width: 26, height: 26))
                    .offset(x: 38, y: 38)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Nickname

    private var nicknameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.nickname.isEmpty ? "Set a nickname" : profile.nickname)
                    .font(.title.bold())
                    .foregroundStyle(profile.nickname.isEmpty ? .secondary : .primary)
                Spacer()
                Button {
                    nicknameText = profile.nickname
                    showingNickname = true
                } label: {
                    Image(systemName: "pencil").font(.headline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("Darkgreen"))
            }
            Text(GiraffeAvatar(rawValue: profile.avatarID)?.displayName ?? "Giraffe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress (full dashboard inline)

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
            ProgressDashboardContent()
        }
    }

    // MARK: - Interests

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Interests")
                    .font(.headline)
                Spacer()
                Button {
                    showingInterests = true
                } label: {
                    Label("Edit", systemImage: "tag")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color("Darkgreen"))
            }

            if profile.interests.isEmpty {
                ContentUnavailableView(
                    "No interests yet",
                    systemImage: "tag",
                    description: Text("Tap Edit to pick subjects you want to study — like Math, Biology, or Spanish.")
                )
                .frame(minHeight: 180)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(profile.interests, id: \.self) { tag in
                        InterestChip(tag: tag)
                    }
                }
            }
        }
    }
}

// MARK: - Interest chip

private struct InterestChip: View {
    let tag: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text(tag)
                .font(.subheadline.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color("Lightgreen").opacity(0.25), in: Capsule())
        .overlay(Capsule().stroke(Color("Darkgreen").opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Avatar picker sheet

private struct AvatarPickerSheet: View {
    let selectedAvatar: String
    let selectedBackground: String
    let onPickAvatar: (String) -> Void
    let onPickBackground: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Live preview
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(AvatarBackground.color(for: selectedBackground))
                            .frame(width: 110, height: 110)
                            .shadow(radius: 3)
                        Image(selectedAvatar)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 110, height: 110)
                    }
                    Spacer()
                }
                .padding(.top, 20)

                // Giraffes
                Text("Giraffe")
                    .font(.headline)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 14
                ) {
                    ForEach(GiraffeAvatar.allCases) { avatar in
                        Button { onPickAvatar(avatar.rawValue) } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(AvatarBackground.color(for: selectedBackground))
                                    Image(avatar.rawValue)
                                        .resizable()
                                        .scaledToFit()
                                        .padding(8)
                                    Circle()
                                        .stroke(
                                            avatar.rawValue == selectedAvatar
                                                ? Color("Darkgreen")
                                                : Color.clear,
                                            lineWidth: 3
                                        )
                                }
                                .frame(width: 86, height: 86)
                                Text(avatar.displayName)
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Background colors
                Text("Background")
                    .font(.headline)
                    .padding(.top, 6)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 56))],
                    spacing: 12
                ) {
                    ForEach(AvatarBackground.allCases) { bg in
                        Button { onPickBackground(bg.rawValue) } label: {
                            ZStack {
                                Circle()
                                    .fill(bg.color)
                                    .frame(width: 50, height: 50)
                                Circle()
                                    .stroke(
                                        bg.rawValue == selectedBackground
                                            ? Color("Darkgreen")
                                            : Color.secondary.opacity(0.25),
                                        lineWidth: bg.rawValue == selectedBackground ? 3 : 1
                                    )
                                    .frame(width: 50, height: 50)
                                if bg.rawValue == selectedBackground {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(Color("Darkgreen"))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 12)

                Button { dismiss() } label: {
                    Text("Done")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(.white)
                        .background(Color("Darkgreen"), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - Interests editor sheet

private struct InterestsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var selected: Set<String>
    let onSave: (Set<String>) -> Void

    @State private var customText: String = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(InterestCatalog.groups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.tags, id: \.self) { tag in
                            tagRow(tag)
                        }
                    }
                }
                Section("Custom") {
                    HStack {
                        TextField("Add your own…", text: $customText)
                        Button("Add") {
                            let t = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            selected.insert(t)
                            customText = ""
                        }
                        .disabled(customText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if !selected.isEmpty {
                        let custom = selected
                            .subtracting(Set(InterestCatalog.groups.flatMap(\.tags)))
                            .sorted()
                        ForEach(custom, id: \.self) { tag in
                            tagRow(tag)
                        }
                    }
                }
            }
            .navigationTitle("Edit Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(selected) }
                }
            }
        }
    }

    private func tagRow(_ tag: String) -> some View {
        Button {
            if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
        } label: {
            HStack {
                Image(systemName: selected.contains(tag) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(tag) ? Color("Darkgreen") : Color.secondary)
                Text(tag)
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow layout for tag chips

/// Wraps tag chips onto multiple lines. Built-in equivalent isn't available pre-iOS 16
/// in some contexts; this is a small, readable replacement.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x)
        }
        return CGSize(width: totalWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
