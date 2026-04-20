#!/usr/bin/env python3
"""
CLI Runner for the Multi-Agent Development Team.

This is the entry point for running the agent system.
Supports both simulation mode (for demo) and live mode (prints prompts for Claude Code).

Examples:
    # Run a simulated feature through the high-priority team
    python .agents/run_team.py sim --team high --feature "Add daily streak counter"

    # Run both teams on a shared feature
    python .agents/run_team.py sim-dual \
        --feature "Implement notification system" \
        --high-scope "Push notification delivery" \
        --medium-scope "Notification preferences UI"

    # View team status
    python .agents/run_team.py status

    # Generate Claude Code agent prompts for live execution
    python .agents/run_team.py generate-prompts --team high --feature "Add streak tracking"

    # View message trail for a task
    python .agents/run_team.py trail --task TASK-001
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from orchestrator import Orchestrator, ContextManager, MessageStore
from schemas.messages import Priority


def cmd_simulate(args):
    """Run a feature through simulated workflow."""
    orch = Orchestrator(args.team, simulate=True)
    orch.run_feature(
        title=args.feature,
        description=args.description or f"Implement: {args.feature}",
        acceptance_criteria=args.criteria or [
            "Feature works as specified",
            "Unit tests pass",
            "No regressions",
        ],
        files_affected=args.files or ["Features/Home/HomeView.swift"],
    )


def cmd_simulate_dual(args):
    """Run a feature across both teams with different scopes."""
    print("\n" + "=" * 70)
    print("  DUAL-TEAM SIMULATION")
    print(f"  Feature: {args.feature}")
    print(f"  High-priority scope: {args.high_scope}")
    print(f"  Medium-priority scope: {args.medium_scope}")
    print("=" * 70)

    # High priority runs first
    high_orch = Orchestrator("high", simulate=True)
    high_orch.run_feature(
        title=args.high_scope,
        description=f"High-priority component of: {args.feature}",
        acceptance_criteria=["Core functionality works", "No crashes", "Tests pass"],
        files_affected=args.high_files or ["Features/Home/HomeView.swift"],
    )

    # Medium priority runs after
    medium_orch = Orchestrator("medium", simulate=True)
    medium_orch.run_feature(
        title=args.medium_scope,
        description=f"Medium-priority component of: {args.feature}",
        acceptance_criteria=["UI matches design", "Settings persist", "Tests pass"],
        files_affected=args.medium_files or ["Features/Settings/SettingsView.swift"],
    )


def cmd_status(args):
    """Show team status."""
    teams = ["high", "medium"] if args.team == "both" else [args.team]
    for t in teams:
        Orchestrator(t).status()


def cmd_trail(args):
    """View message trail for a task."""
    messages = MessageStore.find_by_task(args.task)
    if not messages:
        print(f"No messages found for {args.task}")
        return

    print(f"\n  Message Trail for {args.task} ({len(messages)} messages)")
    print("  " + "─" * 50)
    for i, m in enumerate(messages, 1):
        print(f"\n  [{i}] {m.type.value}")
        print(f"      Time: {m.timestamp}")
        print(f"      From: {m.sender.agent} ({m.sender.team})")
        print(f"      To:   {m.receiver.agent} ({m.receiver.team})")
        if m.type.value == "ReviewFeedback":
            print(f"      Decision: {m.payload.get('decision')}")
            print(f"      Score: {m.payload.get('average')}")
        elif m.type.value == "BugReport":
            print(f"      Severity: {m.payload.get('severity')}")
            print(f"      Bug: {m.payload.get('description')}")
    print()


def cmd_generate_prompts(args):
    """
    Generate ready-to-use Claude Code Agent tool prompts.
    These can be copy-pasted into Claude Code to spawn real subagents.
    """
    runner = Orchestrator(args.team, simulate=True).runner
    ctx = ContextManager.load(args.team)

    team_name = "HighPriorityTeam" if args.team == "high" else "MediumPriorityTeam"

    prompts = {
        "tech_lead": {
            "description": f"{team_name} TechLead — plan {args.feature}",
            "subagent_type": "voltagent-biz:product-manager",
            "prompt": f"""You are the TechLeadAgent for {team_name}.

{runner.get_role_prompt('tech_lead')}

## Current Team Context
{json.dumps(ctx, indent=2)}

## Your Task
Plan and decompose the following feature into implementable subtasks:

Feature: {args.feature}

Produce a JSON TaskAssignment message for each subtask, following the message schema.
Include acceptance criteria, files affected, and dependencies between subtasks.
""",
        },
        "developer": {
            "description": f"{team_name} Developer — implement {args.feature}",
            "subagent_type": "voltagent-core-dev:fullstack-developer",
            "prompt": f"""You are DeveloperAgent-1 for {team_name}.

{runner.get_role_prompt('developer', '1')}

## Current Team Context (check learnings!)
{json.dumps(ctx, indent=2)}

## Your Assignment
Implement the following feature for the Revenge iOS app (SwiftUI, MVVM):

Feature: {args.feature}

Write the Swift code, include unit tests, and submit as a CodeSubmission JSON message.
Follow the project conventions in your role prompt.
""",
        },
        "reviewer": {
            "description": f"{team_name} Reviewer — review submission",
            "subagent_type": "voltagent-qa-sec:code-reviewer",
            "prompt": f"""You are the ReviewerAgent for {team_name}.

{runner.get_role_prompt('reviewer')}

## Current Reviewer Patterns (watch for these)
{json.dumps(ctx.get('reviewer_feedback_summary', []), indent=2)}

## Your Task
Review the code submission that will be provided. Score against ALL 5 rubric dimensions.
Produce a ReviewFeedback JSON message with your decision.

Remember: You are NOT evaluated on delivery speed. Your sole metric is code quality.
""",
        },
        "qa": {
            "description": f"{team_name} QA — test feature",
            "subagent_type": "voltagent-qa-sec:test-automator",
            "prompt": f"""You are the QAAgent for {team_name}.

{runner.get_role_prompt('qa')}

## Your Task
Test the following feature that has passed code review:

Feature: {args.feature}

Design and execute test cases covering:
1. Happy path (acceptance criteria)
2. Edge cases (nil, empty, max values)
3. Error states
4. Regression

Produce either an Approval or BugReport JSON message.
""",
        },
    }

    print(f"\n{'='*60}")
    print(f"  CLAUDE CODE AGENT PROMPTS — {team_name}")
    print(f"  Feature: {args.feature}")
    print(f"{'='*60}")

    for role, config in prompts.items():
        print(f"\n{'─'*60}")
        print(f"  Role: {role.upper()}")
        print(f"  Agent Type: {config['subagent_type']}")
        print(f"{'─'*60}")
        print(f"\n  Description: {config['description']}")
        print(f"\n  Prompt (first 200 chars):")
        print(f"  {config['prompt'][:200]}...")
        print()

    # Save full prompts to file for reference
    output_path = Path(__file__).parent / "generated_prompts.json"
    with open(output_path, "w") as f:
        json.dump(prompts, f, indent=2)
    print(f"\n  Full prompts saved to: {output_path}")


def cmd_reset(args):
    """Reset team context and messages."""
    if args.confirm != "yes":
        print("Add --confirm yes to reset. This clears all messages and context.")
        return

    teams = ["high", "medium"] if args.team == "both" else [args.team]
    for t in teams:
        ctx = {
            "team": t,
            "last_updated": "",
            "completed_work": [],
            "current_work": [],
            "planned_work": [],
            "errors_and_issues": [],
            "learnings": [],
            "reviewer_feedback_summary": [],
        }
        ContextManager.save(t, ctx)
        print(f"  Reset {t} team context")

    # Clear messages
    msg_dir = Path(__file__).parent / "messages"
    for f in msg_dir.glob("*.json"):
        f.unlink()
    print(f"  Cleared all messages")


def main():
    parser = argparse.ArgumentParser(
        description="Multi-Agent Dev Team Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command")

    # Simulate
    sim = subparsers.add_parser("sim", help="Simulate a single-team feature")
    sim.add_argument("--team", choices=["high", "medium"], default="high")
    sim.add_argument("--feature", required=True)
    sim.add_argument("--description", default="")
    sim.add_argument("--criteria", nargs="+")
    sim.add_argument("--files", nargs="+")

    # Dual simulate
    dual = subparsers.add_parser("sim-dual", help="Simulate dual-team feature")
    dual.add_argument("--feature", required=True)
    dual.add_argument("--high-scope", required=True)
    dual.add_argument("--medium-scope", required=True)
    dual.add_argument("--high-files", nargs="+")
    dual.add_argument("--medium-files", nargs="+")

    # Status
    st = subparsers.add_parser("status", help="Show team status")
    st.add_argument("--team", choices=["high", "medium", "both"], default="both")

    # Trail
    tr = subparsers.add_parser("trail", help="View message trail")
    tr.add_argument("--task", required=True)

    # Generate prompts
    gp = subparsers.add_parser("generate-prompts", help="Generate Claude Code agent prompts")
    gp.add_argument("--team", choices=["high", "medium"], required=True)
    gp.add_argument("--feature", required=True)

    # Reset
    rs = subparsers.add_parser("reset", help="Reset team state")
    rs.add_argument("--team", choices=["high", "medium", "both"], default="both")
    rs.add_argument("--confirm", default="no")

    args = parser.parse_args()

    commands = {
        "sim": cmd_simulate,
        "sim-dual": cmd_simulate_dual,
        "status": cmd_status,
        "trail": cmd_trail,
        "generate-prompts": cmd_generate_prompts,
        "reset": cmd_reset,
    }

    if args.command in commands:
        commands[args.command](args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
