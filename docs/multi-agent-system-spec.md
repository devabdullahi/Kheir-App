# Multi-Agent Software Development Team Specification

## 1. System Overview

This specification defines an autonomous multi-agent system for planning, building, reviewing, and delivering features for the Revenge iOS app. Agents communicate via structured JSON messages, maintain persistent context files, and follow strict workflow gates.

---

## 2. Team Division

| Property | HighPriorityTeam | MediumPriorityTeam |
|----------|-----------------|-------------------|
| Scope | Critical path, time-sensitive, blocking | Important improvements, non-blocking |
| SLA | 1 sprint cycle | 2 sprint cycles |
| Escalation | Direct to human | Via HighPriority TechLead |
| Context File | `team_high_context.json` | `team_medium_context.json` |

Both teams have read-only access to each other's context files.

---

## 3. Agent Definitions

### TechLeadAgent
- **Capabilities**: Architecture planning, task decomposition, assignment, dependency resolution, escalation
- **Constraints**: Does not write implementation code. Delegates all coding to DeveloperAgents.
- **Inputs**: Feature requests, bug reports, context files
- **Outputs**: TaskAssignment messages, architecture decisions

### DeveloperAgent (2-3 per team)
- **Capabilities**: Write Swift/SwiftUI code, create tests, fix bugs, refactor
- **Constraints**: Cannot merge without ReviewerAgent approval. Must follow architecture from TechLead.
- **Inputs**: TaskAssignment messages
- **Outputs**: CodeSubmission messages, ProgressUpdate messages

### QAAgent
- **Capabilities**: Write and run tests, validate behavior, report bugs
- **Constraints**: Only tests code that has passed review. Does not fix bugs directly.
- **Inputs**: Approved CodeSubmissions
- **Outputs**: BugReport messages, Approval messages

### ReviewerAgent
- **Capabilities**: Code review against rubric, cross-team audits
- **Constraints**: NEVER writes implementation code. Not evaluated on delivery speed. Cannot be pressured to approve.
- **Scoring Rubric** (each 1-5):
  - Correctness: Logic, edge cases, crash safety
  - Readability: Naming, structure, comments where needed
  - Scalability: Performance under growth, no N+1 patterns
  - Security: Input validation, no hardcoded secrets, safe concurrency
  - Maintainability: SOLID adherence, testability, minimal coupling
- **Threshold**: Average >= 3.5 required. Any dimension at 1 = automatic rejection.
- **Cross-team audit**: Reviews 1 submission from the other team per cycle.

---

## 4. Communication Protocol

### Message Schema

```json
{
  "id": "uuid-v4",
  "type": "TaskAssignment | ProgressUpdate | CodeSubmission | ReviewFeedback | BugReport | Approval | Rejection",
  "from": { "agent": "string", "team": "high | medium" },
  "to": { "agent": "string", "team": "high | medium" },
  "timestamp": "ISO-8601",
  "parent_id": "uuid-v4 | null",
  "payload": {}
}
```

### Payload by Type

**TaskAssignment**
```json
{
  "task_id": "TASK-001",
  "title": "Implement Quran audio resume",
  "description": "...",
  "acceptance_criteria": ["AC1", "AC2"],
  "files_affected": ["Features/Quran/ReadingViewModel.swift"],
  "priority": "high | medium",
  "depends_on": ["TASK-000"],
  "deadline": "ISO-8601"
}
```

**ProgressUpdate**
```json
{
  "task_id": "TASK-001",
  "status": "in_progress | blocked | ready_for_review",
  "percent_complete": 70,
  "blockers": [],
  "notes": "..."
}
```

**CodeSubmission**
```json
{
  "task_id": "TASK-001",
  "files_changed": [
    { "path": "Features/Quran/ReadingViewModel.swift", "diff_summary": "Added resumePlayback()" }
  ],
  "test_coverage": "unit tests added for resume logic",
  "self_review_notes": "Checked edge case for nil position"
}
```

**ReviewFeedback**
```json
{
  "task_id": "TASK-001",
  "decision": "approve | request_changes | reject",
  "scores": {
    "correctness": 4,
    "readability": 5,
    "scalability": 3,
    "security": 4,
    "maintainability": 4
  },
  "average": 4.0,
  "comments": [
    { "file": "ReadingViewModel.swift", "line": 45, "issue": "...", "suggestion": "..." }
  ],
  "blocking_issues": []
}
```

**BugReport**
```json
{
  "task_id": "TASK-001",
  "severity": "critical | major | minor",
  "description": "Audio does not resume after backgrounding",
  "steps_to_reproduce": ["1. Start playback", "2. Background app", "3. Return"],
  "expected": "Resumes from saved position",
  "actual": "Restarts from beginning",
  "evidence": "Test output attached"
}
```

**Approval / Rejection**
```json
{
  "task_id": "TASK-001",
  "stage": "review | qa | final",
  "reason": "All criteria met / Fails AC2"
}
```

### Communication Rules
1. No task reaches "complete" without ReviewerAgent approval.
2. QAAgent only receives code after review approval.
3. All feedback must include actionable suggestions, not just criticism.
4. Rejections must cite specific rubric dimensions.
5. Messages are immutable once sent; corrections use new messages with `parent_id`.

---

## 5. Team Context File

Each team maintains a single persistent JSON file updated after every workflow step.

```json
{
  "team": "high",
  "last_updated": "ISO-8601",
  "completed_work": [
    {
      "task_id": "TASK-001",
      "title": "...",
      "completed_at": "ISO-8601",
      "review_score": 4.2,
      "files_changed": []
    }
  ],
  "current_work": [
    {
      "task_id": "TASK-002",
      "assignee": "DeveloperAgent-1",
      "status": "in_progress",
      "started_at": "ISO-8601",
      "blockers": []
    }
  ],
  "planned_work": [
    { "task_id": "TASK-003", "title": "...", "depends_on": ["TASK-002"] }
  ],
  "errors_and_issues": [
    { "task_id": "TASK-001", "issue": "...", "resolved": true }
  ],
  "learnings": [
    "CacheManager writes must be dispatched to main thread for UI updates"
  ],
  "reviewer_feedback_summary": [
    { "pattern": "Missing guard clauses on optional unwrapping", "frequency": 3 }
  ]
}
```

---

## 6. Workflow

```
[Feature Request]
       |
       v
+------------------+
| 1. Task Intake   |  TechLead receives, validates against context file
+------------------+
       |
       v
+------------------+
| 2. Breakdown     |  TechLead decomposes into subtasks, identifies dependencies
+------------------+
       |
       v
+------------------+
| 3. Assignment    |  TechLead sends TaskAssignment to available DeveloperAgent
+------------------+
       |
       v
+------------------+
| 4. Implementation|  Developer codes, sends ProgressUpdates, submits CodeSubmission
+------------------+
       |
       v
+------------------+
| 5. Review        |  ReviewerAgent scores against rubric
+------------------+
      / \
     /   \
  Pass   Fail --> Developer fixes --> back to step 5
   |
   v
+------------------+
| 6. QA Testing    |  QAAgent validates acceptance criteria
+------------------+
      / \
     /   \
  Pass   Bug --> BugReport to Developer --> fix --> back to step 5
   |
   v
+------------------+
| 7. Final Approval|  TechLead confirms, updates context file
+------------------+
       |
       v
+------------------+
| 8. Context Update|  Completed work logged, learnings captured
+------------------+
```

---

## 7. Cross-Team Coordination

- **Shared dependency registry**: Both TechLeads maintain a `shared_dependencies.json` listing files under active modification. Before assigning work, TechLead checks for conflicts.
- **File locking**: If both teams need the same file, HighPriority takes precedence. MediumPriority queues until complete.
- **Cross-team audit**: Each ReviewerAgent audits 1 random completed task from the other team per cycle. Findings go to both TechLeads.
- **Escalation path**: MediumPriority blockers caused by HighPriority changes escalate to HighPriority TechLead within 1 hour.
- **Read-only context access**: Either team can read (never write) the other's context file to understand state.

---

## 8. Memory and State

| Memory Type | Scope | Persistence | Content |
|-------------|-------|-------------|---------|
| Task Memory | Per agent, per task | Duration of task | Current assignment, progress, local decisions |
| Team Context | Per team | Permanent | All sections from Section 5 |
| Shared State | Cross-team | Permanent | `shared_dependencies.json`, escalation log |
| Agent Profile | Per agent | Permanent | Capabilities, historical performance, patterns to avoid |

Agents reference the team context file before starting any new work to avoid repeating mistakes and to understand current state.

---

## 9. Example Simulation

**Scenario**: Implement "Continue Reading" bookmark indicator on HomeView.

### Step 1: Task Intake
```json
{
  "id": "msg-001",
  "type": "TaskAssignment",
  "from": { "agent": "TechLeadAgent", "team": "high" },
  "to": { "agent": "DeveloperAgent-1", "team": "high" },
  "timestamp": "2026-04-20T09:00:00Z",
  "parent_id": null,
  "payload": {
    "task_id": "TASK-047",
    "title": "Add continue reading indicator to HomeView",
    "description": "Show a card on HomeView displaying last read Surah/Ayah with a tap to resume.",
    "acceptance_criteria": [
      "Card shows Surah name and Ayah number",
      "Tapping navigates to ReadingView at saved position",
      "Card hidden if no reading history exists"
    ],
    "files_affected": ["Features/Home/HomeView.swift", "Features/Home/HomeViewModel.swift"],
    "priority": "high",
    "depends_on": [],
    "deadline": "2026-04-21T17:00:00Z"
  }
}
```

### Step 2: Developer submits code
```json
{
  "id": "msg-002",
  "type": "CodeSubmission",
  "from": { "agent": "DeveloperAgent-1", "team": "high" },
  "to": { "agent": "ReviewerAgent", "team": "high" },
  "timestamp": "2026-04-20T14:30:00Z",
  "parent_id": "msg-001",
  "payload": {
    "task_id": "TASK-047",
    "files_changed": [
      { "path": "Features/Home/HomeView.swift", "diff_summary": "Added ContinueReadingCard view" },
      { "path": "Features/Home/HomeViewModel.swift", "diff_summary": "Added lastReadPosition computed property" }
    ],
    "test_coverage": "Unit test for lastReadPosition nil case",
    "self_review_notes": "Used optional binding for safety"
  }
}
```

### Step 3: Reviewer rejects
```json
{
  "id": "msg-003",
  "type": "ReviewFeedback",
  "from": { "agent": "ReviewerAgent", "team": "high" },
  "to": { "agent": "DeveloperAgent-1", "team": "high" },
  "timestamp": "2026-04-20T15:00:00Z",
  "parent_id": "msg-002",
  "payload": {
    "task_id": "TASK-047",
    "decision": "request_changes",
    "scores": {
      "correctness": 3,
      "readability": 4,
      "scalability": 4,
      "security": 4,
      "maintainability": 2
    },
    "average": 3.4,
    "comments": [
      {
        "file": "HomeViewModel.swift",
        "line": 28,
        "issue": "lastReadPosition directly accesses CacheManager synchronously on main thread, risking UI stutter on large cache files.",
        "suggestion": "Load asynchronously in init() or onAppear, store in @Published property."
      }
    ],
    "blocking_issues": ["Maintainability below threshold — tight coupling to CacheManager internals"]
  }
}
```

### Step 4: Developer fixes and resubmits
```json
{
  "id": "msg-004",
  "type": "CodeSubmission",
  "from": { "agent": "DeveloperAgent-1", "team": "high" },
  "to": { "agent": "ReviewerAgent", "team": "high" },
  "timestamp": "2026-04-20T16:00:00Z",
  "parent_id": "msg-003",
  "payload": {
    "task_id": "TASK-047",
    "files_changed": [
      { "path": "Features/Home/HomeViewModel.swift", "diff_summary": "Async loading via Task in loadLastRead(), @Published lastReadPosition" }
    ],
    "test_coverage": "Added async test for loadLastRead()",
    "self_review_notes": "Decoupled from CacheManager internals, uses service protocol"
  }
}
```

### Step 5: Reviewer approves
```json
{
  "id": "msg-005",
  "type": "ReviewFeedback",
  "from": { "agent": "ReviewerAgent", "team": "high" },
  "to": { "agent": "DeveloperAgent-1", "team": "high" },
  "timestamp": "2026-04-20T16:20:00Z",
  "parent_id": "msg-004",
  "payload": {
    "task_id": "TASK-047",
    "decision": "approve",
    "scores": { "correctness": 4, "readability": 5, "scalability": 4, "security": 4, "maintainability": 4 },
    "average": 4.2,
    "comments": [],
    "blocking_issues": []
  }
}
```

### Step 6: QA finds a bug
```json
{
  "id": "msg-006",
  "type": "BugReport",
  "from": { "agent": "QAAgent", "team": "high" },
  "to": { "agent": "DeveloperAgent-1", "team": "high" },
  "timestamp": "2026-04-20T17:00:00Z",
  "parent_id": "msg-005",
  "payload": {
    "task_id": "TASK-047",
    "severity": "minor",
    "description": "Card appears briefly with stale data before async load completes",
    "steps_to_reproduce": ["1. Clear cache", "2. Read Surah Al-Fatiha Ayah 3", "3. Kill app", "4. Relaunch"],
    "expected": "Card shows Al-Fatiha:3 after load",
    "actual": "Card flashes previous position for 200ms then updates",
    "evidence": "Captured in UI test recording"
  }
}
```

### Step 7: Fix, re-review, QA pass, context update

After the developer adds a loading state guard, the fix passes review (score 4.4) and QA. TechLead updates context:

```json
{
  "completed_work": [{
    "task_id": "TASK-047",
    "title": "Continue reading indicator on HomeView",
    "completed_at": "2026-04-20T18:30:00Z",
    "review_score": 4.4,
    "files_changed": ["Features/Home/HomeView.swift", "Features/Home/HomeViewModel.swift"]
  }],
  "learnings": [
    "Always use loading states for async-populated UI cards to prevent flash of stale content"
  ],
  "reviewer_feedback_summary": [
    { "pattern": "Synchronous cache access on main thread", "frequency": 4 }
  ]
}
```

---

## 10. Implementation Notes

- Each agent runs as a Claude Code subagent invoked with its role prompt and the relevant context file.
- Messages are stored in a shared `messages/` directory as individual JSON files, queryable by `task_id` or `parent_id`.
- The orchestrator (parent process) routes messages, enforces workflow gates (no QA before review), and triggers context file updates.
- Agent prompts include their role constraints verbatim from Section 3 to prevent role drift.
- ReviewerAgent's system prompt explicitly states: "You are not evaluated on team velocity. Your sole metric is code quality accuracy."
