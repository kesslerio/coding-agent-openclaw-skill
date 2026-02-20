# Contributing

## Before You Start
- Search existing issues and PRs first.
- Use issue forms in `.github/ISSUE_TEMPLATE/` for new reports/requests.
- Keep each PR focused; do not mix unrelated changes.

## Branches and Commits
- Branch names should be short and descriptive (example: `codex/<topic>`).
- Prefer commit format `type(scope): subject`.

## Validation
- Include exact commands and outcomes in your PR.
- For script changes, run:

```bash
while IFS= read -r script; do [[ -f "$script" ]] || continue; bash -n "$script"; done < <(git ls-files scripts)
while IFS= read -r script; do [[ -f "$script" ]] || continue; shellcheck "$script"; done < <(git ls-files scripts)
./scripts/smoke-wrappers.sh
```

- Run preflight checks when working with wrappers:

```bash
./scripts/doctor
```

## Pull Requests
- Complete all sections in `.github/pull_request_template.md`.
- Include: linked issue, What/Why/Scope, validation commands/results, risk/rollback, AI assistance.
- If behavior changes, update docs in `README.md` and `references/`.
