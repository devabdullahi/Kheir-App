#!/usr/bin/env python3
"""
Example Simulation: Full dual-team workflow with rejection, bug, and resolution.

This demonstrates the complete multi-agent system with realistic interactions
including a ReviewerAgent rejecting code and QAAgent finding a bug.
"""

import json
import sys
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))
from schemas.messages import (
    Message, MessageType, AgentIdentity, TaskStatus, Priority,
    ReviewDecision, Severity,
    task_assignment_payload, progress_update_payload,
    code_submission_payload, review_feedback_payload,
    bug_report_payload, approval_payload,
)
from orchestrator import ContextManager, MessageStore, WorkflowGate

# Clean state for demo
MESSAGES_DIR = Path(__file__).parent / "messages"
MESSAGES_DIR.mkdir(exist_ok=True)


def print_message(msg: Message, step: str):
    """Pretty-print a message."""
    print(f"\n  ┌─ {step}")
    print(f"  │ Type: {msg.type.value}")
    print(f"  │ From: {msg.sender.agent} ({msg.sender.team})")
    print(f"  │ To:   {msg.receiver.agent} ({msg.receiver.team})")
    print(f"  │ Time: {msg.timestamp}")
    if msg.parent_id:
        print(f"  │ Re:   {msg.parent_id[:8]}...")

    # Type-specific display
    p = msg.payload
    if msg.type == MessageType.TASK_ASSIGNMENT:
        print(f"  │")
        print(f"  │ Task: {p['task_id']} — {p['title']}")
        print(f"  │ Priority: {p['priority']}")
        print(f"  │ Criteria:")
        for ac in p["acceptance_criteria"]:
            print(f"  │   • {ac}")
        print(f"  │ Files: {p['files_affected']}")
    elif msg.type == MessageType.CODE_SUBMISSION:
        print(f"  │")
        print(f"  │ Task: {p['task_id']}")
        print(f"  │ Changed:")
        for f in p["files_changed"]:
            print(f"  │   {f['path']} — {f['diff_summary']}")
        print(f"  │ Tests: {p['test_coverage']}")
        print(f"  │ Notes: {p['self_review_notes']}")
    elif msg.type == MessageType.REVIEW_FEEDBACK:
        print(f"  │")
        print(f"  │ Decision: {p['decision'].upper()}")
        print(f"  │ Scores: C={p['scores']['correctness']} R={p['scores']['readability']} "
              f"S={p['scores']['scalability']} Sec={p['scores']['security']} M={p['scores']['maintainability']}")
        print(f"  │ Average: {p['average']}")
        if p.get("comments"):
            print(f"  │ Comments:")
            for c in p["comments"]:
                print(f"  │   [{c['file']}:{c['line']}] {c['issue']}")
                print(f"  │   → {c['suggestion']}")
        if p.get("blocking_issues"):
            print(f"  │ Blocking:")
            for bi in p["blocking_issues"]:
                print(f"  │   ✗ {bi}")
    elif msg.type == MessageType.BUG_REPORT:
        print(f"  │")
        print(f"  │ Severity: {p['severity'].upper()}")
        print(f"  │ Bug: {p['description']}")
        print(f"  │ Steps:")
        for s in p["steps_to_reproduce"]:
            print(f"  │   {s}")
        print(f"  │ Expected: {p['expected']}")
        print(f"  │ Actual:   {p['actual']}")
    elif msg.type == MessageType.APPROVAL:
        print(f"  │")
        print(f"  │ Stage: {p['stage']}")
        print(f"  │ Reason: {p['reason']}")

    print(f"  └{'─' * 50}")


def run_simulation():
    print("""
╔══════════════════════════════════════════════════════════════════════╗
║          MULTI-AGENT TEAM SIMULATION — FULL WORKFLOW DEMO           ║
╠══════════════════════════════════════════════════════════════════════╣
║  Feature: Daily Streak Counter                                      ║
║  High Team: Core streak logic + persistence                         ║
║  Medium Team: Streak UI card on HomeView                            ║
╚══════════════════════════════════════════════════════════════════════╝
""")

    # ============================================================
    # HIGH PRIORITY TEAM — Core streak logic
    # ============================================================
    print("\n" + "═" * 60)
    print("  HIGH PRIORITY TEAM — Core Streak Logic")
    print("═" * 60)

    # Step 1: TechLead assigns
    msg1 = Message(
        type=MessageType.TASK_ASSIGNMENT,
        sender=AgentIdentity("TechLeadAgent", "high"),
        receiver=AgentIdentity("DeveloperAgent-1", "high"),
        payload=task_assignment_payload(
            task_id="TASK-048",
            title="Implement StreakService with persistence",
            description="Create a StreakService that tracks consecutive days of app usage. "
                        "Must persist across app launches and handle timezone changes.",
            acceptance_criteria=[
                "Streak increments on first app open each day",
                "Streak resets if a day is missed",
                "Persists via CacheManager",
                "Handles timezone changes gracefully",
                "Unit tests cover all edge cases",
            ],
            files_affected=[
                "Services/StreakService.swift",
                "Models/StreakData.swift",
            ],
            priority=Priority.HIGH,
            deadline="2026-04-21T17:00:00Z",
        ),
    )
    MessageStore.save(msg1)
    ContextManager.lock_files("high", "TASK-048", ["Services/StreakService.swift", "Models/StreakData.swift"])
    ContextManager.add_current_work("high", "TASK-048", "DeveloperAgent-1")
    print_message(msg1, "Step 1: TechLead assigns task")

    # Step 2: Developer submits (first attempt — has issues)
    msg2 = Message(
        type=MessageType.CODE_SUBMISSION,
        sender=AgentIdentity("DeveloperAgent-1", "high"),
        receiver=AgentIdentity("ReviewerAgent", "high"),
        parent_id=msg1.id,
        payload=code_submission_payload(
            task_id="TASK-048",
            files_changed=[
                {"path": "Services/StreakService.swift", "diff_summary": "Added StreakService with check/increment/reset logic"},
                {"path": "Models/StreakData.swift", "diff_summary": "Added StreakData model with currentStreak, lastOpenDate"},
            ],
            test_coverage="Unit tests for increment and reset",
            self_review_notes="Used UserDefaults for persistence. Timezone handled via Calendar.current.",
        ),
    )
    MessageStore.save(msg2)
    print_message(msg2, "Step 2: Developer submits code")

    # Step 3: Reviewer REJECTS (maintainability issue)
    msg3 = Message(
        type=MessageType.REVIEW_FEEDBACK,
        sender=AgentIdentity("ReviewerAgent", "high"),
        receiver=AgentIdentity("DeveloperAgent-1", "high"),
        parent_id=msg2.id,
        payload=review_feedback_payload(
            task_id="TASK-048",
            decision=ReviewDecision.REQUEST_CHANGES,
            scores={
                "correctness": 4,
                "readability": 4,
                "scalability": 3,
                "security": 3,
                "maintainability": 2,
            },
            comments=[
                {
                    "file": "Services/StreakService.swift",
                    "line": 12,
                    "issue": "Direct UserDefaults access creates tight coupling and makes testing impossible without mocking UserDefaults",
                    "suggestion": "Inject a StorageProtocol dependency. In production use CacheManager, in tests use MockStorage.",
                },
                {
                    "file": "Services/StreakService.swift",
                    "line": 34,
                    "issue": "Calendar.current is called inline — timezone logic is untestable",
                    "suggestion": "Inject a DateProvider protocol that wraps Calendar. Tests can provide fixed dates.",
                },
            ],
            blocking_issues=[
                "Maintainability at 2: tight coupling to UserDefaults and Calendar makes testing fragile and changes risky",
            ],
        ),
    )
    MessageStore.save(msg3)
    ContextManager.add_reviewer_pattern("high", "Direct UserDefaults access creates tight coupling")
    print_message(msg3, "Step 3: Reviewer REJECTS — maintainability issues")

    # Validate the rejection
    valid, reason = WorkflowGate.validate_review_feedback(msg3.payload)
    print(f"\n  Gate validation: {'✓' if valid else '✗'} {reason}")

    # Step 4: Developer fixes and resubmits
    msg4 = Message(
        type=MessageType.CODE_SUBMISSION,
        sender=AgentIdentity("DeveloperAgent-1", "high"),
        receiver=AgentIdentity("ReviewerAgent", "high"),
        parent_id=msg3.id,
        payload=code_submission_payload(
            task_id="TASK-048",
            files_changed=[
                {"path": "Services/StreakService.swift", "diff_summary": "Injected StorageProtocol + DateProvider, removed direct UserDefaults"},
                {"path": "Protocols/StorageProtocol.swift", "diff_summary": "New protocol for testable persistence"},
                {"path": "Protocols/DateProvider.swift", "diff_summary": "New protocol wrapping Calendar for testable dates"},
                {"path": "Tests/StreakServiceTests.swift", "diff_summary": "Tests using MockStorage and FixedDateProvider"},
            ],
            test_coverage="Full test suite: increment, reset, timezone change, first-ever-open, midnight edge case",
            self_review_notes="Addressed all blocking issues. Protocol injection enables full testability. "
                             "Verified previous reviewer patterns (no sync cache access on main thread).",
        ),
    )
    MessageStore.save(msg4)
    print_message(msg4, "Step 4: Developer fixes and resubmits")

    # Step 5: Reviewer APPROVES
    msg5 = Message(
        type=MessageType.REVIEW_FEEDBACK,
        sender=AgentIdentity("ReviewerAgent", "high"),
        receiver=AgentIdentity("DeveloperAgent-1", "high"),
        parent_id=msg4.id,
        payload=review_feedback_payload(
            task_id="TASK-048",
            decision=ReviewDecision.APPROVE,
            scores={
                "correctness": 5,
                "readability": 4,
                "scalability": 4,
                "security": 4,
                "maintainability": 5,
            },
            comments=[],
            blocking_issues=[],
        ),
    )
    MessageStore.save(msg5)
    print_message(msg5, "Step 5: Reviewer APPROVES")

    # Gate check
    can_qa, gate_msg = WorkflowGate.can_submit_to_qa("TASK-048")
    print(f"\n  QA Gate: {'✓' if can_qa else '✗'} {gate_msg}")

    # Step 6: QA finds a bug
    msg6 = Message(
        type=MessageType.BUG_REPORT,
        sender=AgentIdentity("QAAgent", "high"),
        receiver=AgentIdentity("DeveloperAgent-1", "high"),
        parent_id=msg5.id,
        payload=bug_report_payload(
            task_id="TASK-048",
            severity=Severity.MAJOR,
            description="Streak does not reset when user skips exactly one day and opens at 11:59 PM",
            steps_to_reproduce=[
                "1. Open app on Day 1 (streak = 1)",
                "2. Skip Day 2 entirely",
                "3. Open app on Day 3 at 23:59 local time",
                "4. Observe streak value",
            ],
            expected="Streak resets to 1 (day was missed)",
            actual="Streak shows 2 (incorrectly continues)",
            evidence="DateProvider test with fixedDate = Day3 23:59 fails assertion",
        ),
    )
    MessageStore.save(msg6)
    ContextManager.add_error("high", "TASK-048", "Edge case: midnight boundary streak reset logic incorrect")
    print_message(msg6, "Step 6: QA finds edge-case bug")

    # Step 7: Developer fixes the bug
    msg7 = Message(
        type=MessageType.CODE_SUBMISSION,
        sender=AgentIdentity("DeveloperAgent-1", "high"),
        receiver=AgentIdentity("ReviewerAgent", "high"),
        parent_id=msg6.id,
        payload=code_submission_payload(
            task_id="TASK-048",
            files_changed=[
                {"path": "Services/StreakService.swift", "diff_summary": "Fixed day comparison to use calendar.dateComponents([.day], from:to:) instead of timeIntervalSince"},
                {"path": "Tests/StreakServiceTests.swift", "diff_summary": "Added test for skip-one-day-open-at-midnight edge case"},
            ],
            test_coverage="Added 3 new edge case tests for midnight boundary conditions",
            self_review_notes="Root cause: was using timeIntervalSince (seconds) to determine days elapsed. "
                             "Now using Calendar.dateComponents for proper day-boundary math.",
        ),
    )
    MessageStore.save(msg7)
    print_message(msg7, "Step 7: Developer fixes bug")

    # Step 8: Reviewer re-approves
    msg8 = Message(
        type=MessageType.REVIEW_FEEDBACK,
        sender=AgentIdentity("ReviewerAgent", "high"),
        receiver=AgentIdentity("DeveloperAgent-1", "high"),
        parent_id=msg7.id,
        payload=review_feedback_payload(
            task_id="TASK-048",
            decision=ReviewDecision.APPROVE,
            scores={
                "correctness": 5,
                "readability": 5,
                "scalability": 4,
                "security": 4,
                "maintainability": 5,
            },
        ),
    )
    MessageStore.save(msg8)
    print_message(msg8, "Step 8: Reviewer re-approves fix")

    # Step 9: QA passes
    msg9 = Message(
        type=MessageType.APPROVAL,
        sender=AgentIdentity("QAAgent", "high"),
        receiver=AgentIdentity("TechLeadAgent", "high"),
        parent_id=msg8.id,
        payload=approval_payload("TASK-048", "qa", "All 5 acceptance criteria verified. Edge cases pass."),
    )
    MessageStore.save(msg9)
    print_message(msg9, "Step 9: QA passes all tests")

    # Final gate
    can_complete, gate_msg = WorkflowGate.can_mark_complete("TASK-048")
    print(f"\n  Completion Gate: {'✓' if can_complete else '✗'} {gate_msg}")

    # Step 10: Context update
    ContextManager.complete_task(
        "high", "TASK-048", "Implement StreakService with persistence",
        4.6, ["Services/StreakService.swift", "Models/StreakData.swift", "Protocols/StorageProtocol.swift"]
    )
    ContextManager.add_learning("high", "Use Calendar.dateComponents for day math, not timeIntervalSince")
    ContextManager.unlock_files("TASK-048")

    print(f"\n  ✅ TASK-048 COMPLETE — Score: 4.6")

    # ============================================================
    # MEDIUM PRIORITY TEAM — Streak UI
    # ============================================================
    print("\n\n" + "═" * 60)
    print("  MEDIUM PRIORITY TEAM — Streak UI Card")
    print("═" * 60)

    # Depends on high-priority team finishing StreakService
    msg10 = Message(
        type=MessageType.TASK_ASSIGNMENT,
        sender=AgentIdentity("TechLeadAgent", "medium"),
        receiver=AgentIdentity("DeveloperAgent-1", "medium"),
        payload=task_assignment_payload(
            task_id="TASK-049",
            title="Add streak display card to HomeView",
            description="Show current streak count on HomeView with fire animation when streak >= 7 days.",
            acceptance_criteria=[
                "Streak card shows current count",
                "Fire animation appears at 7+ day streaks",
                "Card hidden when streak is 0",
                "Tapping card shows streak history",
                "Accessible via VoiceOver",
            ],
            files_affected=["Features/Home/HomeView.swift", "Features/Home/Components/StreakCard.swift"],
            priority=Priority.MEDIUM,
            depends_on=["TASK-048"],
        ),
    )
    MessageStore.save(msg10)
    ContextManager.add_current_work("medium", "TASK-049", "DeveloperAgent-1")
    print_message(msg10, "Step 10: Medium TechLead assigns UI task (depends on TASK-048)")

    # Quick approval path for demo brevity
    msg11 = Message(
        type=MessageType.CODE_SUBMISSION,
        sender=AgentIdentity("DeveloperAgent-1", "medium"),
        receiver=AgentIdentity("ReviewerAgent", "medium"),
        parent_id=msg10.id,
        payload=code_submission_payload(
            task_id="TASK-049",
            files_changed=[
                {"path": "Features/Home/Components/StreakCard.swift", "diff_summary": "New SwiftUI card with streak count, fire animation, VoiceOver"},
                {"path": "Features/Home/HomeView.swift", "diff_summary": "Added StreakCard below prayer countdown"},
            ],
            test_coverage="Snapshot tests for 0, 1, 7, 30 day states. VoiceOver label tests.",
            self_review_notes="Checked team learnings: using @Published with async load, no sync cache access. "
                             "Fire animation uses matched geometry for smooth transitions.",
        ),
    )
    MessageStore.save(msg11)
    print_message(msg11, "Step 11: Medium Developer submits streak UI")

    msg12 = Message(
        type=MessageType.REVIEW_FEEDBACK,
        sender=AgentIdentity("ReviewerAgent", "medium"),
        receiver=AgentIdentity("DeveloperAgent-1", "medium"),
        parent_id=msg11.id,
        payload=review_feedback_payload(
            task_id="TASK-049",
            decision=ReviewDecision.APPROVE,
            scores={"correctness": 4, "readability": 5, "scalability": 4, "security": 4, "maintainability": 4},
        ),
    )
    MessageStore.save(msg12)
    print_message(msg12, "Step 12: Medium Reviewer approves")

    msg13 = Message(
        type=MessageType.APPROVAL,
        sender=AgentIdentity("QAAgent", "medium"),
        receiver=AgentIdentity("TechLeadAgent", "medium"),
        parent_id=msg12.id,
        payload=approval_payload("TASK-049", "qa", "All criteria met. VoiceOver reads correctly."),
    )
    MessageStore.save(msg13)
    print_message(msg13, "Step 13: Medium QA passes")

    ContextManager.complete_task(
        "medium", "TASK-049", "Add streak display card to HomeView",
        4.2, ["Features/Home/HomeView.swift", "Features/Home/Components/StreakCard.swift"]
    )

    print(f"\n  ✅ TASK-049 COMPLETE — Score: 4.2")

    # ============================================================
    # FINAL SUMMARY
    # ============================================================
    print(f"""

{'═' * 60}
  SIMULATION COMPLETE — SUMMARY
{'═' * 60}

  Messages exchanged: 13
  Tasks completed: 2 (TASK-048, TASK-049)
  Reviews: 4 (1 rejection, 3 approvals)
  Bugs found: 1 (midnight boundary edge case)
  Cross-team dependency: TASK-049 depended on TASK-048

  High Team Context Updated:
    • Completed: StreakService implementation
    • Learning: Use Calendar.dateComponents for day math
    • Reviewer pattern: Direct UserDefaults coupling

  Medium Team Context Updated:
    • Completed: Streak UI card
    • Dependency satisfied: TASK-048 → TASK-049

{'═' * 60}
""")

    # Print final context state
    print("  HIGH PRIORITY CONTEXT (final state):")
    ctx = ContextManager.load("high")
    print(f"  {json.dumps(ctx, indent=2)[:500]}...")

    print(f"\n  MEDIUM PRIORITY CONTEXT (final state):")
    ctx = ContextManager.load("medium")
    print(f"  {json.dumps(ctx, indent=2)[:500]}...")


if __name__ == "__main__":
    run_simulation()
