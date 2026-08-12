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
        $attempt = 0
        do {
            $attempt++
            try {
                Invoke-WebRequest -Uri $url -OutFile $tmpFile -UseBasicParsing -ErrorAction Stop
                break
            } catch {
                if ($attempt -ge 3) { throw }
                Write-Warning "  Download failed (attempt $attempt/3), retrying: $_"
                Start-Sleep -Seconds 3
            }
        } while ($true)
        $hash = (Get-FileHash -Path $tmpFile -Algorithm SHA256).Hash.ToLower()
        return $hash
    } catch {
        Write-Warning "  Failed to download asset: $_"
        return $null
    } finally {
        if (Test-Path $tmpFile) { Remove-Item $tmpFile -Force }
    }
}

function Update-ReadmeVersion($slug, $newVersion) {
    $readmePath = Join-Path $PSScriptRoot '..\README.md'
    if (-not (Test-Path $readmePath)) {
        Write-Warning "  README.md not found, skipping version sync"
        return
    }
    $raw = [IO.File]::ReadAllText((Resolve-Path $readmePath))
    # Capture group 1 = "| [slug](url) |", group 2 = "description | "
    # The version column follows group 2 and is discarded by the replacement.
    $pattern = '\| \[' + [regex]::Escape($slug) + '\]\([^)]*\) \|'
    $re = [regex]::new("(?m)^($pattern)([^|]+ \| )([^|]+ \|)\r?$")
    $newContent = $re.Replace($raw, { param($m) $m.Groups[1].Value + $m.Groups[2].Value + "${newVersion} |" })
    if ($newContent -ne $raw) {
        [IO.File]::WriteAllText((Resolve-Path $readmePath), $newContent, [Text.UTF8Encoding]::new($false))
        Write-Host "  README.md: updated $slug version to $newVersion" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Scoop Bucket Sync ===" -ForegroundColor Cyan
if ($DryRun) { Write-Host "(DRY RUN - no files will be modified)" -ForegroundColor Yellow }

$manifests = Get-ChildItem -Path $BucketDir -Filter '*.json' -File
$updated = @()

foreach ($m in $manifests) {
    $slug = $m.BaseName
    $manifest = Get-Content $m.FullName -Raw | ConvertFrom-Json

    if (-not $manifest.autoupdate) {
        Write-Host "[$slug] Skipped (no autoupdate)" -ForegroundColor DarkGray
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

    $currentVersion = $manifest.version
    $newVersion = $null

    # Support two checkver formats:
    #   1. "checkver": "github"              → use /releases/latest (simple)
    #   2. "checkver": { "url": "...", "re": "..." } → filter releases list by regex
    $checkver = $manifest.checkver
    if ($checkver -is [string] -and $checkver -eq 'github') {
        # Simple format: fetch latest release
        $release = Get-LatestRelease $owner $repo
        if (-not $release) { continue }
        $newVersion = $release.tag_name.TrimStart('v')
    } elseif ($checkver -is [PSCustomObject] -and $checkver.url -and $checkver.re) {
        # Regex format: fetch releases list and find first match
        Write-Host "  Using regex: $($checkver.re)" -ForegroundColor DarkGray
        try {
            $releases = Invoke-RestMethod -Uri $checkver.url -Headers $headers -ErrorAction Stop
            $re = [regex]::new($checkver.re)
            foreach ($rel in $releases) {
                $match = $re.Match($rel.tag_name)
                if ($match.Success) {
                    $newVersion = $match.Groups[1].Value
                    Write-Host "  Found CLI release: $($rel.tag_name)" -ForegroundColor Cyan
                    break
                }
            }
            if (-not $newVersion) {
                Write-Warning "  No matching release found for regex: $($checkver.re)"
                continue
            }
        } catch {
            Write-Warning "  Failed to fetch releases: $_"
            continue
        }
    } else {
        Write-Host "[$slug] Skipped (unsupported checkver format)" -ForegroundColor DarkGray
        continue
    }

    if ($newVersion -notmatch '^[0-9][0-9A-Za-z.\-+]*$') {
        Write-Warning "  Skipped: version '$newVersion' is not version-shaped"
        continue
    }

    if ($newVersion -eq $currentVersion) {
        Write-Host "  Up to date: $currentVersion" -ForegroundColor Green
        # Keep README in sync even when manifest is already current
        if (-not $DryRun) {
            Update-ReadmeVersion $slug $newVersion
        }
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

    $failedArch = $false
    foreach ($arch in $archs.Keys) {
        $oldUrl = $archs[$arch].url
        # Replace old version in URL with new version (literal replace; both
        # `v<ver>` and `@pkg@<ver>` URL forms contain the bare version)
        $newUrl = $oldUrl.Replace($currentVersion, $newVersion)

        Write-Host "  [$arch] URL: $newUrl" -ForegroundColor DarkGray

        if ($DryRun) {
            $updatedManifest.architecture.$arch.url = $newUrl
            $updatedManifest.architecture.$arch.hash = "<would-compute-hash>"
        } else {
            $newHash = Get-AssetHash $newUrl
            if (-not $newHash) {
                Write-Host "  [$arch] Failed to download asset, skipping" -ForegroundColor Red
                $failedArch = $true
                continue
            }
            Write-Host "  [$arch] hash: $newHash" -ForegroundColor DarkGray
            $updatedManifest.architecture.$arch.url = $newUrl
            $updatedManifest.architecture.$arch.hash = "sha256:$newHash"
        }
    }

    if ($failedArch) {
        Write-Warning "  Skipped writing ${slug}: download failed for one or more architectures"
        continue
    }

    if (-not $DryRun) {
        $updatedManifest | ConvertTo-Json -Depth 10 | Set-Content $m.FullName -Encoding UTF8
        Update-ReadmeVersion $slug $newVersion
        $updated += $slug
        Write-Host "  Updated: $m.Name" -ForegroundColor Green
    } else {
        $updated += "$slug (dry-run)"
        Write-Host "  README.md: would update $slug version to $newVersion" -ForegroundColor DarkGray
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
