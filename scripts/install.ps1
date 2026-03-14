# install.ps1 -- Install The Agency agents into your local agentic tool(s).
#
# Reads converted files from integrations/ and copies them to the appropriate
# config directory for each tool. Run scripts/convert.ps1 first if integrations/
# is missing or stale.
#
# Usage:
#   .\scripts\install.ps1 [-Tool <name>] [-Interactive] [-NoInteractive] [-Help]

param (
    [string]$Tool = "all",
    [string]$ConfigPath,
    [switch]$Interactive,
    [switch]$NoInteractive,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\scripts\install.ps1 [-Tool <name>] [-Interactive] [-NoInteractive] [-Help]"
    Write-Host ""
    Write-Host "Tools: claude-code, copilot, antigravity, gemini-cli, opencode, openclaw, cursor, aider, windsurf, qwen"
    exit 0
}

$RepoRoot = Resolve-Path "$PSScriptRoot\.."
$Integrations = Join-Path $RepoRoot "integrations"

if (-not (Test-Path $Integrations)) {
    Write-Error "integrations/ not found. Run .\scripts\convert.ps1 first."
    exit 1
}

$AllTools = @("claude-code", "copilot", "antigravity", "gemini-cli", "opencode", "openclaw", "cursor", "aider", "windsurf", "qwen")

# --- Config Handling ---

$Whitelist = @()

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    # Auto-detect config in root
    $DetectJson = Join-Path $RepoRoot "agents-to-install.json"
    $DetectTxt = Join-Path $RepoRoot "agents-to-install.txt"
    if (Test-Path $DetectJson) { $ConfigPath = $DetectJson }
    elseif (Test-Path $DetectTxt) { $ConfigPath = $DetectTxt }
}

if ($ConfigPath -and (Test-Path $ConfigPath)) {
    Write-Host "Using config: $ConfigPath"
    if ($ConfigPath.EndsWith(".json")) {
        $Whitelist = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } else {
        $Whitelist = Get-Content $ConfigPath -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    }
    Write-Host "Limited to $($Whitelist.Count) agents from list."
}

function Should-Install {
    param($AgentName)
    if ($Whitelist.Count -eq 0) { return $true }
    # Flexible match: partial name or full name
    foreach ($W in $Whitelist) {
        if ($AgentName -like "*$W*") { return $true }
    }
    return $false
}

function Get-AgencyRoster {
    $ReadmePath = Join-Path $RepoRoot "README.md"
    if (-not (Test-Path $ReadmePath)) { return "" }
    
    # Force UTF8 reading to avoid encoding issues in PowerShell 5.1
    $Content = Get-Content $ReadmePath -Encoding UTF8
    $Roster = "# Agency Roster (Installed Specialists)`n`n"
    $Roster += "This file lists the agents currently installed in your environment. The Orchestrator uses this to delegate tasks.`n`n"
    $Roster += "| Agent | Specialty | When to Use |`n|-------|-----------|-------------|`n"
    
    # Simple regex to extract rows from tables: | emoji [Name](link) | Specialty | When to Use |
    # We look for lines starting with | and containing []()
    $Rows = $Content | Where-Object { $_ -match "^\|\s*.*\[(.*)\]\((.*)\.md\)\s*\|\s*(.*)\s*\|\s*(.*)\s*\|" }
    
    $FoundCount = 0
    foreach ($Row in $Rows) {
        if ($Row -match "^\|\s*(.*)\[(.*)\]\((.*)\.md\)\s*\|\s*(.*)\s*\|\s*(.*)\s*\|") {
            $Emoji = $Matches[1].Trim()
            $Name = $Matches[2].Trim()
            $Path = $Matches[3].Trim()
            $Specialty = $Matches[4].Trim()
            $WhenToUse = $Matches[5].Trim()
            
            # Use the filename from the path as the agent ID for matching
            $AgentId = [System.IO.Path]::GetFileName($Path)
            
            if (Should-Install $AgentId) {
                $Roster += "| $Emoji $Name | $Specialty | $WhenToUse |`n"
                $FoundCount++
            }
        }
    }
    
    return $Roster
}

# --- Detection ---

function Test-Detected {
    param($T)
    $Home = $env:USERPROFILE
    switch ($T) {
        "claude-code" { return Test-Path (Join-Path $Home ".claude") }
        "copilot"     { return (Get-Command "code" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".github")) -or (Test-Path (Join-Path $Home ".copilot")) }
        "antigravity" { return Test-Path (Join-Path $Home ".gemini\antigravity\skills") }
        "gemini-cli"  { return (Get-Command "gemini" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".gemini")) }
        "cursor"      { return (Get-Command "cursor" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".cursor")) }
        "opencode"    { return (Get-Command "opencode" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".config\opencode")) }
        "aider"        { return [bool](Get-Command "aider" -ErrorAction SilentlyContinue) }
        "openclaw"    { return (Get-Command "openclaw" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".openclaw")) }
        "windsurf"    { return (Get-Command "windsurf" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".codeium")) }
        "qwen"         { return (Get-Command "qwen" -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $Home ".qwen")) }
    }
    return $false
}

# --- Installers ---

function Install-ClaudeCode {
    $Dest = Join-Path $env:USERPROFILE ".claude\agents"
    if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force }
    $Count = 0
    $AgentDirs = @("design", "engineering", "game-development", "marketing", "paid-media", "sales", "product", "project-management", "testing", "support", "spatial-computing", "specialized")
    foreach ($Dir in $AgentDirs) {
        $Path = Join-Path $RepoRoot $Dir
        if (Test-Path $Path) {
            $Files = Get-ChildItem -Path $Path -Filter "*.md" -File
            foreach ($F in $Files) {
                $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($F.Name)
                if ((Should-Install $BaseName) -and (Get-Content $F.FullName -TotalCount 1).StartsWith("---")) {
                    Copy-Item $F.FullName $Dest -Force
                    $Count++
                }
            }
        }
    }
    Write-Host "[OK]  Claude Code: $Count agents -> $Dest"
}

function Install-Copilot {
    $DestGithub = Join-Path $env:USERPROFILE ".github\agents"
    $DestCopilot = Join-Path $env:USERPROFILE ".copilot\agents"
    if (-not (Test-Path $DestGithub)) { New-Item -ItemType Directory -Path $DestGithub -Force }
    if (-not (Test-Path $DestCopilot)) { New-Item -ItemType Directory -Path $DestCopilot -Force }
    $Count = 0
    $AgentDirs = @("design", "engineering", "game-development", "marketing", "paid-media", "sales", "product", "project-management", "testing", "support", "spatial-computing", "specialized")
    foreach ($Dir in $AgentDirs) {
        $Path = Join-Path $RepoRoot $Dir
        if (Test-Path $Path) {
            $Files = Get-ChildItem -Path $Path -Filter "*.md" -File
            foreach ($F in $Files) {
                $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($F.Name)
                if ((Should-Install $BaseName) -and (Get-Content $F.FullName -TotalCount 1).StartsWith("---")) {
                    Copy-Item $F.FullName $DestGithub -Force
                    Copy-Item $F.FullName $DestCopilot -Force
                    $Count++
                }
            }
        }
    }
    Write-Host "[OK]  Copilot: $Count agents -> $DestGithub"
}

function Install-Antigravity {
    $Src = Join-Path $Integrations "antigravity"
    $Dest = Join-Path $env:USERPROFILE ".gemini\antigravity\skills"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/antigravity missing."; return }
    $Dirs = Get-ChildItem -Path $Src -Directory
    $Count = 0
    $RosterContent = ""
    if ($Whitelist.Count -gt 0) {
        Write-Host "Generating AGENCY_ROSTER.md..."
        $RosterContent = Get-AgencyRoster
    }

    foreach ($D in $Dirs) {
        if (Should-Install $D.Name) {
            $Target = Join-Path $Dest $D.Name
            if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force }
            Copy-Item (Join-Path $D.FullName "SKILL.md") $Target -Force
            
            # Custom logic for Orchestrator: add the roster
            if ($D.Name -eq "agency-agents-orchestrator" -and $RosterContent) {
                $RosterPath = Join-Path $Target "AGENCY_ROSTER.md"
                # Safe UTF8 write without BOM or with explicit UTF8
                [System.IO.File]::WriteAllText($RosterPath, $RosterContent, (New-Object System.Text.UTF8Encoding $false))
                Write-Host "  + Attached AGENCY_ROSTER.md to Orchestrator"
            }
            $Count++
        }
    }
    Write-Host "[OK]  Antigravity: $Count skills -> $Dest"
}

function Install-GeminiCLI {
    $Src = Join-Path $Integrations "gemini-cli"
    $Dest = Join-Path $env:USERPROFILE ".gemini\extensions\agency-agents"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/gemini-cli missing."; return }
    if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force }
    Copy-Item (Join-Path $Src "gemini-extension.json") $Dest -Force
    $SkillsSrc = Join-Path $Src "skills"
    $SkillsDest = Join-Path $Dest "skills"
    if (-not (Test-Path $SkillsDest)) { New-Item -ItemType Directory -Path $SkillsDest -Force }
    $Dirs = Get-ChildItem -Path $SkillsSrc -Directory
    $Count = 0
    foreach ($D in $Dirs) {
        if (Should-Install $D.Name) {
            $Target = Join-Path $SkillsDest $D.Name
            if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force }
            Copy-Item (Join-Path $D.FullName "SKILL.md") $Target -Force
            $Count++
        }
    }
    Write-Host "[OK]  Gemini CLI: $Count skills -> $Dest"
}

function Install-OpenCode {
    $Src = Join-Path $Integrations "opencode\agents"
    $Dest = Join-Path $PWD ".opencode\agents"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/opencode missing."; return }
    $Count = 0
    $Files = Get-ChildItem -Path $Src -Filter "*.md" -File
    foreach ($F in $Files) {
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($F.Name)
        if (Should-Install $BaseName) {
            Copy-Item $F.FullName $Dest -Force
            $Count++
        }
    }
    Write-Host "[OK]  OpenCode: $Count agents -> $Dest"
}

function Install-Cursor {
    $Src = Join-Path $Integrations "cursor\rules"
    $Dest = Join-Path $PWD ".cursor\rules"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/cursor missing."; return }
    $Count = 0
    $Files = Get-ChildItem -Path $Src -Filter "*.mdc" -File
    foreach ($F in $Files) {
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($F.Name)
        if (Should-Install $BaseName) {
            Copy-Item $F.FullName $Dest -Force
            $Count++
        }
    }
    Write-Host "[OK]  Cursor: $Count rules -> $Dest"
}

function Install-Aider {
    $Src = Join-Path $Integrations "aider\CONVENTIONS.md"
    $Dest = Join-Path $PWD "CONVENTIONS.md"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/aider missing."; return }
    if ($Whitelist.Count -gt 0) {
        Write-Warning "Aider uses a single CONVENTIONS.md file. Config-based filtering is not available at install time. Use convert.ps1 to filter instead."
    }
    Copy-Item $Src $Dest -Force
    Write-Host "[OK]  Aider: CONVENTIONS.md -> $Dest"
}

function Install-Windsurf {
    $Src = Join-Path $Integrations "windsurf\.windsurfrules"
    $Dest = Join-Path $PWD ".windsurfrules"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/windsurf missing."; return }
    if ($Whitelist.Count -gt 0) {
        Write-Warning "Windsurf uses a single .windsurfrules file. Config-based filtering is not available at install time. Use convert.ps1 to filter instead."
    }
    Copy-Item $Src $Dest -Force
    Write-Host "[OK]  Windsurf: .windsurfrules -> $Dest"
}

function Install-OpenClaw {
    $Src = Join-Path $Integrations "openclaw"
    $Dest = Join-Path $env:USERPROFILE ".openclaw\agency-agents"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/openclaw missing."; return }
    if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force }
    $Dirs = Get-ChildItem -Path $Src -Directory
    $Count = 0
    foreach ($D in $Dirs) {
        if (Should-Install $D.Name) {
            $Target = Join-Path $Dest $D.Name
            if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force }
            Copy-Item (Join-Path $D.FullName "*.md") $Target -Force
            $Count++
        }
    }
    Write-Host "[OK]  OpenClaw: $Count workspaces -> $Dest"
}

function Install-Qwen {
    $Src = Join-Path $Integrations "qwen\agents"
    $Dest = Join-Path $PWD ".qwen\agents"
    if (-not (Test-Path $Src)) { Write-Warning "integrations/qwen missing."; return }
    $Count = 0
    $Files = Get-ChildItem -Path $Src -Filter "*.md" -File
    foreach ($F in $Files) {
        $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($F.Name)
        if (Should-Install $BaseName) {
            Copy-Item $F.FullName $Dest -Force
            $Count++
        }
    }
    Write-Host "[OK]  Qwen Code: $Count agents -> $Dest"
}

# --- Main Interaction ---

$SelectedTools = @()

if ($Interactive -or (-not $NoInteractive -and $Tool -eq "all")) {
    Write-Host "`n  The Agency -- Tool Installer (PowerShell)"
    Write-Host "  ------------------------------------------------"
    Write-Host "  Detected tools (marked with *):"
    
    $TempList = @()
    for ($i = 0; $i -lt $AllTools.Length; $i++) {
        $T = $AllTools[$i]
        $Detected = Test-Detected $T
        $Mark = if ($Detected) { "*" } else { " " }
        Write-Host "  $($i + 1)) [$Mark] $T"
        $TempList += [PSCustomObject]@{ Id = $i + 1; Name = $T; Detected = $Detected }
    }
    
    Write-Host "`n  Enter numbers separated by space (e.g. 1 3 7), 'all', or 'q' to quit."
    $Input = Read-Host "  >> "
    
    if ($Input -eq "all") { $SelectedTools = $AllTools }
    elseif ($Input -eq "q") { exit 0 }
    else {
        $Indices = $Input -split "\s+"
        foreach ($Idx in $Indices) {
            if ($Idx -as [int] -and $Idx -ge 1 -and $Idx -le $AllTools.Length) {
                $SelectedTools += $AllTools[$Idx - 1]
            }
        }
    }
} elseif ($Tool -ne "all") {
    $SelectedTools = @($Tool)
} else {
    # Non-interactive, auto-detect
    foreach ($T in $AllTools) {
        if (Test-Detected $T) { $SelectedTools += $T }
    }
}

if ($SelectedTools.Count -eq 0) {
    Write-Warning "No tools selected or detected. Use -Tool <name> to force install."
    exit 0
}

Write-Host "`nInstalling tools: $($SelectedTools -join ', ')"

foreach ($T in $SelectedTools) {
    switch ($T) {
        "claude-code" { Install-ClaudeCode }
        "copilot"     { Install-Copilot }
        "antigravity" { Install-Antigravity }
        "gemini-cli"  { Install-GeminiCLI }
        "opencode"    { Install-OpenCode }
        "cursor"      { Install-Cursor }
        "aider"        { Install-Aider }
        "windsurf"    { Install-Windsurf }
        "openclaw"    { Install-OpenClaw }
        "qwen"         { Install-Qwen }
    }
}

Write-Host "`n  Done! Installed $($SelectedTools.Count) tool(s).`n"
