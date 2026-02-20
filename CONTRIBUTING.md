# Contributing

## Before opening a PR
- Search existing issues/PRs first.
- Open or link an issue for non-trivial changes.
- Keep changes focused; avoid mixing unrelated work.

## Branch and commit conventions
- Branches: use clear topic names (example: `codex/<short-topic>`).
- Commits: conventional format `type(scope): subject`.

## Development expectations
- Include exact verification commands in PRs.
- For script changes, run at minimum:

```bash
while IFS= read -r script; do [[ -f "$script" ]] || continue; bash -n "$script"; done < <(git ls-files scripts)
while IFS= read -r script; do [[ -f "$script" ]] || continue; shellcheck "$script"; done < <(git ls-files scripts)
./scripts/smoke-wrappers.sh
```

- Run preflight checks when working with wrappers:

```bash
./scripts/doctor
```

## PR requirements
- Use the PR template sections completely.
- Include: What, Why, Scope, Validation, Risk/Rollback, AI Assistance.
- If behavior changes, update relevant docs in `README.md` and `references/`.
