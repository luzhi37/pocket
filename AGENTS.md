# AGENTS.md

Personal Scoop bucket. Source manifests live in `bucket/<slug>.json` and **are committed to git** (CLAUDE.md's claim that `bucket/` is gitignored is wrong for this repo). One JSON per app slug.

## Layout & tools

- `bucket/` — source manifests (committed).
- `bin/sync.ps1` — the real updater (also runs daily via `.github/workflows/sync.yml`). `template.json` scaffolds new manifests.
- `.github/workflows/sync.yml` — daily UTC 18:00; installs Scoop on `windows-latest`, runs `sync.ps1` with `GITHUB_TOKEN`.
- `.github/workflows/validate.yml` — on push/PR to `main` or `chore/readme-sync`; validates JSON syntax and required fields in `bucket/*.json`.

## Autoupdate mechanism

Each manifest carries `autoupdate.github` (`"owner/repo"`) plus `checkver` in one of two formats:

- `"checkver": "github"` → uses GitHub `/releases/latest`, version = tag stripped of leading `v`.
- `"checkver": {"url": ..., "re": ...}` → regex-match against the releases list; use when the latest release isn't the CLI asset (e.g. kilocode's desktop vs CLI releases).

`sync.ps1` substitutes the version in URLs in both `v<ver>` and `@pkg@<ver>` forms (kimi-code uses the latter, no `v`), recomputes hashes, and writes `sha256:<lowercase hex>`. Safe local test: `.\bin\sync.ps1 -DryRun`. Without `GITHUB_TOKEN` you're rate-limited to 60 req/hr. It commits (`chore: auto-update ...`) and pushes itself when there are updates.

## Git workflow

See [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md). All manual changes go through the `chore/readme-sync` branch — reset to `origin/main` each cycle, commit, force-push, then PR into `main`.

## Commands & conventions

```powershell
scoop bucket add pocket D:\Code\Web\pocket\bucket
# local sync test
.\bin\sync.ps1 -DryRun
```

- Hash format: `sha256:<lowercase hex>`.
- CLI manifests: no `shortcuts` (removed repo-wide on purpose).
- Keep the package table in README.md (name/description/version) in sync when adding or bumping a package.
- Manifest JSON keys: `architecture` (`64bit`/`arm64`) blocks preferred when arch-specific assets exist.
- Commits use conventional style: `feat:`, `chore:`, `fix:`.
