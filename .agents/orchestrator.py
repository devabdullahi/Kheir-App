"""
Multi-Agent Development Team Orchestrator

Coordinates autonomous agents through a structured workflow:
  Task Intake → Breakdown → Assignment → Implementation → Review → QA → Completion

Usage:
    python .agents/orchestrator.py run --feature "Add streak tracking to Home"
    python .agents/orchestrator.py status
    python .agents/orchestrator.py context --team high
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional
from dataclasses import dataclass, field

# Add parent to path for schema imports
sys.path.insert(0, str(Path(__file__).parent))
from schemas.messages import (
    Message, MessageType, AgentIdentity, TaskStatus, Priority,
    ReviewDecision, Severity, task_assignment_payload,
    progress_update_payload, code_submission_payload,
    review_feedback_payload, bug_report_payload, approval_payload,
)

BASE_DIR = Path(__file__).parent
CONTEXT_DIR = BASE_DIR / "context"
MESSAGES_DIR = BASE_DIR / "messages"
ROLES_DIR = BASE_DIR / "roles"

MESSAGES_DIR.mkdir(exist_ok=True)


# --- Context Management ---

class ContextManager:
    """Manages team context files — the persistent shared memory."""

    @staticmethod
    def load(team: str) -> dict:
        path = CONTEXT_DIR / f"team_{team}_context.json"
        with open(path) as f:
            return json.load(f)

    @staticmethod
    def save(team: str, context: dict):
        context["last_updated"] = datetime.utcnow().isoformat() + "Z"
        path = CONTEXT_DIR / f"team_{team}_context.json"
        with open(path, "w") as f:
            json.dump(context, f, indent=2)

    @staticmethod
    def add_current_work(team: str, task_id: str, assignee: str):
        ctx = ContextManager.load(team)
        ctx["current_work"].append({
            "task_id": task_id,
            "assignee": assignee,
            "status": "in_progress",
            "started_at": datetime.utcnow().isoformat() + "Z",
            "blockers": [],
        })
        ContextManager.save(team, ctx)

    @staticmethod
    def complete_task(team: str, task_id: str, title: str, score: float, files: list):
        ctx = ContextManager.load(team)
        # Remove from current
        ctx["current_work"] = [w for w in ctx["current_work"] if w["task_id"] != task_id]
        # Add to completed
        ctx["completed_work"].append({
            "task_id": task_id,
            "title": title,
            "completed_at": datetime.utcnow().isoformat() + "Z",
            "review_score": score,
            "files_changed": files,
        })
        ContextManager.save(team, ctx)

    @staticmethod
    def add_learning(team: str, learning: str):
        ctx = ContextManager.load(team)
        if learning not in ctx["learnings"]:
            ctx["learnings"].append(learning)
        ContextManager.save(team, ctx)

    @staticmethod
    def add_error(team: str, task_id: str, issue: str):
        ctx = ContextManager.load(team)
        ctx["errors_and_issues"].append({
            "task_id": task_id,
            "issue": issue,
            "resolved": False,
            "timestamp": datetime.utcnow().isoformat() + "Z",
        })
        ContextManager.save(team, ctx)

    @staticmethod
    def add_reviewer_pattern(team: str, pattern: str):
        ctx = ContextManager.load(team)
        existing = next(
            (p for p in ctx["reviewer_feedback_summary"] if p["pattern"] == pattern),
            None
        )
        if existing:
            existing["frequency"] += 1
        else:
            ctx["reviewer_feedback_summary"].append({"pattern": pattern, "frequency": 1})
        ContextManager.save(team, ctx)

    @staticmethod
    def load_shared() -> dict:
        path = CONTEXT_DIR / "shared_dependencies.json"
        with open(path) as f:
            return json.load(f)

    @staticmethod
    def save_shared(data: dict):
        data["last_updated"] = datetime.utcnow().isoformat() + "Z"
        path = CONTEXT_DIR / "shared_dependencies.json"
        with open(path, "w") as f:
            json.dump(data, f, indent=2)

    @staticmethod
    def lock_files(team: str, task_id: str, files: list[str]):
        shared = ContextManager.load_shared()
        for f in files:
            shared["locked_files"].append({
                "file": f,
                "team": team,
                "task_id": task_id,
                "locked_at": datetime.utcnow().isoformat() + "Z",
            })
        ContextManager.save_shared(shared)

    @staticmethod
    def unlock_files(task_id: str):
        shared = ContextManager.load_shared()
        shared["locked_files"] = [
            lf for lf in shared["locked_files"] if lf["task_id"] != task_id
        ]
        ContextManager.save_shared(shared)

    @staticmethod
    def check_conflicts(files: list[str], team: str) -> list[dict]:
        shared = ContextManager.load_shared()
        conflicts = []
        for lf in shared["locked_files"]:
            if lf["file"] in files and lf["team"] != team:
                conflicts.append(lf)
        return conflicts


# --- Message Store ---

class MessageStore:
    """Persists and queries messages."""

    @staticmethod
    def save(message: Message):
        path = MESSAGES_DIR / f"{message.id}.json"
        with open(path, "w") as f:
            json.dump(message.to_dict(), f, indent=2)

    @staticmethod
    def load(message_id: str) -> Optional[Message]:
        path = MESSAGES_DIR / f"{message_id}.json"
        if not path.exists():
            return None
        with open(path) as f:
            return Message.from_dict(json.load(f))

    @staticmethod
    def find_by_task(task_id: str) -> list[Message]:
        messages = []
        for path in MESSAGES_DIR.glob("*.json"):
            with open(path) as f:
                data = json.load(f)
            if data.get("payload", {}).get("task_id") == task_id:
                messages.append(Message.from_dict(data))
        messages.sort(key=lambda m: m.timestamp)
        return messages

    @staticmethod
    def find_by_type(msg_type: MessageType) -> list[Message]:
        messages = []
        for path in MESSAGES_DIR.glob("*.json"):
            with open(path) as f:
                data = json.load(f)
            if data.get("type") == msg_type.value:
                messages.append(Message.from_dict(data))
        return messages


# --- Workflow Engine ---

class WorkflowGate:
    """Enforces workflow rules — the core of the orchestrator."""

    @staticmethod
    def can_submit_to_qa(task_id: str) -> tuple[bool, str]:
        """QA only tests code that has passed review."""
        messages = MessageStore.find_by_task(task_id)
        approvals = [
            m for m in messages
            if m.type == MessageType.REVIEW_FEEDBACK
            and m.payload.get("decision") == "approve"
        ]
        if not approvals:
            return False, "Cannot submit to QA: no ReviewerAgent approval found"
        return True, "Approved for QA"

    @staticmethod
    def can_mark_complete(task_id: str) -> tuple[bool, str]:
        """Tasks cannot be complete without Reviewer AND QA approval."""
        messages = MessageStore.find_by_task(task_id)

        review_approved = any(
            m.type == MessageType.REVIEW_FEEDBACK
            and m.payload.get("decision") == "approve"
            for m in messages
        )
        qa_approved = any(
            m.type == MessageType.APPROVAL
            and m.payload.get("stage") == "qa"
            for m in messages
        )

        if not review_approved:
            return False, "Cannot complete: missing ReviewerAgent approval"
        if not qa_approved:
            return False, "Cannot complete: missing QAAgent approval"
        return True, "Ready for completion"

    @staticmethod
    def validate_review_feedback(payload: dict) -> tuple[bool, str]:
        """All feedback must be actionable."""
        scores = payload.get("scores", {})
        if not scores:
            return False, "Review must include rubric scores"

        decision = payload.get("decision")
        if decision in ("request_changes", "reject"):
            if not payload.get("comments") and not payload.get("blocking_issues"):
                return False, "Rejections must include actionable comments or blocking issues"

        # Check for automatic rejection (any score at 1)
        if any(v == 1 for v in scores.values()):
            if decision != "reject":
                return False, "Any rubric score at 1 requires rejection"

        return True, "Valid review"


# --- Agent Runner ---

class AgentRunner:
    """
    Executes agent actions by loading role prompts and invoking them.
    In production, this calls Claude Code subagents.
    In simulation mode, it logs expected behavior.
    """

    def __init__(self, team: str, simulate: bool = True):
        self.team = team
        self.simulate = simulate

    def get_role_prompt(self, role: str, agent_id: str = "1") -> str:
        path = ROLES_DIR / f"{role}.md"
        with open(path) as f:
            template = f.read()
        team_name = "HighPriorityTeam" if self.team == "high" else "MediumPriorityTeam"
        return (
            template
            .replace("{{TEAM_NAME}}", team_name)
            .replace("{{TEAM_PRIORITY}}", self.team)
            .replace("{{AGENT_ID}}", agent_id)
        )

    def invoke_agent(self, role: str, context: dict, task_message: Message) -> Message:
        """
        Invoke an agent with its role prompt + context + task.
        Returns the agent's response message.

        In production: spawns a Claude Code subagent via the Agent tool.
        In simulation: returns a mock response for demonstration.
        """
        if self.simulate:
            return self._simulate_response(role, task_message)
        else:
            # Production: would call Claude Code Agent tool here
            raise NotImplementedError(
                "Production mode requires Claude Code Agent tool integration. "
                "Use simulate=True for demonstration."
            )

    def _simulate_response(self, role: str, task_message: Message) -> Message:
        """Generate a simulated agent response for demo purposes."""
        task_id = task_message.payload.get("task_id", "TASK-000")

        if role == "tech_lead":
            return Message(
                type=MessageType.TASK_ASSIGNMENT,
                sender=AgentIdentity("TechLeadAgent", self.team),
                receiver=AgentIdentity("DeveloperAgent-1", self.team),
                payload=task_message.payload,
            )
        elif role == "developer":
            return Message(
                type=MessageType.CODE_SUBMISSION,
                sender=AgentIdentity("DeveloperAgent-1", self.team),
                receiver=AgentIdentity("ReviewerAgent", self.team),
                parent_id=task_message.id,
                payload=code_submission_payload(
                    task_id=task_id,
                    files_changed=[{"path": "Features/Home/HomeView.swift", "diff_summary": "Implementation added"}],
                    test_coverage="Unit tests added",
                    self_review_notes="Checked against rubric",
                ),
            )
        elif role == "reviewer":
            return Message(
                type=MessageType.REVIEW_FEEDBACK,
                sender=AgentIdentity("ReviewerAgent", self.team),
                receiver=AgentIdentity("DeveloperAgent-1", self.team),
                parent_id=task_message.id,
                payload=review_feedback_payload(
                    task_id=task_id,
                    decision=ReviewDecision.APPROVE,
                    scores={"correctness": 4, "readability": 4, "scalability": 4, "security": 4, "maintainability": 4},
                ),
            )
        elif role == "qa":
            return Message(
                type=MessageType.APPROVAL,
                sender=AgentIdentity("QAAgent", self.team),
                receiver=AgentIdentity("TechLeadAgent", self.team),
                parent_id=task_message.id,
                payload=approval_payload(task_id, "qa", "All acceptance criteria verified"),
            )
        else:
            raise ValueError(f"Unknown role: {role}")


# --- Orchestrator ---

class Orchestrator:
    """
    Main orchestrator that drives the full workflow for a team.
    Manages state transitions and enforces all gates.
    """

    def __init__(self, team: str, simulate: bool = True):
        self.team = team
        self.runner = AgentRunner(team, simulate)
        self.task_counter = self._get_next_task_id()

    def _get_next_task_id(self) -> int:
        ctx = ContextManager.load(self.team)
        completed = len(ctx["completed_work"])
        current = len(ctx["current_work"])
        planned = len(ctx["planned_work"])
        return completed + current + planned + 1

    def run_feature(self, title: str, description: str, acceptance_criteria: list[str],
                    files_affected: list[str], priority: Priority = None):
        """
        Execute the full workflow for a feature.
        Returns the complete message trail.
        """
        if priority is None:
            priority = Priority.HIGH if self.team == "high" else Priority.MEDIUM

        task_id = f"TASK-{self.task_counter:03d}"
        self.task_counter += 1
        trail = []

        print(f"\n{'='*60}")
        print(f"  ORCHESTRATOR [{self.team.upper()}] — Starting: {title}")
        print(f"  Task ID: {task_id}")
        print(f"{'='*60}\n")

        # --- Step 1: Check for conflicts ---
        conflicts = ContextManager.check_conflicts(files_affected, self.team)
        if conflicts:
            print(f"  ⚠ CONFLICT: Files locked by other team: {conflicts}")
            if self.team == "medium":
                print(f"  ⏸ Queuing until high-priority work completes")
                return trail
            else:
                print(f"  ▶ High-priority override — proceeding")

        # --- Step 2: Lock files ---
        ContextManager.lock_files(self.team, task_id, files_affected)
        print(f"  🔒 Locked files: {files_affected}")

        # --- Step 3: TechLead creates assignment ---
        print(f"\n  [1/8] TechLead → Task Breakdown & Assignment")
        assignment_msg = Message(
            type=MessageType.TASK_ASSIGNMENT,
            sender=AgentIdentity("TechLeadAgent", self.team),
            receiver=AgentIdentity("DeveloperAgent-1", self.team),
            payload=task_assignment_payload(
                task_id=task_id,
                title=title,
                description=description,
                acceptance_criteria=acceptance_criteria,
                files_affected=files_affected,
                priority=priority,
            ),
        )
        MessageStore.save(assignment_msg)
        trail.append(assignment_msg)
        ContextManager.add_current_work(self.team, task_id, "DeveloperAgent-1")
        print(f"       Assigned to DeveloperAgent-1")

        # --- Step 4: Developer implements ---
        print(f"  [2/8] Developer → Implementation")
        progress_msg = Message(
            type=MessageType.PROGRESS_UPDATE,
            sender=AgentIdentity("DeveloperAgent-1", self.team),
            receiver=AgentIdentity("TechLeadAgent", self.team),
            parent_id=assignment_msg.id,
            payload=progress_update_payload(task_id, TaskStatus.IN_PROGRESS, 50, notes="Working on implementation"),
        )
        MessageStore.save(progress_msg)
        trail.append(progress_msg)

        submission = self.runner.invoke_agent("developer", {}, assignment_msg)
        MessageStore.save(submission)
        trail.append(submission)
        print(f"       Code submitted for review")

        # --- Step 5: Reviewer reviews ---
        print(f"  [3/8] Reviewer → Code Review")
        review = self.runner.invoke_agent("reviewer", {}, submission)

        # Validate review
        valid, reason = WorkflowGate.validate_review_feedback(review.payload)
        if not valid:
            print(f"       ❌ Invalid review: {reason}")
            return trail

        MessageStore.save(review)
        trail.append(review)

        decision = review.payload["decision"]
        avg_score = review.payload["average"]
        print(f"       Decision: {decision} (avg: {avg_score})")

        # --- Step 5b: Handle rejection loop ---
        revision_count = 0
        max_revisions = 3
        while decision != "approve" and revision_count < max_revisions:
            revision_count += 1
            print(f"  [3b/8] Developer → Revision #{revision_count}")

            # Record reviewer patterns
            for comment in review.payload.get("comments", []):
                issue = comment.get("issue", "")
                if issue:
                    ContextManager.add_reviewer_pattern(self.team, issue[:80])

            # Developer fixes and resubmits
            resubmission = self.runner.invoke_agent("developer", {}, review)
            MessageStore.save(resubmission)
            trail.append(resubmission)

            # Re-review
            review = self.runner.invoke_agent("reviewer", {}, resubmission)
            valid, reason = WorkflowGate.validate_review_feedback(review.payload)
            if not valid:
                print(f"       ❌ Invalid review: {reason}")
                ContextManager.add_error(self.team, task_id, f"Review validation failed: {reason}")
                return trail

            MessageStore.save(review)
            trail.append(review)
            decision = review.payload["decision"]
            avg_score = review.payload["average"]
            print(f"       Re-review: {decision} (avg: {avg_score})")

        if decision != "approve":
            print(f"  ❌ Task rejected after {max_revisions} revisions — escalating")
            ContextManager.add_error(self.team, task_id, f"Rejected after {max_revisions} revision attempts")
            ContextManager.unlock_files(task_id)
            return trail

        # --- Step 6: QA Gate Check ---
        print(f"  [4/8] Gate Check → QA Eligibility")
        can_qa, gate_msg = WorkflowGate.can_submit_to_qa(task_id)
        if not can_qa:
            print(f"       ❌ {gate_msg}")
            return trail
        print(f"       ✓ {gate_msg}")

        # --- Step 7: QA Testing ---
        print(f"  [5/8] QA → Testing")
        qa_result = self.runner.invoke_agent("qa", {}, review)
        MessageStore.save(qa_result)
        trail.append(qa_result)

        if qa_result.type == MessageType.BUG_REPORT:
            print(f"       🐛 Bug found: {qa_result.payload.get('description', 'Unknown')}")
            ContextManager.add_error(self.team, task_id, qa_result.payload.get("description", "QA bug"))

            # Developer fixes
            print(f"  [6/8] Developer → Bug Fix")
            fix = self.runner.invoke_agent("developer", {}, qa_result)
            MessageStore.save(fix)
            trail.append(fix)

            # Re-review the fix
            print(f"  [6b/8] Reviewer → Re-review fix")
            re_review = self.runner.invoke_agent("reviewer", {}, fix)
            MessageStore.save(re_review)
            trail.append(re_review)

            # Re-QA
            print(f"  [6c/8] QA → Re-test")
            qa_result = self.runner.invoke_agent("qa", {}, re_review)
            MessageStore.save(qa_result)
            trail.append(qa_result)

        if qa_result.type == MessageType.APPROVAL:
            print(f"       ✓ QA Passed")
        else:
            print(f"       ❌ QA failed after retry — escalating")
            ContextManager.add_error(self.team, task_id, "QA failed after fix attempt")
            ContextManager.unlock_files(task_id)
            return trail

        # --- Step 8: Final Completion Gate ---
        print(f"  [7/8] Gate Check → Completion Eligibility")
        can_complete, gate_msg = WorkflowGate.can_mark_complete(task_id)
        if not can_complete:
            print(f"       ❌ {gate_msg}")
            return trail
        print(f"       ✓ {gate_msg}")

        # --- Step 9: Context Update ---
        print(f"  [8/8] Context Update → Marking Complete")
        ContextManager.complete_task(
            self.team, task_id, title, avg_score, files_affected
        )
        ContextManager.unlock_files(task_id)
        print(f"       ✓ Task {task_id} completed (score: {avg_score})")

        print(f"\n{'='*60}")
        print(f"  ✅ FEATURE COMPLETE: {title}")
        print(f"  Messages exchanged: {len(trail)}")
        print(f"  Revisions required: {revision_count}")
        print(f"  Final review score: {avg_score}")
        print(f"{'='*60}\n")

        return trail

    def status(self):
        """Print current team status from context file."""
        ctx = ContextManager.load(self.team)
        team_name = "HIGH PRIORITY" if self.team == "high" else "MEDIUM PRIORITY"
        print(f"\n{'─'*50}")
        print(f"  {team_name} TEAM STATUS")
        print(f"  Last updated: {ctx['last_updated']}")
        print(f"{'─'*50}")
        print(f"\n  Completed: {len(ctx['completed_work'])} tasks")
        for t in ctx["completed_work"][-5:]:
            print(f"    ✓ {t['task_id']}: {t['title']} (score: {t['review_score']})")
        print(f"\n  In Progress: {len(ctx['current_work'])} tasks")
        for t in ctx["current_work"]:
            print(f"    ▶ {t['task_id']} → {t['assignee']} [{t['status']}]")
        print(f"\n  Planned: {len(ctx['planned_work'])} tasks")
        print(f"\n  Errors: {len(ctx['errors_and_issues'])} issues")
        for e in ctx["errors_and_issues"][-3:]:
            status = "✓" if e.get("resolved") else "✗"
            print(f"    {status} {e['task_id']}: {e['issue']}")
        print(f"\n  Learnings: {len(ctx['learnings'])}")
        for l in ctx["learnings"][-5:]:
            print(f"    • {l}")
        print(f"\n  Reviewer Patterns:")
        for p in ctx["reviewer_feedback_summary"]:
            print(f"    [{p['frequency']}x] {p['pattern']}")
        print()


# --- CLI ---

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Multi-Agent Dev Team Orchestrator")
    subparsers = parser.add_subparsers(dest="command")

    # Run command
    run_parser = subparsers.add_parser("run", help="Run a feature through the workflow")
    run_parser.add_argument("--feature", required=True, help="Feature title")
    run_parser.add_argument("--description", default="", help="Feature description")
    run_parser.add_argument("--criteria", nargs="+", default=["Feature works as specified"], help="Acceptance criteria")
    run_parser.add_argument("--files", nargs="+", default=["Features/Home/HomeView.swift"], help="Files affected")
    run_parser.add_argument("--team", choices=["high", "medium"], default="high", help="Team assignment")

    # Status command
    status_parser = subparsers.add_parser("status", help="Show team status")
    status_parser.add_argument("--team", choices=["high", "medium", "both"], default="both")

    # Context command
    ctx_parser = subparsers.add_parser("context", help="View raw context file")
    ctx_parser.add_argument("--team", choices=["high", "medium"], required=True)

    # Messages command
    msg_parser = subparsers.add_parser("messages", help="View messages for a task")
    msg_parser.add_argument("--task", required=True, help="Task ID")

    args = parser.parse_args()

    if args.command == "run":
        orch = Orchestrator(args.team, simulate=True)
        orch.run_feature(
            title=args.feature,
            description=args.description,
            acceptance_criteria=args.criteria,
            files_affected=args.files,
        )

    elif args.command == "status":
        teams = ["high", "medium"] if args.team == "both" else [args.team]
        for t in teams:
            Orchestrator(t).status()

    elif args.command == "context":
        ctx = ContextManager.load(args.team)
        print(json.dumps(ctx, indent=2))

    elif args.command == "messages":
        messages = MessageStore.find_by_task(args.task)
        for m in messages:
            print(f"\n[{m.timestamp}] {m.type.value}")
            print(f"  From: {m.sender.agent} ({m.sender.team})")
            print(f"  To:   {m.receiver.agent} ({m.receiver.team})")
            print(f"  {json.dumps(m.payload, indent=4)}")

    else:
        parser.print_help()


if __name__ == "__main__":
    main()
