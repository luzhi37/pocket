<#
.SYNOPSIS
    Generate Scoop bucket index and validate all manifests.
#>

param(
    [string]$ManifestDir = Join-Path $PSScriptRoot '..',
    [string]$BucketDir   = Join-Path $PSScriptRoot '..\bucket'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "`n=== Scoop Bucket Update ===" -ForegroundColor Cyan

# --- Clean & recreate bucket directory ---
if (Test-Path $BucketDir) {
    Write-Host "Removing old bucket index..." -ForegroundColor DarkGray
    Remove-Item $BucketDir -Recurse -Force
}
New-Item -ItemType Directory -Path $BucketDir -Force | Out-Null

# --- Collect manifests ---
$excludeDirs  = @('bucket', 'scripts')
$excludeFiles = @('manifest.json', 'apps.json', 'package.json')

$manifests = Get-ChildItem -Path $ManifestDir -Filter '*.json' -Recurse -File |
    Where-Object {
        $skip = $false
        foreach ($d in $excludeDirs) {
            if ($_.DirectoryName -like "*\$d") { $skip = $true; break }
        }
        if ($_.Name -in $excludeFiles) { $skip = $true }
        -not $skip
    }

if (-not $manifests) {
    Write-Warning "No manifests found in $ManifestDir"
    exit 0
}

Write-Host "Found $($manifests.Count) manifest(s)`n" -ForegroundColor Green

# --- Index each manifest ---
foreach ($m in $manifests) {
    $slug = $m.BaseName
    Write-Host "[$slug] Indexing..." -ForegroundColor Yellow
    scoop index $m.FullName --bucketdir $BucketDir 2>&1 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor DarkGray
    }
}

# --- Validate ---
Write-Host "`n=== Validation ===" -ForegroundColor Cyan
$validateResult = scoop-validate $ManifestDir --bucketdir $BucketDir 2>&1
$validateResult | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nValidation failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nDone. Index written to: $BucketDir" -ForegroundColor Green
