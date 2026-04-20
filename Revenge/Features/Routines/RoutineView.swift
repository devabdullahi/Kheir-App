import SwiftUI

// MARK: - RoutineView

/// Full-screen checklist view for a morning or evening spiritual routine.
struct RoutineView: View {
    let routineType: RoutineType

    @StateObject private var viewModel = RoutineViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Progress bar
                        progressHeader
                            .scrollReveal(delay: 0)

                        // Step list
                        if let routine = viewModel.currentRoutine {
                            ForEach(Array(routine.steps.enumerated()), id: \.element.id) { index, step in
                                RoutineStepRow(
                                    step: step,
                                    isCompleted: routine.completedSteps.contains(step.id),
                                    colorScheme: colorScheme
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.markStepComplete(index: index)
                                    }
                                }
                                .scrollReveal(delay: Double(index) * 0.06)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }

                // Celebration overlay
                if viewModel.showCelebration {
                    celebrationOverlay
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(1)
                }
            }
            .navigationTitle(routineType.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.resetRoutine()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .accessibilityLabel("Reset routine")
                    .accessibilityIdentifier("resetRoutineButton")
                }
            }
            .onAppear {
                viewModel.loadRoutine(type: routineType)
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text(routineType.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

                Spacer()

                Text("\(Int(viewModel.completionPercentage * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.adaptiveCardSurface(colorScheme))
                        .frame(height: 8)

                    Capsule()
                        .fill(Color.adaptivePrimary(colorScheme))
                        .frame(width: geo.size.width * viewModel.completionPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.completionPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(Color.adaptiveCardSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Routine progress: \(Int(viewModel.completionPercentage * 100)) percent complete")
        .accessibilityIdentifier("routineProgressBar")
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { viewModel.dismissCelebration() }

            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))

                VStack(spacing: 8) {
                    Text("Alhamdulillah!")
                        .font(.title.bold())
                        .foregroundStyle(.white)

                    Text("You have completed your \(routineType.rawValue) routine.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal)
                }

                Button {
                    viewModel.dismissCelebration()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveCardSurface(colorScheme))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.adaptivePrimary(colorScheme))
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("celebrationDismissButton")
            }
            .padding(32)
            .background(Color.adaptiveCardSurface(colorScheme).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - RoutineStepRow

/// A single checklist row showing the step's Arabic text (if any), English content, and reference.
struct RoutineStepRow: View {
    let step: RoutineStep
    let isCompleted: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                // Checkbox
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        isCompleted
                            ? Color.adaptivePrimary(colorScheme)
                            : Color.adaptiveSecondaryText(colorScheme)
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    // Step label badge
                    HStack(spacing: 6) {
                        Image(systemName: stepIcon)
                            .font(.caption2)
                        Text(step.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))

                    // Arabic text
                    if let arabic = step.arabicText, !arabic.isEmpty {
                        Text(arabic)
                            .arabicFont(size: 20)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(
                                isCompleted
                                    ? Color.adaptiveText(colorScheme).opacity(0.5)
                                    : Color.adaptiveText(colorScheme)
                            )
                    }

                    // English content
                    Text(step.content)
                        .font(.body)
                        .foregroundStyle(
                            isCompleted
                                ? Color.adaptiveText(colorScheme).opacity(0.5)
                                : Color.adaptiveText(colorScheme)
                        )
                        .fixedSize(horizontal: false, vertical: true)

                    // Reference
                    Text(step.reference)
                        .font(.caption2)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }
            .padding(16)
            .background(Color.adaptiveCardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isCompleted ? Color.adaptivePrimary(colorScheme).opacity(0.4) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(step.title): \(step.content). \(isCompleted ? "Completed" : "Not completed")")
        .accessibilityAddTraits(isCompleted ? [.isSelected] : [])
    }

    private var stepIcon: String {
        switch step.type {
        case .dua:        return "hands.sparkles"
        case .ayah:       return "book"
        case .hadith:     return "text.quote"
        case .dhikr:      return "circle.grid.3x3"
        case .reflection: return "pencil.and.list.clipboard"
        }
    }
}
