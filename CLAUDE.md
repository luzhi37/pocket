# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal Scoop bucket repository. Package manifests live in `bucket/`, one JSON file per app slug (e.g. `bucket/kimi-code.json`).

## Directory layout

```
bucket/                  # Scoop bucket root — manifests go here
├── kimi-code.json
└── kilocode.json
scripts/                 # Tooling
├── template.json        # Scaffold for new manifests
└── sync.ps1             # Sync upstream versions
.gitignore               # Ignores bucket/ index cache
```

## Manifest conventions

- Each manifest is a single JSON file named after the app slug (e.g. `bucket/kimi-code.json`).
- Key fields: `version`, `description`, `homepage`, `license`, `url`, `hash`, `extract_dir` (when needed), `shortcuts`, `env_set`, `persist`, `post_install`/`pre_uninstall`/`checkver`/`autoupdate` scripts.
- `architecture` blocks (`64bit` / `arm64`) are preferred when the download URL differs by arch.
- Use `scoop-validate` or `scoop test <slug>` to check a manifest before committing.
- `bucket/` is gitignored because Scoop caches index files there; only commit manifest JSONs.

## Validation

```powershell
scoop test <slug>     # validate + simulate install
scoop checkver <slug> # verify upstream version
```

## Adding a new package

1. Copy `scripts/template.json` to `bucket/<slug>.json`.
2. Fill in version, URL, and SHA256 hash.
3. Run `scoop test` and fix any errors.
4. Commit the manifest.

## Updating a package

- `scoop update <slug>` (when bucket is registered locally).
- Alternatively: bump `version` + `url` + `hash`, then run validation.

## Registering the bucket locally

```powershell
scoop bucket add personal D:\Code\Web\pocket\bucket
```

## Useful links

- Scoop docs: https://github.com/ScoopInstaller/Scoop/wiki
- Manifest schema reference: https://github.com/ScoopInstaller/Scoop/wiki/Manifest
