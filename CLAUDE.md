# Chembience Core

All project guidance lives in AGENTS.md (shared with other agents); edit it
there, not here.

@AGENTS.md

## Claude Code specifics

- `.claude/settings.json` pre-approves validation commands (`./test`,
  `tests/compare-prepare-prod.sh`, `bash -n`, `shellcheck`, `helm lint`/`template`,
  `docker compose config`, read-only `git`) and denies destructive ones
  (`./remove ... --force-prod`, `docker volume rm`, `docker compose down -v`).
  Put personal overrides in `.claude/settings.local.json` (ignored by Git).
- A PostToolUse hook (`.claude/hooks/lint-shell.sh`) runs `bash -n` and, when
  installed, ShellCheck on every shell script you edit; fix what it reports.
- Run `./test --integration` with the Bash tool's background mode; it builds all
  images.
