# uninstall.ps1 -- Uninstall The Agency agents from your local agentic tool(s).
#
# Removes agents from the config directories of supported tools.
#
# Usage:
#   .\scripts\uninstall.ps1 [-Tool <name>] [-Interactive] [-NoInteractive] [-Help]

param (
    [string]$Tool = "all",
    [switch]$Interactive,
    [switch]$NoInteractive,
    [switch]$Help
)

if ($Help) {
    Write-Host "Usage: .\scripts\uninstall.ps1 [-Tool <name>] [-Interactive] [-NoInteractive] [-Help]"
    Write-Host ""
    Write-Host "Tools: claude-code, copilot, antigravity, gemini-cli, opencode, openclaw, cursor, aider, windsurf, qwen"
    exit 0
}

$RepoRoot = Resolve-Path "$PSScriptRoot\.."
$AllTools = @("claude-code", "copilot", "antigravity", "gemini-cli", "opencode", "openclaw", "cursor", "aider", "windsurf", "qwen")

# --- Detection of Installation ---

function Test-Installed {
    param($T)
    $Home = $env:USERPROFILE
    switch ($T) {
        "claude-code" { return Test-Path (Join-Path $Home ".claude\agents") }
        "copilot"     { return (Test-Path (Join-Path $Home ".github\agents")) -or (Test-Path (Join-Path $Home ".copilot\agents")) }
        "antigravity" { return Test-Path (Join-Path $Home ".gemini\antigravity\skills") }
        "gemini-cli"  { return Test-Path (Join-Path $Home ".gemini\extensions\agency-agents") }
        "cursor"      { return Test-Path (Join-Path $PWD ".cursor\rules") }
        "opencode"    { return Test-Path (Join-Path $PWD ".opencode\agents") }
        "aider"        { return Test-Path (Join-Path $PWD "CONVENTIONS.md") }
        "openclaw"    { return Test-Path (Join-Path $Home ".openclaw\agency-agents") }
        "windsurf"    { return Test-Path (Join-Path $PWD ".windsurfrules") }
        "qwen"         { return Test-Path (Join-Path $PWD ".qwen\agents") }
    }
    return $false
}

# --- Uninstallers ---

function Uninstall-ClaudeCode {
    $Dest = Join-Path $env:USERPROFILE ".claude\agents"
    if (Test-Path $Dest) {
        Remove-Item (Join-Path $Dest "*.md") -Force -ErrorAction SilentlyContinue
        Write-Host "[OK]  Claude Code: Agents removed from $Dest"
    }
}

function Uninstall-Copilot {
    $DestGithub = Join-Path $env:USERPROFILE ".github\agents"
    $DestCopilot = Join-Path $env:USERPROFILE ".copilot\agents"
    if (Test-Path $DestGithub) {
        Remove-Item (Join-Path $DestGithub "*.md") -Force -ErrorAction SilentlyContinue
        Write-Host "[OK]  Copilot: Agents removed from $DestGithub"
    }
    if (Test-Path $DestCopilot) {
        Remove-Item (Join-Path $DestCopilot "*.md") -Force -ErrorAction SilentlyContinue
        Write-Host "[OK]  Copilot: Agents removed from $DestCopilot"
    }
}

function Uninstall-Antigravity {
    $Dest = Join-Path $env:USERPROFILE ".gemini\antigravity\skills"
    if (Test-Path $Dest) {
        $Dirs = Get-ChildItem -Path $Dest -Filter "agency-*" -Directory
        foreach ($D in $Dirs) {
            Remove-Item $D.FullName -Recurse -Force
        }
        Write-Host "[OK]  Antigravity: Agency skills removed from $Dest"
    }
}

function Uninstall-GeminiCLI {
    $Dest = Join-Path $env:USERPROFILE ".gemini\extensions\agency-agents"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Recurse -Force
        Write-Host "[OK]  Gemini CLI: Extension removed from $Dest"
    }
}

function Uninstall-OpenCode {
    $Dest = Join-Path $PWD ".opencode\agents"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Recurse -Force
        Write-Host "[OK]  OpenCode: Agents removed from $Dest"
    }
}

function Uninstall-Cursor {
    $Dest = Join-Path $PWD ".cursor\rules"
    if (Test-Path $Dest) {
        Remove-Item (Join-Path $Dest "*.mdc") -Force -ErrorAction SilentlyContinue
        Write-Host "[OK]  Cursor: Rules removed from $Dest"
    }
}

function Uninstall-Aider {
    $Dest = Join-Path $PWD "CONVENTIONS.md"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Force
        Write-Host "[OK]  Aider: CONVENTIONS.md removed"
    }
}

function Uninstall-Windsurf {
    $Dest = Join-Path $PWD ".windsurfrules"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Force
        Write-Host "[OK]  Windsurf: .windsurfrules removed"
    }
}

function Uninstall-OpenClaw {
    $Dest = Join-Path $env:USERPROFILE ".openclaw\agency-agents"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Recurse -Force
        Write-Host "[OK]  OpenClaw: Workspaces removed from $Dest"
    }
}

function Uninstall-Qwen {
    $Dest = Join-Path $PWD ".qwen\agents"
    if (Test-Path $Dest) {
        Remove-Item $Dest -Recurse -Force
        Write-Host "[OK]  Qwen Code: Agents removed from $Dest"
    }
}

# --- Main Interaction ---

$SelectedTools = @()

if ($Interactive -or (-not $NoInteractive -and $Tool -eq "all")) {
    Write-Host "`n  The Agency -- Tool Uninstaller (PowerShell)"
    Write-Host "  ------------------------------------------------"
    Write-Host "  Installed components (marked with *):"
    
    $TempList = @()
    for ($i = 0; $i -lt $AllTools.Length; $i++) {
        $T = $AllTools[$i]
        $Installed = Test-Installed $T
        $Mark = if ($Installed) { "*" } else { " " }
        Write-Host "  $($i + 1)) [$Mark] $T"
    }
    
    Write-Host "`n  Enter numbers to uninstall (e.g. 1 3 7), 'all', or 'q' to quit."
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
    # Non-interactive, auto-uninstall everything installed
    foreach ($T in $AllTools) {
        if (Test-Installed $T) { $SelectedTools += $T }
    }
}

if ($SelectedTools.Count -eq 0) {
    Write-Warning "No tools selected or found to uninstall."
    exit 0
}

Write-Host "`nUninstalling tools: $($SelectedTools -join ', ')"

foreach ($T in $SelectedTools) {
    switch ($T) {
        "claude-code" { Uninstall-ClaudeCode }
        "copilot"     { Uninstall-Copilot }
        "antigravity" { Uninstall-Antigravity }
        "gemini-cli"  { Uninstall-GeminiCLI }
        "opencode"    { Uninstall-OpenCode }
        "cursor"      { Uninstall-Cursor }
        "aider"        { Uninstall-Aider }
        "windsurf"    { Uninstall-Windsurf }
        "openclaw"    { Uninstall-OpenClaw }
        "qwen"         { Uninstall-Qwen }
    }
}

Write-Host "`n  Done! Uninstalled $($SelectedTools.Count) tool(s).`n"
