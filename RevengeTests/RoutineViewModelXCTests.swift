//
//  RoutineViewModelXCTests.swift
//  RevengeTests
//
//  XCTest coverage for RoutineViewModel edge cases.

import XCTest
@testable import Revenge

@MainActor
final class RoutineViewModelXCTests: XCTestCase {

    private func makeVM(
        routine: MockRoutineService = MockRoutineService()
    ) -> RoutineViewModel {
        RoutineViewModel(routineService: routine)
    }

    // MARK: - Load Routine

    func test_loadRoutine_morning_populatesCurrentRoutine() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        XCTAssertNotNil(vm.currentRoutine)
        XCTAssertEqual(vm.currentRoutine?.type, .morning)
    }

    func test_loadRoutine_evening_populatesCurrentRoutine() {
        let vm = makeVM()
        vm.loadRoutine(type: .evening)
        XCTAssertNotNil(vm.currentRoutine)
        XCTAssertEqual(vm.currentRoutine?.type, .evening)
    }

    func test_loadRoutine_generates6Steps() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        XCTAssertEqual(vm.currentRoutine?.steps.count, 6)
    }

    func test_loadRoutine_completionPercentageStartsAtZero() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        XCTAssertEqual(vm.completionPercentage, 0)
    }

    // MARK: - markStepComplete

    func test_markStepComplete_firstStep_setsCompletedSteps() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        let stepID = vm.currentRoutine!.steps[0].id

        vm.markStepComplete(index: 0)

        XCTAssertTrue(vm.currentRoutine?.completedSteps.contains(stepID) == true)
    }

    func test_markStepComplete_togglingOff_removesFromCompletedSteps() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 0)
        vm.markStepComplete(index: 0)

        XCTAssertTrue(vm.currentRoutine?.completedSteps.isEmpty == true)
    }

    func test_markStepComplete_updatesCompletionPercentage() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        XCTAssertEqual(vm.completionPercentage, 0)

        vm.markStepComplete(index: 0)
        XCTAssertGreaterThan(vm.completionPercentage, 0)
    }

    func test_markStepComplete_outOfBounds_doesNotCrash() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 100)
        vm.markStepComplete(index: -1)

        XCTAssertTrue(vm.currentRoutine?.completedSteps.isEmpty == true)
    }

    func test_markStepComplete_outOfBounds_whenNoRoutine_doesNotCrash() {
        let vm = makeVM()
        vm.markStepComplete(index: 0)
        XCTAssertNil(vm.currentRoutine)
    }

    func test_markAllSteps_completionPercentageIsOne() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        let count = vm.currentRoutine!.steps.count
        for i in 0..<count { vm.markStepComplete(index: i) }
        XCTAssertEqual(vm.completionPercentage, 1.0, accuracy: 0.001)
    }

    // MARK: - showCelebration

    func test_markAllSteps_showsCelebration() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        let count = vm.currentRoutine!.steps.count
        for i in 0..<count { vm.markStepComplete(index: i) }
        XCTAssertTrue(vm.showCelebration)
    }

    func test_dismissCelebration_clearsFlagWithoutResettingProgress() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        let count = vm.currentRoutine!.steps.count
        for i in 0..<count { vm.markStepComplete(index: i) }
        XCTAssertTrue(vm.showCelebration)

        vm.dismissCelebration()

        XCTAssertFalse(vm.showCelebration)
        XCTAssertEqual(vm.completionPercentage, 1.0, accuracy: 0.001)
        XCTAssertFalse(vm.currentRoutine?.completedSteps.isEmpty ?? true)
    }

    func test_resetRoutine_clearsCelebrationFlag() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)
        let count = vm.currentRoutine!.steps.count
        for i in 0..<count { vm.markStepComplete(index: i) }
        XCTAssertTrue(vm.showCelebration)

        vm.resetRoutine()

        XCTAssertFalse(vm.showCelebration)
    }

    func test_resetRoutine_clearsCompletedSteps() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 0)
        vm.markStepComplete(index: 1)
        vm.resetRoutine()

        XCTAssertTrue(vm.currentRoutine?.completedSteps.isEmpty == true)
        XCTAssertEqual(vm.completionPercentage, 0)
    }

    func test_resetRoutine_noOp_whenNoCurrentRoutine() {
        let vm = makeVM()
        vm.resetRoutine()
        XCTAssertNil(vm.currentRoutine)
    }

    // MARK: - saveProgress call counts

    func test_saveProgressCalledOnce_perMarkStep() {
        let service = MockRoutineService()
        let vm = makeVM(routine: service)
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 0)
        XCTAssertEqual(service.saveProgressCallCount, 1)

        vm.markStepComplete(index: 1)
        XCTAssertEqual(service.saveProgressCallCount, 2)
    }

    func test_saveProgressCalled_whenTogglingOff() {
        let service = MockRoutineService()
        let vm = makeVM(routine: service)
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 0)
        vm.markStepComplete(index: 0)

        XCTAssertEqual(service.saveProgressCallCount, 2)
    }

    func test_saveProgressCalled_onReset() {
        let service = MockRoutineService()
        let vm = makeVM(routine: service)
        vm.loadRoutine(type: .morning)
        vm.markStepComplete(index: 0)
        let countBeforeReset = service.saveProgressCallCount

        vm.resetRoutine()

        XCTAssertGreaterThan(service.saveProgressCallCount, countBeforeReset)
    }

    // MARK: - Fractional completion

    func test_threeOfSixSteps_completionIsHalf() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)

        for i in 0..<3 { vm.markStepComplete(index: i) }

        XCTAssertEqual(vm.completionPercentage, 0.5, accuracy: 0.001)
    }

    func test_oneOfSixSteps_completionIsOneSixth() {
        let vm = makeVM()
        vm.loadRoutine(type: .morning)

        vm.markStepComplete(index: 0)

        let expected = 1.0 / 6.0
        XCTAssertEqual(vm.completionPercentage, expected, accuracy: 0.001)
    }
}
