param(
    [string]$RepoName = "royaldash-ios",
    [switch]$Private
)

$ErrorActionPreference = "Stop"

$Gh = "C:\Program Files\GitHub CLI\gh.exe"
if (-not (Test-Path $Gh)) {
    throw "GitHub CLI not found at $Gh. Install it with: winget install --id GitHub.cli -e"
}

& $Gh auth status | Out-Null

$login = (& $Gh api user --jq ".login").Trim()
$id = (& $Gh api user --jq ".id").Trim()
if ([string]::IsNullOrWhiteSpace($login) -or [string]::IsNullOrWhiteSpace($id)) {
    throw "Could not read GitHub account data from gh."
}

git config user.name $login
git config user.email "$id+$login@users.noreply.github.com"

git add .github .gitignore Package.swift README.md Sources Tests docs scripts

$hasCommit = $true
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $hasCommit = $false
}

$staged = git diff --cached --name-only
if (-not [string]::IsNullOrWhiteSpace($staged)) {
    git commit -m "Initialize RoyalDash iOS core"
} elseif (-not $hasCommit) {
    throw "No staged files and no existing commit. Nothing to publish."
}

$visibility = if ($Private) { "--private" } else { "--public" }

$repoExists = $true
& $Gh repo view "$login/$RepoName" 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $repoExists = $false
}

if (-not $repoExists) {
    & $Gh repo create "$RepoName" $visibility --source "." --remote "origin" --push
} else {
    git remote remove origin 2>$null
    git remote add origin "https://github.com/$login/$RepoName.git"
    git branch -M main
    git push -u origin main
}

Write-Host "Published https://github.com/$login/$RepoName"
