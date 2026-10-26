import SwiftUI

// MARK: - RoutineView

/// A morning or evening routine as a checklist of paper cards, with a paper
/// progress ring that fills like a strip being laid around a disc.
struct RoutineView: View {
    let routineType: RoutineType

    @State private var viewModel = RoutineViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    progressHeader
                        .quickPlace(0)

                    if let routine = viewModel.currentRoutine {
                        ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                            RoutineStepRow(
                                step: step,
                                isCompleted: routine.completedSteps.contains(step.id),
                                colorScheme: colorScheme,
                                seed: 155 + index
                            ) {
                                withAnimation(reduceMotion ? nil : .open(0.22)) {
                                    viewModel.markStepComplete(index: index)
                                }
                            }
                            .quickPlace(index + 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

            if viewModel.showCelebration {
                celebrationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .paperBackground()
        .navigationTitle(routineType.displayName)
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.open(0.25)) { viewModel.resetRoutine() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }
                .accessibilityLabel("Reset routine")
                .accessibilityIdentifier("resetRoutineButton")
            }
        }
        .task {
            await viewModel.loadRoutine(type: routineType)
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        let total = viewModel.currentRoutine?.steps.count ?? 0
        let done = viewModel.currentRoutine?.completedSteps.count ?? 0
        let left = max(0, total - done)

        return HStack(spacing: 16) {
            PaperProgressRing(progress: viewModel.completionPercentage)
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(done) of \(total) complete")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .contentTransition(.numericText())
                Text(left == 0 && total > 0 ? "All done. Alhamdulillah." : "\(routineType.subtitle) · \(left) left")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            Spacer(minLength: 0)
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine progress: \(Int(viewModel.completionPercentage * 100)) percent complete")
        .accessibilityIdentifier("routineProgressBar")
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissCelebration() }

            VStack(spacing: 18) {
                PaperIconView(routineType == .morning ? .sunrise : .moon, size: 56)

                VStack(spacing: 6) {
                    Text("Alhamdulillah!")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text("You have completed your \(routineType.rawValue) routine.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }

                Button {
                    viewModel.dismissCelebration()
                } label: {
                    PaperButtonLabel(title: "Continue", seed: 171)
                }
                .buttonStyle(PaperPressStyle())
                .accessibilityIdentifier("celebrationDismissButton")
            }
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 2.6, seed: 170, padding: 28)
            .overlay(alignment: .top) { PaperTape(seed: 170).offset(y: -10) }
            .rotationEffect(.degrees(-1))
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Paper progress ring

/// A card disc with a strip of leaf-green paper laid around it.
struct PaperProgressRing: View {
    let progress: Double
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.adaptiveSecondaryText(scheme).opacity(0.14), lineWidth: 11)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(Color.adaptivePrimary(scheme), style: StrokeStyle(lineWidth: 11, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .shadow(color: .black.opacity(0.25), radius: 0.6, x: 0.5, y: 1)
                .shadow(color: .black.opacity(0.12), radius: 2, x: 1, y: 2)
                .animation(reduceMotion ? nil : .travel(0.5), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.adaptiveText(scheme))
                .contentTransition(.numericText())
        }
        .padding(6)
        .accessibilityHidden(true)
    }
}

// MARK: - RoutineStepRow

/// A single checklist card: a paper checkbox, the step's Arabic (if any),
/// English content, a count/kind tag and the reference.
struct RoutineStepRow: View {
    let step: RoutineStep
    let isCompleted: Bool
    let colorScheme: ColorScheme
    var seed: Int = 155
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                PaperCheckbox(isOn: isCompleted, size: 26, seed: seed)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        PaperIconView(stepIcon, size: 16)
                        Text(step.title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                            .strikethrough(isCompleted, color: Color.adaptiveSecondaryText(colorScheme))
                        Spacer(minLength: 4)
                        PaperTag(
                            text: step.type.rawValue,
                            color: isCompleted ? PaperInk.parkTissue : PaperInk.mustard,
                            ink: .lightBodyText,
                            seed: seed + 5
                        )
                    }

                    if let arabic = step.arabicText, !arabic.isEmpty {
                        Text(arabic)
                            .arabicFont(size: 20)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Color.adaptiveText(colorScheme))
                    }

                    Text(step.content)
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.reference)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
                .opacity(isCompleted ? 0.6 : 1)
            }
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: isCompleted ? 0.5 : 1, radius: 16, seed: seed, padding: 16)
            .paperTilt(seed, max: 0.6)
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel("\(step.title): \(step.content). \(isCompleted ? "Completed" : "Not completed")")
        .accessibilityAddTraits(isCompleted ? [.isSelected] : [])
    }

    private var stepIcon: PaperIcon {
        switch step.type {
        case .dua:        return .lantern
        case .ayah:       return .book
        case .hadith:     return .beads
        case .dhikr:      return .beads
        case .reflection: return .pen
        }
    }
}
