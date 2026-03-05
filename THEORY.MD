# Theory: Coding-Agent as a Reliability Contract for Autonomous Engineering

## Mission

This skill is not a thin command wrapper. It is a safety and reliability layer
that turns LLM-driven coding into a repeatable engineering workflow:

1. generate a concrete plan,
2. require explicit approval,
3. execute through constrained wrappers,
4. verify with machine-checkable tests,
5. produce reviewer-ready artifacts (PRs, issue links, evidence).

The problem we are solving is not "how to run Codex/ACPX once." The real
problem is preventing drift, ambiguity, and hidden failure states in
multi-step autonomous development loops.

## System Problem

Raw LLM orchestration fails in predictable ways:

- command-shape drift across hosts/versions,
- stale or conflicting session state,
- mixed interactive vs non-interactive assumptions,
- policy bypass through ad-hoc commands,
- weak observability of long-running loops,
- docs/examples drifting ahead of executable guardrails.

Each of these causes "it worked yesterday" failures that are expensive to
debug and easy to reintroduce.

## Core Operating Theory

Reliability comes from contract boundaries, not from prompt quality alone.

The coding-agent skill should enforce three boundary types:

1. **Intent boundary**  
   Non-trivial changes must pass through plan + explicit approval before
   mutation.

2. **Execution boundary**  
   Tool invocation must flow through sanctioned wrappers with canonicalized
   flags, deterministic defaults, and hard rejection of non-canonical usage.

3. **Verification boundary**  
   Every critical behavior must be represented in smoke/regression checks, and
   docs must be linted against the same operational policy.

If any boundary is optional, operational entropy returns quickly.

## Architectural Principles

1. **One sanctioned path per risky action**
   Example: direct ACPX should have a single wrapper entrypoint, not free-form
   raw command snippets.

2. **Fail closed with actionable errors**
   Reject invalid state early with explicit remediation text. Silent fallthrough
   is worse than hard failure.

3. **Behavior before prose**
   Docs should describe guardrailed commands that are already enforced in code.
   Avoid "policy by documentation only."

4. **Portability of enforcement**
   Test harnesses should run even in constrained environments (fallbacks when
   optional tools like `rg` are absent).

5. **Operator trust via observability**
   Long runs must emit consistent lifecycle events and state transitions so
   humans can distinguish progress, stall, and interruption.

## Strategic Shape of the Skill

The skill evolves around four control planes:

1. **Plan + review orchestration**  
   Plan artifacts, live review checkpoints, readiness metadata, and review-loop
   supervision.

2. **Execution wrappers**  
   `safe-fallback`, `safe-review`, `code-implement`, and direct ACPX wrappers
   that normalize runtime behavior.

3. **Policy/docs alignment**  
   AGENTS/README/references encode policy, while smoke tests enforce policy so
   docs cannot silently regress.

4. **Upstream boundary management**  
   Distinguish what this repo owns (wrapper behavior, docs, tests) from what
   OpenClaw/ACPX upstream owns (runtime lifecycle semantics, backend bugs).

## What "Done" Means for This Skill

A fix is complete only when all of the following are true:

- the behavior is enforced in wrapper code,
- there is regression coverage in `scripts/smoke-wrappers.sh`,
- user-facing docs/reference paths are aligned to sanctioned commands,
- PR evidence shows reproducible verification,
- ownership boundaries are explicit for any upstream dependency.

This definition prevents shallow fixes that solve one incident but not the
class of incident.

## Current Direction

Near-term work remains focused on closing reliability gaps discovered in live
session evidence:

- prevent direct-path ACPX policy bypasses (#53),
- harden plan-review-live resume/non-interactive semantics (#49),
- normalize non-default agent cron/session payload semantics (#52),
- strengthen review-loop supervisor convergence and diagnostics (#50).

These are not isolated bugs; they are parts of one strategy: make autonomous
coding runs deterministic, inspectable, and reviewer-trustworthy by default.
