import Foundation

// MARK: - RoutineType

/// Identifies which time-of-day spiritual routine is being referenced.
enum RoutineType: String, Codable, CaseIterable, Sendable {
    case morning
    case evening

    var displayName: String {
        switch self {
        case .morning: return "Morning Routine"
        case .evening: return "Evening Routine"
        }
    }

    var subtitle: String {
        switch self {
        case .morning: return "Start your day with remembrance"
        case .evening: return "Close your day with gratitude"
        }
    }

    var systemImage: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

// MARK: - RoutineStepType

/// Categorises the nature of a single step within a routine.
enum RoutineStepType: String, Codable, Sendable {
    case dua
    case ayah
    case hadith
    case dhikr
    case reflection
}

// MARK: - RoutineStep

/// A single item inside a `DailyRoutine`.
///
/// `arabicText` is optional — reflection prompts and hadith steps may omit it.
struct RoutineStep: Codable, Identifiable, Equatable, Sendable {

    let id: UUID
    let type: RoutineStepType
    let title: String
    let content: String
    let arabicText: String?
    let reference: String

    init(
        id: UUID = UUID(),
        type: RoutineStepType,
        title: String,
        content: String,
        arabicText: String? = nil,
        reference: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.arabicText = arabicText
        self.reference = reference
    }
}

// MARK: - DailyRoutine

/// A full morning or evening routine for a specific calendar day.
///
/// `completedSteps` stores the `id` of each `RoutineStep` the user has checked off.
/// `isCompleted` is a computed convenience that returns `true` when every step is done.
struct DailyRoutine: Codable, Identifiable, Sendable {

    let id: UUID
    let type: RoutineType
    let dateString: String          // "yyyy-MM-dd"
    let steps: [RoutineStep]
    var completedSteps: Set<UUID>

    // MARK: Computed

    var isCompleted: Bool {
        !steps.isEmpty && completedSteps.count >= steps.count
    }

    var completionPercentage: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedSteps.count) / Double(steps.count)
    }

    // MARK: Init

    init(
        id: UUID = UUID(),
        type: RoutineType,
        dateString: String,
        steps: [RoutineStep],
        completedSteps: Set<UUID> = []
    ) {
        self.id = id
        self.type = type
        self.dateString = dateString
        self.steps = steps
        self.completedSteps = completedSteps
    }
}
