"""
Message schemas and validation for the multi-agent communication protocol.
"""

from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Optional
from datetime import datetime
import uuid
import json


class MessageType(Enum):
    TASK_ASSIGNMENT = "TaskAssignment"
    PROGRESS_UPDATE = "ProgressUpdate"
    CODE_SUBMISSION = "CodeSubmission"
    REVIEW_FEEDBACK = "ReviewFeedback"
    BUG_REPORT = "BugReport"
    APPROVAL = "Approval"
    REJECTION = "Rejection"


class TaskStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    READY_FOR_REVIEW = "ready_for_review"
    IN_REVIEW = "in_review"
    CHANGES_REQUESTED = "changes_requested"
    APPROVED = "approved"
    IN_QA = "in_qa"
    QA_FAILED = "qa_failed"
    COMPLETED = "completed"


class Priority(Enum):
    HIGH = "high"
    MEDIUM = "medium"


class Severity(Enum):
    CRITICAL = "critical"
    MAJOR = "major"
    MINOR = "minor"


class ReviewDecision(Enum):
    APPROVE = "approve"
    REQUEST_CHANGES = "request_changes"
    REJECT = "reject"


@dataclass
class AgentIdentity:
    agent: str
    team: str

    def to_dict(self):
        return {"agent": self.agent, "team": self.team}


@dataclass
class Message:
    type: MessageType
    sender: AgentIdentity
    receiver: AgentIdentity
    payload: dict
    parent_id: Optional[str] = None
    id: str = field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: str = field(default_factory=lambda: datetime.utcnow().isoformat() + "Z")

    def to_dict(self):
        return {
            "id": self.id,
            "type": self.type.value,
            "from": self.sender.to_dict(),
            "to": self.receiver.to_dict(),
            "timestamp": self.timestamp,
            "parent_id": self.parent_id,
            "payload": self.payload,
        }

    def to_json(self, indent=2):
        return json.dumps(self.to_dict(), indent=indent)

    @classmethod
    def from_dict(cls, data: dict) -> "Message":
        return cls(
            id=data["id"],
            type=MessageType(data["type"]),
            sender=AgentIdentity(**data["from"]),
            receiver=AgentIdentity(**data["to"]),
            timestamp=data["timestamp"],
            parent_id=data.get("parent_id"),
            payload=data["payload"],
        )


# --- Payload Builders ---

def task_assignment_payload(
    task_id: str,
    title: str,
    description: str,
    acceptance_criteria: list[str],
    files_affected: list[str],
    priority: Priority,
    depends_on: list[str] = None,
    deadline: str = None,
) -> dict:
    return {
        "task_id": task_id,
        "title": title,
        "description": description,
        "acceptance_criteria": acceptance_criteria,
        "files_affected": files_affected,
        "priority": priority.value,
        "depends_on": depends_on or [],
        "deadline": deadline,
    }


def progress_update_payload(
    task_id: str,
    status: TaskStatus,
    percent_complete: int,
    blockers: list[str] = None,
    notes: str = "",
) -> dict:
    return {
        "task_id": task_id,
        "status": status.value,
        "percent_complete": percent_complete,
        "blockers": blockers or [],
        "notes": notes,
    }


def code_submission_payload(
    task_id: str,
    files_changed: list[dict],
    test_coverage: str,
    self_review_notes: str,
) -> dict:
    return {
        "task_id": task_id,
        "files_changed": files_changed,
        "test_coverage": test_coverage,
        "self_review_notes": self_review_notes,
    }


def review_feedback_payload(
    task_id: str,
    decision: ReviewDecision,
    scores: dict,
    comments: list[dict] = None,
    blocking_issues: list[str] = None,
) -> dict:
    avg = sum(scores.values()) / len(scores) if scores else 0
    return {
        "task_id": task_id,
        "decision": decision.value,
        "scores": scores,
        "average": round(avg, 1),
        "comments": comments or [],
        "blocking_issues": blocking_issues or [],
    }


def bug_report_payload(
    task_id: str,
    severity: Severity,
    description: str,
    steps_to_reproduce: list[str],
    expected: str,
    actual: str,
    evidence: str = "",
) -> dict:
    return {
        "task_id": task_id,
        "severity": severity.value,
        "description": description,
        "steps_to_reproduce": steps_to_reproduce,
        "expected": expected,
        "actual": actual,
        "evidence": evidence,
    }


def approval_payload(task_id: str, stage: str, reason: str = "") -> dict:
    return {"task_id": task_id, "stage": stage, "reason": reason}


def rejection_payload(task_id: str, stage: str, reason: str) -> dict:
    return {"task_id": task_id, "stage": stage, "reason": reason}
