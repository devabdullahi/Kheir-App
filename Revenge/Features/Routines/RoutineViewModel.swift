import Foundation
import Combine
import SwiftUI

// MARK: - RoutineViewModel

/// Drives the RoutineView. Handles loading, step completion, and reset.
///
/// Design decisions:
///   - @MainActor ensures all published-property mutations happen on the main thread
///     without extra `DispatchQueue.main.async` boilerplate in the view layer.
///   - `routineService` is injected as the `RoutineProviding` protocol so tests can
///     supply `MockRoutineService` without touching the file system.
///   - The date key is computed once per `loadRoutine` call to stay consistent with
///     the rest of the app's "yyyy-MM-dd" keying convention.
@MainActor
final class RoutineViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var currentRoutine: DailyRoutine?
    @Published private(set) var completionPercentage: Double = 0
    @Published private(set) var showCelebration = false

    // MARK: - Private State

    private let routineService: any RoutineProviding

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private func todayKey() -> String {
        Self.dayKeyFormatter.string(from: Date())
    }

    // MARK: - Initialisation

    init(routineService: any RoutineProviding = RoutineService.shared) {
        self.routineService = routineService
    }

    // MARK: - Public API

    /// Loads (or generates) the routine for the given type and today's date.
    func loadRoutine(type: RoutineType) async {
        let date = todayKey()
        let routine = await routineService.generateRoutine(type: type, for: date)
        currentRoutine = routine
        updateCompletion(from: routine)
    }

    /// Marks the step at `index` as complete (or re-marks if already tapped).
    /// Saves progress immediately and checks for full completion.
    func markStepComplete(index: Int) {
        guard var routine = currentRoutine,
              index >= 0,
              index < routine.steps.count else { return }

        let stepID = routine.steps[index].id
        if routine.completedSteps.contains(stepID) {
            routine.completedSteps.remove(stepID)
        } else {
            routine.completedSteps.insert(stepID)
        }

        currentRoutine = routine
        updateCompletion(from: routine)
        Task { await routineService.saveRoutineProgress(routine) }

        if routine.isCompleted && !showCelebration {
            showCelebration = true
        }
    }

    /// Clears all completed steps for the current routine.
    /// Persists the zeroed-out progress so the next `generateRoutine` call restores
    /// the same step content with a clean completion state.
    func resetRoutine() {
        guard var routine = currentRoutine else { return }
        routine.completedSteps = []
        currentRoutine = routine
        updateCompletion(from: routine)
        showCelebration = false
        Task { await routineService.saveRoutineProgress(routine) }
    }

    /// Dismisses the celebration overlay without resetting progress.
    func dismissCelebration() {
        showCelebration = false
    }

    // MARK: - Helpers

    private func updateCompletion(from routine: DailyRoutine) {
        completionPercentage = routine.completionPercentage
    }
}
