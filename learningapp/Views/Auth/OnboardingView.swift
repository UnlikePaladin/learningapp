import SwiftUI
import SwiftData
import FirebaseAuth
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var selectedAvatar: GiraffeAvatar = .happy
    @State private var selectedBackground: AvatarBackground = .mint
    @State private var nickname = ""
    @State private var selectedInterests: Set<String> = []
    @State private var customTag = ""
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)
    private let firestoreService = FirestoreService()

    private let totalSteps = 3

    var body: some View {
        ZStack {
            cream.ignoresSafeArea()

            VStack(spacing: 0) {
                topIllustration
                bottomSheet
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Top illustration area

    private var topIllustration: some View {
        ZStack {
            cream

            VStack(spacing: 16) {
                progressDots
                    .padding(.top, 16)

                switch step {
                case 0:
                    AvatarPreview(avatar: selectedAvatar, background: selectedBackground)
                        .frame(width: 130, height: 130)
                        .transition(.scale.combined(with: .opacity))
                case 1:
                    Image("clear_happy_giraffe")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .transition(.scale.combined(with: .opacity))
                default:
                    Image("question_giraffe")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 220)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Color("Darkgreen") : Color("Darkgreen").opacity(0.25))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(duration: 0.35), value: step)
            }
        }
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(stepSubtitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(stepTitle)
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)

            stepContent
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Spacer(minLength: 20)

            if let err = saveError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
            }

            OnboardingPrimaryButton(
                label: step < totalSteps - 1 ? "Siguiente" : "¡Empezar a aprender!",
                isLoading: isSaving,
                disabled: !canAdvance
            ) {
                if step < totalSteps - 1 {
                    withAnimation { step += 1 }
                } else {
                    Task { await finishOnboarding() }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 36,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 36,
                style: .continuous
            )
            .fill(Color("Darkgreen"))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: "Elige tu avatar"
        case 1: "¿Cómo te llamamos?"
        default: "¿Qué te interesa?"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: "Tu personaje"
        case 1: "Tu nombre"
        default: "Tus temas"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: avatarStep
        case 1: nicknameStep
        default: interestsStep
        }
    }

    // MARK: Step 0 – Avatar

    private var avatarStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(GiraffeAvatar.allCases) { avatar in
                    Button {
                        selectedAvatar = avatar
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selectedBackground.color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(selectedAvatar == avatar ? .white : .clear, lineWidth: 2.5)
                                )
                            VStack(spacing: 4) {
                                Image(avatar.rawValue)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(8)
                                Text(avatar.displayName)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Color("Darkgreen"))
                                    .padding(.bottom, 6)
                            }
                        }
                        .frame(height: 90)
                    }
                    .scaleEffect(selectedAvatar == avatar ? 1.05 : 1)
                    .animation(.spring(duration: 0.25), value: selectedAvatar)
                }
            }

            Text("Color de fondo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AvatarBackground.allCases) { bg in
                        Button {
                            selectedBackground = bg
                        } label: {
                            Circle()
                                .fill(bg.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().strokeBorder(selectedBackground == bg ? .white : .clear, lineWidth: 2.5)
                                )
                                .scaleEffect(selectedBackground == bg ? 1.15 : 1)
                                .animation(.spring(duration: 0.2), value: selectedBackground)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: Step 1 – Nickname

    private var nicknameStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Tu nombre aquí", text: $nickname)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(cream, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.black)
                .autocorrectionDisabled()
                #if os(iOS)
                .autocapitalization(.words)
                #endif

            Text("Este nombre aparecerá en tu perfil y en tus logros.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: Step 2 – Interests

    private var interestsStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(InterestCatalog.groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .textCase(.uppercase)
                            .tracking(0.5)

                        OnboardingTagFlow(tags: group.tags, selected: $selectedInterests)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Personalizado")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        TextField("Agregar tema…", text: $customTag)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(cream.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .autocapitalization(.words)
                            #endif

                        Button {
                            let tag = customTag.trimmingCharacters(in: .whitespaces)
                            guard !tag.isEmpty else { return }
                            selectedInterests.insert(tag)
                            customTag = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(cream)
                        }
                    }

                    if !selectedInterests.filter({ tag in
                        !InterestCatalog.groups.flatMap(\.tags).contains(tag)
                    }).isEmpty {
                        OnboardingTagFlow(
                            tags: selectedInterests.filter { tag in
                                !InterestCatalog.groups.flatMap(\.tags).contains(tag)
                            }.sorted(),
                            selected: $selectedInterests
                        )
                    }
                }
            }
            .padding(.bottom, 16)
        }
        .frame(maxHeight: 280)
    }

    // MARK: - Finish

    private func finishOnboarding() async {
        guard let uid = auth.currentUser?.uid else {
            saveError = "Error: no hay sesión activa."
            return
        }
        isSaving = true
        saveError = nil

        let blob = renderAvatarBlob(avatar: selectedAvatar, background: selectedBackground)
        let interestList = Array(selectedInterests).sorted()
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespaces)

        do {
            try await firestoreService.createProfile(
                uid: uid,
                nickname: trimmedNickname,
                avatarID: selectedAvatar.rawValue,
                avatarBackground: selectedBackground.rawValue,
                avatarBlob: blob,
                interests: interestList
            )

            let profile = UserProfile(
                nickname: trimmedNickname,
                avatarID: selectedAvatar.rawValue,
                avatarBackground: selectedBackground.rawValue,
                interests: interestList,
                avatarBlob: blob
            )
            context.insert(profile)
            try context.save()

            try await firestoreService.syncLocalData(uid: uid, context: context)

            auth.completeOnboarding()
        } catch {
            print("❌ Onboarding save error: \(error)")
            saveError = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Avatar blob rendering

    private func renderAvatarBlob(avatar: GiraffeAvatar, background: AvatarBackground) -> Data? {
        #if os(iOS)
        guard let giraffeImage = UIImage(named: avatar.rawValue) else { return nil }
        let size = CGSize(width: 300, height: 300)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor(background.color).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let aspect = giraffeImage.size.height / giraffeImage.size.width
            let drawH = size.height * 0.88
            let drawW = drawH / aspect
            let rect = CGRect(
                x: (size.width - drawW) / 2,
                y: (size.height - drawH) / 2,
                width: drawW, height: drawH
            )
            giraffeImage.draw(in: rect)
        }
        return image.pngData()
        #else
        return nil
        #endif
    }
}

// MARK: - Avatar preview circle

private struct AvatarPreview: View {
    let avatar: GiraffeAvatar
    let background: AvatarBackground

    var body: some View {
        ZStack {
            Circle().fill(background.color)
            Image(avatar.rawValue)
                .resizable()
                .scaledToFit()
                .padding(12)
        }
    }
}

// MARK: - Tag flow for interests

private struct OnboardingTagFlow: View {
    let tags: [String]
    @Binding var selected: Set<String>

    var body: some View {
        OnboardingFlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(tag)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            selected.contains(tag)
                                ? Color(red: 1, green: 0.961, blue: 0.914)
                                : Color(red: 1, green: 0.961, blue: 0.914).opacity(0.15),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selected.contains(tag)
                                ? Color("Darkgreen")
                                : Color(red: 1, green: 0.961, blue: 0.914)
                        )
                }
                .animation(.spring(duration: 0.2), value: selected)
            }
        }
    }
}

// MARK: - Flow layout

private struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                y += rowH + spacing
                x = 0
                rowH = 0
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowH + spacing
                x = bounds.minX
                rowH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: - Primary button

private struct OnboardingPrimaryButton: View {
    let label: String
    let isLoading: Bool
    let disabled: Bool
    let action: () -> Void

    private let cream = Color(red: 1, green: 0.961, blue: 0.914)

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().tint(Color("Darkgreen"))
                } else {
                    Text(label).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(Color("Darkgreen"))
            .background(
                cream.opacity(disabled ? 0.4 : 1),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .disabled(disabled || isLoading)
    }
}

#Preview {
    OnboardingView()
        .environment(AuthService())
}
