# Theory: Bounded ACP Mitigation with Canonical-Clone Enforcement

## Problem

Two separate issues were creating operational risk in this repository.

First, issue #43 exposed upstream ACP/OpenClaw runtime limitations around
spawned-run observability and relay profile aliasing. Users needed immediate,
repo-side guidance without pretending the upstream runtime behavior was fixed.

Second, local workflow drift occurred because multiple independent clones of
the same GitHub repo were used (`/home/art/projects/coding-agent-openclaw-skill`
and `/home/art/projects/skills/shared/coding-agent`). That divergence caused
work to land in different clones and made PR state hard to reason about.

## Operating Theory

The right immediate fix is a bounded mitigation layer plus strict local topology
control.

For issue #43, this repo should provide deterministic operator guidance:
- explicit symptom signatures,
- deterministic preflight warnings,
- bounded triage steps,
- known-safe fallback commands.

For divergence, the fix is not “better habits.” It must be enforced in runtime
entrypoints. If wrappers fail fast outside a canonical local clone, accidental
work in shadow clones becomes hard to do by default.

## Strategy

1. Keep issue #43 scope honest and narrow: docs + doctor warnings + smoke
   assertions only. No runtime probing and no claim of upstream fix.
2. Make `/home/art/projects/skills/shared/coding-agent` the canonical local
   clone and encode this directly in wrapper guardrails.
3. Provide an explicit emergency escape hatch (`CODING_AGENT_ALLOW_NONCANONICAL=1`)
   so recovery is possible without weakening default enforcement.
4. Retire deprecated local path by replacing it with a symlink to canonical,
   preserving backward path compatibility while removing independent git state.
5. Mirror only policy-level canonical-path guidance in home-level AGENTS/CLAUDE
   docs and keep implementation detail in repo-local docs.

## Key Discoveries

The previous failing CI signal was shellcheck, not functional wrapper behavior.
Fixing those warnings inside this PR is necessary to avoid repeating prior CI
failures even when feature logic is correct.

The old clone had no unique commits not already represented upstream for the
relevant changes, so path retirement can be done safely with pre-checks and a
symlink transition.

## Open Questions

- Whether canonical-path enforcement should eventually validate remote URL and
  default branch too, not only absolute filesystem root.
- Whether a dedicated doctor subcommand should explicitly print canonical-path
  status and remediation steps for onboarding.
