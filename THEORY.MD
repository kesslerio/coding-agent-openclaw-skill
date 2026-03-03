# Theory: Opt-In Verbose Progress for Coding-Agent

## Problem

The skill currently has no explicit verbosity control, so users who want richer
execution telemetry get inconsistent behavior. At the same time, this is a
public/shared skill, so making all responses verbose by default would degrade
the default experience for users who prefer concise output.

## Operating Theory

The right lever is an opt-in runtime switch, not another command alias. This
skill already relies on environment-based behavior controls
(`CODING_AGENT_IMPL_MODE`, `CODING_AGENT_CLAUDE_BIN`), and OpenClaw deploys
through a systemd environment file. That makes environment configuration a
stable, low-friction integration path that does not require command memorization
or channel-specific command wiring.

The value target is execution visibility, not longer prose everywhere. The
highest impact behavior is to make progress reporting explicit (`Now`, `Why`,
`Next`) during active execution while preserving concise defaults.

## Strategy

Define a single environment contract: `CODING_AGENT_VERBOSE`, default off.
Document accepted truthy/falsy values so behavior is predictable and testable.
Apply the mode to execution-progress updates only. Keep core guardrails and
approval semantics unchanged to avoid coupling verbosity with workflow control.

Expose the mode in three places:

1. Skill behavior contract (`skills/coding-agent/SKILL.md`)
2. Operator docs (`README.md`, `references/tooling.md`, `AGENTS.md`)
3. Runtime diagnostics (`scripts/doctor`)

Then mirror the same changes into the local installed skill path so live agent
behavior matches the upstream repo state.

## Key Discoveries

The existing skill pack already has a clear environment-variable pattern and a
doctor script that reports effective defaults. This avoids adding new command
surface area and keeps rollout simple.

## Open Questions

Whether to add slash-command toggles later (`/verbose on|off`) remains optional.
Current approach intentionally avoids that to keep configuration centralized and
portable across channels.
