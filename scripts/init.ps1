# ─────────────────────────────────────────────────────────────────────────────
# Claude Code ADO Setup Script
# Generates CLAUDE.md from CLAUDE.template.md for your ADO project.
#
# Usage:
#   .\scripts\init.ps1
#
#   If blocked by execution policy, run:
#   PowerShell -ExecutionPolicy Bypass -File .\scripts\init.ps1
#
# Run from the repo root. Requires no dependencies — pure PowerShell.
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = 'Stop'
$RepoRoot   = Split-Path -Parent $PSScriptRoot
$Template   = Join-Path $RepoRoot 'CLAUDE.template.md'
$Output     = Join-Path $RepoRoot 'CLAUDE.md'
$ConfigFile = Join-Path $RepoRoot '.claude\project-config.json'

# ── Helpers ──────────────────────────────────────────────────────────────────

function Prompt-Required {
    param([string]$Label, [string]$Default = '')
    $hint = if ($Default) { " [$Default]" } else { '' }
    do {
        $val = Read-Host "$Label$hint"
        if (-not $val -and $Default) { $val = $Default }
    } while (-not $val)
    return $val.Trim()
}

function Prompt-Optional {
    param([string]$Label, [string]$Default = '')
    $hint = if ($Default) { " [$Default]" } else { ' (leave blank to skip)' }
    $val = Read-Host "$Label$hint"
    if (-not $val -and $Default) { $val = $Default }
    return $val.Trim()
}

function Prompt-YesNo {
    param([string]$Label)
    do { $val = (Read-Host "$Label [Y/N]").ToUpper() } while ($val -notin @('Y','N'))
    return $val -eq 'Y'
}

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
Write-Host '║        Claude Code ADO — Project Setup                      ║' -ForegroundColor Cyan
Write-Host '║  Generates CLAUDE.md from CLAUDE.template.md                ║' -ForegroundColor Cyan
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
Write-Host ''

# ── Load existing config if present ──────────────────────────────────────────

$existing = $null
if (Test-Path $ConfigFile) {
    $existing = Get-Content $ConfigFile | ConvertFrom-Json
    Write-Host "Found existing config at .claude\project-config.json" -ForegroundColor Yellow
    $reuse = Prompt-YesNo 'Use saved values as defaults?'
    if (-not $reuse) { $existing = $null }
    Write-Host ''
}

# ── Collect inputs ────────────────────────────────────────────────────────────

Write-Host '── Step 1: Azure DevOps organisation ───────────────────────────' -ForegroundColor DarkCyan
$adoOrg = Prompt-Required 'ADO organisation name (e.g. contoso)' ($existing?.adoOrg)
$adoOrgUrl = "https://dev.azure.com/$adoOrg"

Write-Host ''
Write-Host '── Step 2: Primary project ─────────────────────────────────────' -ForegroundColor DarkCyan
$p1Name = Prompt-Required 'Project name (e.g. IRIS)'         ($existing?.projects[0]?.name)
$p1Team = Prompt-Required 'Team name (e.g. IRIS Team)'       ($existing?.projects[0]?.team)
$p1Repo = Prompt-Required 'Repo name (e.g. Iris)'            ($existing?.projects[0]?.repo)

Write-Host ''
Write-Host '── Step 3: Second project (optional) ───────────────────────────' -ForegroundColor DarkCyan
$hasP2 = Prompt-YesNo 'Add a second ADO project?'
$p2Name = ''; $p2Team = ''; $p2Repo = ''
if ($hasP2) {
    $p2Name = Prompt-Required 'Second project name' ($existing?.projects[1]?.name)
    $p2Team = Prompt-Required 'Second team name'    ($existing?.projects[1]?.team)
    $p2Repo = Prompt-Required 'Second repo name'    ($existing?.projects[1]?.repo)
}

Write-Host ''
Write-Host '── Step 4: App details ─────────────────────────────────────────' -ForegroundColor DarkCyan
$appName    = Prompt-Required 'Application / product name (e.g. IRIS)' ($existing?.appName ?? $p1Name)
$techStack  = Prompt-Required 'Tech stack (e.g. React frontend, Node.js backend)' ($existing?.techStack ?? 'React frontend, Node.js backend')
$mainBranch = Prompt-Required 'Main branch name' ($existing?.mainBranch ?? 'main')

# ── Build replacement values ──────────────────────────────────────────────────

$p2RemoteRow   = if ($hasP2) { "| $p2Name | $p2Repo | `https://$adoOrg@dev.azure.com/$adoOrg/$p2Name/_git/$p2Repo` |" } else { '' }
$p2SupportedRow = if ($hasP2) { "| ``$p2Name`` | ``$p2Team`` |" } else { '' }
$p2TeamSection  = if ($hasP2) {
    @"

### $p2Name

<!-- Replace the table below with your actual team members -->
| Sub-team | Role | Name |
|----------|------|------|
| Leadership | Scrum Master | |
| Leadership | Product Owner | |
| Backend | Lead | |
| Frontend | Lead | |
| QA | Lead | |
"@
} else { '' }

$p2BranchingSection = if ($hasP2) {
    @"

### $p2Name

| Branch type | Naming convention | Merge target | Who can create |
|-------------|------------------|--------------|----------------|
| Feature / User Story / Enhancement | ``feature/[id]-[short-title]`` | ``$mainBranch`` | Any developer |
| Bug fix | ``bugfix/[id]-[short-title]`` | ``$mainBranch`` | Any developer |
| Hotfix (production incident) | ``hotfix/[id]-[short-title]`` | ``$mainBranch`` | Lead only |
| Release | ``[TO BE CONFIRMED]`` | — | — |

Default merge strategy: ``[TO BE CONFIRMED]``
Branch protection on ``$mainBranch``: ``[TO BE CONFIRMED]``
"@
} else { '' }

$p2CodebaseSection = if ($hasP2) {
    @"

### $p2Name

| Layer | Root folder | Notes |
|-------|-------------|-------|
| Frontend | ``[TO BE CONFIRMED]`` | React app root |
| Backend | ``[TO BE CONFIRMED]`` | Node.js/Express root |
| Tests | ``[TO BE CONFIRMED]`` | Jest test root |
| Config / env | ``[TO BE CONFIRMED]`` | .env files, config |
| Shared types | ``[TO BE CONFIRMED]`` | TypeScript interfaces |

- Component library: ``[TO BE CONFIRMED]``
- State management: ``[TO BE CONFIRMED]``
- API pattern: ``[TO BE CONFIRMED]``
- DB / ORM: ``[TO BE CONFIRMED]``
- Auth pattern: ``[TO BE CONFIRMED]``
"@
} else { '' }

# ── Read template and replace placeholders ────────────────────────────────────

Write-Host ''
Write-Host 'Generating CLAUDE.md ...' -ForegroundColor DarkCyan

$content = Get-Content $Template -Raw -Encoding UTF8

$content = $content -replace '\{\{APP_NAME\}\}',            $appName
$content = $content -replace '\{\{TECH_STACK\}\}',          $techStack
$content = $content -replace '\{\{ADO_ORG\}\}',             $adoOrg
$content = $content -replace '\{\{ADO_ORG_URL\}\}',         $adoOrgUrl
$content = $content -replace '\{\{PROJECT_1_NAME\}\}',      $p1Name
$content = $content -replace '\{\{PROJECT_1_TEAM\}\}',      $p1Team
$content = $content -replace '\{\{PROJECT_1_REPO\}\}',      $p1Repo
$content = $content -replace '\{\{PROJECT_2_REMOTE_ROW\}\}',$p2RemoteRow
$content = $content -replace '\{\{PROJECT_2_SUPPORTED_ROW\}\}',$p2SupportedRow
$content = $content -replace '\{\{PROJECT_2_TEAM_SECTION\}\}',$p2TeamSection
$content = $content -replace '\{\{PROJECT_2_BRANCHING_SECTION\}\}',$p2BranchingSection
$content = $content -replace '\{\{PROJECT_2_CODEBASE_SECTION\}\}',$p2CodebaseSection
$content = $content -replace '\{\{MAIN_BRANCH\}\}',         $mainBranch

# Replace the "DO NOT EDIT" warning with a generated-by header
$content = $content -replace '# ⚠️  DO NOT EDIT THIS FILE DIRECTLY\..*?# ─+\r?\n', ''

$content | Set-Content $Output -Encoding UTF8
Write-Host "  ✔  CLAUDE.md written" -ForegroundColor Green

# ── Save config ───────────────────────────────────────────────────────────────

$config = [ordered]@{
    adoOrg     = $adoOrg
    appName    = $appName
    techStack  = $techStack
    mainBranch = $mainBranch
    projects   = @(
        [ordered]@{ name = $p1Name; team = $p1Team; repo = $p1Repo }
    )
}
if ($hasP2) {
    $config.projects += [ordered]@{ name = $p2Name; team = $p2Team; repo = $p2Repo }
}

$configDir = Split-Path $ConfigFile
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir | Out-Null }
$config | ConvertTo-Json -Depth 4 | Set-Content $ConfigFile -Encoding UTF8
Write-Host "  ✔  Config saved to .claude\project-config.json" -ForegroundColor Green

# ── Set git remote ────────────────────────────────────────────────────────────

$adoRemote = "https://$adoOrg@dev.azure.com/$adoOrg/$p1Name/_git/$p1Repo"
$setRemote = Prompt-YesNo "Set git remote 'origin' to $adoRemote ?"
if ($setRemote) {
    git -C $RepoRoot remote set-url origin $adoRemote 2>&1 | Out-Null
    Write-Host "  ✔  git remote origin → $adoRemote" -ForegroundColor Green
}

# ── Final instructions ────────────────────────────────────────────────────────

Write-Host ''
Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Green
Write-Host '║  Setup complete!                                             ║' -ForegroundColor Green
Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Green
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor White
Write-Host ''
Write-Host '  1. Fill in your team members in CLAUDE.md (Team structure section)' -ForegroundColor White
Write-Host ''
Write-Host '     Also complete these two placeholder sections in CLAUDE.md:' -ForegroundColor White
Write-Host '       - Branching strategy  (describe your rules, say "update CLAUDE.md branching strategy")' -ForegroundColor Gray
Write-Host '       - Codebase structure  (share folder tree, say "update CLAUDE.md codebase structure")' -ForegroundColor Gray
Write-Host ''
Write-Host '  2. Register the ADO MCP server with Claude Code CLI (run once):' -ForegroundColor White
Write-Host "       claude mcp add azure-devops -- npx -y @azure-devops/mcp $adoOrg" -ForegroundColor Yellow
Write-Host ''
Write-Host '  3. Open VS Code in this repo — the MCP server loads automatically.' -ForegroundColor White
Write-Host ''
Write-Host '  4. Push to your ADO repo:' -ForegroundColor White
Write-Host "       git push -u origin $mainBranch" -ForegroundColor Yellow
Write-Host ''
Write-Host '  5. Start using slash commands:' -ForegroundColor White
Write-Host "       /sprint --project ""$p1Name"" --team ""$p1Team""" -ForegroundColor Yellow
Write-Host "       /implement 1234 --project ""$p1Name"" --team ""$p1Team""" -ForegroundColor Yellow
Write-Host ''
