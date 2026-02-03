# Violation Examples and Recovery

## Violation Consequences

If any rule is violated:
1. Stop immediately.
2. Acknowledge the violation.
3. Revert or fix.
4. Document the violation in PR/commit notes.
5. Resume correctly.

## Common Pitfalls

### ❌ Writing code directly
Wrong:
```bash
Edit file.py: add function xyz...
```
Correct:
```bash
codex --yolo exec "Add function xyz to file.py"
```

### ❌ Skipping review
Wrong:
```bash
git push && gh pr create && gh pr merge
```
Correct:
```bash
gh pr create
codex review --base main
mcporter call codex.codex 'prompt="Review against STANDARDS.md"' 'sandbox=read-only'
```

### ❌ Using terminal for complex work
Wrong:
```bash
codex exec "Part 1" && codex exec "Part 2"
```
Correct:
```bash
mcporter call codex.codex 'prompt="Part 1"' 'sandbox=workspace-write'
mcporter call codex.codex-reply 'threadId="..."' 'prompt="Part 2"'
```

## Real Violation Examples

### Example 1: “Trivial Change” Rationalization
- What happened: Direct edit for a typo.
- Why wrong: Rule 1 has no exceptions.
- Fix:
```bash
codex --yolo exec "Fix typo in config.py line 42"
```

### Example 2: Skipped PR Creation
- What happened: Commit on main, pushed directly.
- Why wrong: Rule 2 and Rule 3.
- Fix:
```bash
git checkout -b fix/typo-config
git add -A && git commit -m "fix: correct typo"
git push -u origin fix/typo-config
gh pr create
```

### Example 3: Missing Self-Check
- What happened: Implementation started without STOP-AND-VERIFY.
- Why wrong: Mandatory protocol.
- Fix: perform STOP-AND-VERIFY before any changes.
