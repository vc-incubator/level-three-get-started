# Get started on Windows: everything guides 01 and 02 (Step 1) do by hand, in one window.
#
#   Checks for, and with your yes installs: git, Node.js 20+, the GitHub CLI (gh), Claude Code.
#   Asks your name and email for git if they are not set.
#   Signs you in to GitHub in your browser.
#   Copies the package to $HOME\Agent-Team\student-package (or updates it if it is already there).
#   Offers to start Set Up My Team, which takes it from there.
#
# It asks before every install. Windows may ask "Do you want to allow this app to make changes?"
# for git, Node.js and gh: that box is Windows, and the answer is Yes.
# Run it again any time: it skips whatever is already done.
#
#   -Check   report what is installed and what it would do, and change nothing.
#
# NOT YET VERIFIED on a brand-new PC (written 10 Nov 2026). If a step stops, the long version is
# in sops\SOP-01-Check-your-computer.md and sops\SOP-02-Set-up-your-folders.md.

# No param() block on purpose: it also runs as `irm <address> | iex`, where a param block does not apply.
$Check = ($args -contains '-Check') -or ($env:GET_STARTED_CHECK -eq '1')

$ErrorActionPreference = 'Continue'
$Repo   = 'vc-incubator/level-three-student-package'
$Parent = Join-Path $HOME 'Agent-Team'
$Dest   = Join-Path $Parent 'student-package'
$Setup  = Join-Path $Dest 'board\Set Up My Team.bat'

function Say($t)  { Write-Host ''; Write-Host $t }
function Ok($t)   { Write-Host "  ok: $t" }
function Todo($t) { Write-Host "  to do: $t" }
function Stop-Here($t, $guide) {
  Write-Host ''; Write-Host "Stopped: $t"
  if ($guide) { Write-Host "The long version: $guide" }
  throw 'get-started stopped'
}
function Ask($q) {
  $a = Read-Host "`n$q [y/N]"
  return $a -match '^(y|yes)$'
}
function Has($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Refresh-Path {
  # A new install changes PATH for new windows only. This picks it up in this one.
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machine;$user;$(Join-Path $HOME '.local\bin')"
}
function Node-Major {
  if (-not (Has node)) { return 0 }
  $v = (node --version) 2>$null
  if ($v -match '^v(\d+)') { return [int]$Matches[1] }
  return 0
}
function Winget-Install($id, $what, $guide) {
  if (-not (Has winget)) {
    Stop-Here "winget is missing, so $what cannot be installed from here. Install or update 'App Installer' from the Microsoft Store, then run this again." $guide
  }
  if (-not (Ask "Install $what with winget (from $id)?")) { Stop-Here "$what is needed." $guide }
  winget install --id $id -e --source winget --accept-source-agreements --accept-package-agreements
  Refresh-Path
}

try {
  Refresh-Path
  Say 'Getting your computer ready for Level 3. Nothing is installed without your yes.'

  # 1. git
  Say '1. git'
  if (Has git) { Ok (git --version) }
  elseif ($Check) { Todo 'install Git for Windows' }
  else {
    Winget-Install 'Git.Git' 'Git for Windows' 'sops\SOP-01-Check-your-computer.md, Step 4'
    if (-not (Has git)) { Stop-Here 'git is still not found. Close this window, open a new PowerShell and run this again.' }
    Ok (git --version)
  }

  # 2. Node.js 20 or newer
  Say '2. Node.js (20 or newer)'
  $major = Node-Major
  if ($major -ge 20) { Ok "node $(node --version)" }
  elseif ($Check) { Todo "install Node.js (found: $(if ($major) { $major } else { 'none' }))" }
  else {
    Winget-Install 'OpenJS.NodeJS.LTS' 'Node.js (long-term-support version)' 'sops\SOP-01-Check-your-computer.md, Step 3'
    if ((Node-Major) -lt 20) { Stop-Here 'Node.js is still missing or older than 20. Close this window, open a new PowerShell and run this again.' }
    Ok "node $(node --version)"
  }

  # 3. GitHub CLI
  Say '3. GitHub CLI (gh)'
  if (Has gh) { Ok ((gh --version) | Select-Object -First 1) }
  elseif ($Check) { Todo 'install the GitHub CLI' }
  else {
    Winget-Install 'GitHub.cli' 'the GitHub CLI' 'sops\SOP-02-Set-up-your-folders.md, Step 6'
    if (-not (Has gh)) { Stop-Here 'gh is still not found. Close this window, open a new PowerShell and run this again.' }
    Ok ((gh --version) | Select-Object -First 1)
  }

  # 4. Claude Code
  Say '4. Claude Code'
  if (Has claude) { Ok "claude $((claude --version) | Select-Object -First 1)" }
  elseif ($Check) { Todo 'install Claude Code' }
  else {
    if (-not (Ask "Install Claude Code (Anthropic's official installer, claude.ai/install.ps1)?")) { Stop-Here 'Claude Code runs your team.' 'sops\SOP-01-Check-your-computer.md' }
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Refresh-Path
    if (-not (Has claude)) { Stop-Here 'claude is still not found. Close this window, open a new PowerShell and run this again.' }
    Ok "claude $((claude --version) | Select-Object -First 1)"
  }

  # 5. git name and email (written into every commit and visible on GitHub)
  Say '5. Your name and email for git'
  $gname = (git config --global user.name) 2>$null
  $gmail = (git config --global user.email) 2>$null
  if ($gname -and $gmail) { Ok "$gname <$gmail>" }
  elseif ($Check) { Todo 'set your git name and email' }
  else {
    Say 'git writes a name and an email into every save, and they show on GitHub. Use ones you are happy to show.'
    if (-not $gname) { $n = Read-Host 'Your name'; if ($n) { git config --global user.name "$n" } }
    if (-not $gmail) { $e = Read-Host 'Your email'; if ($e) { git config --global user.email "$e" } }
    if (-not ((git config --global user.name) -and (git config --global user.email))) { Stop-Here 'git still has no name or email.' 'sops\SOP-01-Check-your-computer.md, Step 5' }
    Ok "$(git config --global user.name) <$(git config --global user.email)>"
  }

  # 6. Sign in to GitHub
  Say '6. Signed in to GitHub'
  gh auth status --hostname github.com *> $null
  if ($LASTEXITCODE -eq 0) { Ok 'signed in' }
  elseif ($Check) { Todo 'sign in to GitHub' }
  else {
    Say 'Next, GitHub shows an 8-character code here and opens your browser. Sign in with the GitHub account that accepted the Level 3 invitation, type the code there and press Authorize. The code goes only into that GitHub page, never into a chat.'
    Say 'If it asks "Authenticate Git with your GitHub credentials?", answer Yes.'
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Stop-Here 'the GitHub sign-in did not finish.' 'sops\SOP-02-Set-up-your-folders.md, Step 6' }
    gh auth setup-git --hostname github.com *> $null
    Ok 'signed in'
  }

  # 7. The package
  Say "7. The package in $Dest"
  if (Test-Path (Join-Path $Dest '.git')) {
    if ($Check) { Ok 'already there (would update it with git pull)' }
    else {
      git -C "$Dest" pull --ff-only
      if ($LASTEXITCODE -ne 0) { Stop-Here 'the package could not be updated. Nothing was changed.' 'sops\SOP-02-Set-up-your-folders.md, Getting updates' }
      Ok 'up to date'
    }
  }
  elseif (Test-Path $Dest) { Stop-Here "$Dest exists but is not a copy of the package. Rename or move it, then run this again." }
  elseif ($Check) { Todo 'copy the package' }
  else {
    New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    git clone "https://github.com/$Repo.git" "$Dest"
    if ($LASTEXITCODE -ne 0) {
      Say 'If it said "repository not found": accept the invitation in the email from GitHub first, and check this computer is signed in with that same account (gh auth status).'
      Stop-Here 'the package could not be copied.' 'sops\SOP-02-Set-up-your-folders.md, Step 1'
    }
    Ok 'copied'
  }

  if ($Check) { Say 'Check only: nothing was changed.'; return }

  Say "Your computer is ready, and the package is in $Dest."
  if ((Test-Path $Setup) -and (Ask 'Start Set Up My Team now? It takes it from here, and it asks before it does anything.')) {
    & $Setup
  } else {
    Say 'When you are ready, open Agent-Team > student-package > board and double-click Set Up My Team (the one whose type says Windows Batch File), or open INSTALL.md.'
  }
}
catch {
  if ($_.Exception.Message -ne 'get-started stopped') { Write-Host "Stopped: $($_.Exception.Message)" }
}
