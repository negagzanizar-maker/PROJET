[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$requirementFiles = @(
    'docs/01-requirements/REQUIREMENTS.md',
    'docs/01-requirements/SECURITY_REQUIREMENTS.md'
)

$requirementIds = foreach ($relativeFile in $requirementFiles) {
    $fullPath = Join-Path $repositoryRoot $relativeFile
    foreach ($line in Get-Content -LiteralPath $fullPath) {
        if ($line -match '^\|\s*([A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d{3})\s*\|') {
            $Matches[1]
        }
    }
}

$duplicates = @($requirementIds | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) {
    throw "Duplicate requirement IDs: $($duplicates.Name -join ', ')"
}

$traceabilityPath = Join-Path $repositoryRoot 'docs/01-requirements/TRACEABILITY.csv'
$traceabilityIds = @(Import-Csv -LiteralPath $traceabilityPath | ForEach-Object requirement_id)
$missing = @($requirementIds | Where-Object { $_ -notin $traceabilityIds })
$extra = @($traceabilityIds | Where-Object { $_ -notin $requirementIds })

if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
    throw "Traceability mismatch. Missing: $($missing -join ', '); extra: $($extra -join ', ')"
}

$brokenLinks = @()
$markdownFiles = Get-ChildItem -LiteralPath $repositoryRoot -Recurse -Filter '*.md' -File |
    Where-Object { $_.FullName -notmatch '[\\/](node_modules|artifacts|bin|obj|\.data|\.git)[\\/]' }

foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($match in [regex]::Matches($content, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value.Trim('<', '>')
        if ($target -match '^(https?://|mailto:|#)') {
            continue
        }

        $relativeTarget = ($target -split '#')[0]
        if ([string]::IsNullOrWhiteSpace($relativeTarget)) {
            continue
        }

        $resolved = [System.IO.Path]::GetFullPath((Join-Path $file.DirectoryName $relativeTarget))
        if (-not (Test-Path -LiteralPath $resolved)) {
            $brokenLinks += "$($file.FullName): $target"
        }
    }
}

if ($brokenLinks.Count -gt 0) {
    throw "Broken local Markdown links:`n$($brokenLinks -join "`n")"
}

Write-Output "Documentation verification passed: $($markdownFiles.Count) Markdown files, $($requirementIds.Count) unique requirements, exact traceability coverage, zero broken local links."
