<#
.SYNOPSIS
    Sync Scoop bucket manifests with upstream releases.
    For each manifest with checkver:github, check latest release via GitHub API,
    and update version/url/hash if a new release exists.
#>

param(
    [string]$BucketDir,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $BucketDir) {
    $BucketDir = Join-Path $PSScriptRoot '..\bucket'
}

$token = $env:GITHUB_TOKEN
if (-not $token) {
    Write-Warning "GITHUB_TOKEN not set. Unauthenticated requests have lower rate limits (60/hr)."
}

$headers = @{}
if ($token) {
    $headers['Authorization'] = "token $token"
    $headers['Accept'] = 'application/vnd.github+json'
}

function Get-LatestRelease($owner, $repo) {
    $url = "https://api.github.com/repos/$owner/$repo/releases/latest"
    $response = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction SilentlyContinue
    if (-not $response) {
        Write-Warning "  No release found for $owner/$repo"
        return $null
    }
    return $response
}

function Get-AssetHash($url) {
    Write-Host "    Downloading and hashing: $url" -ForegroundColor DarkGray
    $tmpFile = Join-Path $env:TEMP ("asset-" + [Guid]::NewGuid().ToString())
    try {
        Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing -ErrorAction SilentlyContinue
        $hash = (Get-FileHash -Path $tmpFile -Algorithm SHA256).Hash.ToLower()
        return $hash
    } finally {
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
    }
}

Write-Host "`n=== Scoop Bucket Sync ===" -ForegroundColor Cyan
if ($DryRun) { Write-Host "(DRY RUN - no files will be modified)" -ForegroundColor Yellow }

$manifests = Get-ChildItem -Path $BucketDir -Filter '*.json' -File
$updated = @()

foreach ($m in $manifests) {
    $slug = $m.BaseName
    $manifest = Get-Content $m.FullName -Raw | ConvertFrom-Json

    if ($manifest.checkver -ne 'github' -or -not $manifest.autoupdate) {
        Write-Host "[$slug] Skipped (no checkver:github)" -ForegroundColor DarkGray
        continue
    }

    $githubRepo = $manifest.autoupdate.github
    if (-not $githubRepo) {
        Write-Host "[$slug] Skipped (no autoupdate.github)" -ForegroundColor DarkGray
        continue
    }

    $parts = $githubRepo -split '/'
    if ($parts.Count -ne 2) {
        Write-Host "[$slug] Invalid autoupdate.github format: $githubRepo" -ForegroundColor Red
        continue
    }
    $owner = $parts[0]
    $repo = $parts[1]

    Write-Host "[$slug] Checking $owner/$repo..." -ForegroundColor Yellow

    $release = Get-LatestRelease $owner $repo
    if (-not $release) { continue }

    $newVersion = $release.tag_name.TrimStart('v')
    $currentVersion = $manifest.version

    if ($newVersion -eq $currentVersion) {
        Write-Host "  Up to date: $currentVersion" -ForegroundColor Green
        continue
    }

    Write-Host "  New version: $currentVersion -> $newVersion" -ForegroundColor Cyan

    # Update each architecture block
    $archs = @{}
    if ($manifest.architecture) {
        foreach ($arch in ($manifest.architecture.PSObject.Properties.Name)) {
            $archs[$arch] = $manifest.architecture.$arch
        }
    } else {
        # Try top-level url/hash
        if ($manifest.url) {
            $archs['64bit'] = @{ url = $manifest.url; hash = $manifest.hash }
        }
    }

    $updatedManifest = $manifest.PSObject.Copy()
    $updatedManifest.version = $newVersion

    foreach ($arch in $archs.Keys) {
        $oldUrl = $archs[$arch].url
        # Replace old version in URL with new version
        $newUrl = $oldUrl -replace [regex]::Escape($currentVersion), [regex]::Escape($newVersion)
        $newUrl = $newUrl -replace [regex]::Escape("v$currentVersion"), [regex]::Escape("v$newVersion")

        Write-Host "  [$arch] URL: $newUrl" -ForegroundColor DarkGray

        if ($DryRun) {
            $updatedManifest.architecture.$arch.url = $newUrl
            $updatedManifest.architecture.$arch.hash = "<would-compute-hash>"
        } else {
            $newHash = Get-AssetHash $newUrl
            if (-not $newHash) {
                Write-Host "  [$arch] Failed to download asset, skipping" -ForegroundColor Red
                continue
            }
            Write-Host "  [$arch] hash: $newHash" -ForegroundColor DarkGray
            $updatedManifest.architecture.$arch.url = $newUrl
            $updatedManifest.architecture.$arch.hash = "sha256:$newHash"
        }
    }

    if (-not $DryRun) {
        $updatedManifest | ConvertTo-Json -Depth 10 | Set-Content $m.FullName -Encoding UTF8
        $updated += $slug
        Write-Host "  Updated: $m.Name" -ForegroundColor Green
    } else {
        $updated += "$slug (dry-run)"
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
if ($updated.Count -gt 0) {
    Write-Host "Updated manifests: $($updated -join ', ')" -ForegroundColor Green
    if (-not $DryRun) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add -A
        git commit -m "chore: auto-update $($updated -join ', ') @ $timestamp"
        git push
        Write-Host "Changes committed and pushed." -ForegroundColor Green
    }
} else {
    Write-Host "No updates found." -ForegroundColor Green
}
