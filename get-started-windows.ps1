# Get started on Windows: everything guides 01 and 02 (Step 1) do by hand, in one window.
#
#   Checks for, and with your yes installs: git, Node.js 20+, the GitHub CLI (gh), Claude Code.
#   Asks your name and email for git if they are not set.
#   Signs you in to GitHub in your browser.
#   Copies the package to $HOME\Agent-Team\student-package (or updates it if it is already there).
#   Offers to start Set Up My Team, which takes it from there.
#
# It asks before every install. It uses winget when the PC has it, and otherwise downloads the
# official installer (Git for Windows, nodejs.org, GitHub CLI releases). Windows may ask "Do you want to allow this app to make changes?"
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
$ProgressPreference = 'SilentlyContinue'   # Windows PowerShell 5.1 downloads are very slow with the progress bar on
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
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
function Get-Arch {
  if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') { return 'arm64' }
  return 'x64'
}
function Has-Winget {
  if (Has winget) { return $true }
  # On a new or never-updated PC, App Installer can be present but not switched on for this user.
  # This asks Windows to register it; it changes nothing if winget is not there at all.
  try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop } catch { }
  Refresh-Path
  return (Has winget)
}
function Latest-GitHub-Asset($repo, $pattern) {
  $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'level-three-get-started' }
  $assets = @($rel.assets)
  $a = $assets | Where-Object { $_.name -match $pattern } | Select-Object -First 1
  if ($a) { return $a.browser_download_url }
  return $null
}
function Installer-Url($key) {
  $arm = (Get-Arch) -eq 'arm64'
  switch ($key) {
    'git'  { if ($arm) { return Latest-GitHub-Asset 'git-for-windows/git' '^Git-[\d.]+-arm64\.exe$' } else { return Latest-GitHub-Asset 'git-for-windows/git' '^Git-[\d.]+-64-bit\.exe$' } }
    'node' {
      # Assign first: Windows PowerShell 5.1 passes a JSON array down a pipe as ONE object, not item by item.
      $all = Invoke-RestMethod 'https://nodejs.org/dist/index.json'
      $lts = ($all | Where-Object { $_.lts } | Select-Object -First 1).version
      if (-not $lts -or $lts -notmatch '^v\d+\.\d+\.\d+$') { return $null }
      return "https://nodejs.org/dist/$lts/node-$lts-$(Get-Arch).msi"
    }
    'gh'   { if ($arm) { return Latest-GitHub-Asset 'cli/cli' '_windows_arm64\.msi$' } else { return Latest-GitHub-Asset 'cli/cli' '_windows_amd64\.msi$' } }
  }
}
function Install-Tool($id, $key, $what, $source, $guide) {
  if (Has-Winget) {
    if (-not (Ask "Install $what with winget (from $id)?")) { Stop-Here "$what is needed." $guide }
    winget install --id $id -e --source winget --accept-source-agreements --accept-package-agreements
    Refresh-Path
    return
  }
  # No winget (common on Windows 10 that never updated its Store apps): use the official installer directly.
  if (-not (Ask "Install $what? This downloads the official installer from $source and runs it.")) { Stop-Here "$what is needed." $guide }
  $url = $null
  try { $url = Installer-Url $key } catch { }
  if (-not $url) { Stop-Here "could not find the $what installer to download. Check the internet connection and run this again." $guide }
  $file = Join-Path $env:TEMP ([IO.Path]::GetFileName(([uri]$url).AbsolutePath))
  Say "Downloading $([IO.Path]::GetFileName($file)) ..."
  try { Invoke-WebRequest $url -OutFile $file -UseBasicParsing } catch { Stop-Here "the $what download did not finish. Check the internet connection and run this again." $guide }
  Say "Installing $what. If Windows asks 'Do you want to allow this app to make changes?', answer Yes."
  if ($file -like '*.msi') { Start-Process msiexec.exe -ArgumentList "/i `"$file`" /passive /norestart" -Wait }
  else { Start-Process $file -ArgumentList '/VERYSILENT /NORESTART /SP- /SUPPRESSMSGBOXES' -Wait }
  Remove-Item $file -ErrorAction SilentlyContinue
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
    Install-Tool 'Git.Git' 'git' 'Git for Windows' 'gitforwindows.org' 'sops\SOP-01-Check-your-computer.md, Step 4'
    if (-not (Has git)) { Stop-Here 'git is still not found. Close this window, open a new PowerShell and run this again.' }
    Ok (git --version)
  }

  # 2. Node.js 20 or newer
  Say '2. Node.js (20 or newer)'
  $major = Node-Major
  if ($major -ge 20) { Ok "node $(node --version)" }
  elseif ($Check) { Todo "install Node.js (found: $(if ($major) { $major } else { 'none' }))" }
  else {
    Install-Tool 'OpenJS.NodeJS.LTS' 'node' 'Node.js (long-term-support version)' 'nodejs.org' 'sops\SOP-01-Check-your-computer.md, Step 3'
    if ((Node-Major) -lt 20) { Stop-Here 'Node.js is still missing or older than 20. Close this window, open a new PowerShell and run this again.' }
    Ok "node $(node --version)"
  }

  # 3. GitHub CLI
  Say '3. GitHub CLI (gh)'
  if (Has gh) { Ok ((gh --version) | Select-Object -First 1) }
  elseif ($Check) { Todo 'install the GitHub CLI' }
  else {
    Install-Tool 'GitHub.cli' 'gh' 'the GitHub CLI' 'github.com/cli/cli' 'sops\SOP-02-Set-up-your-folders.md, Step 6'
    if (-not (Has gh)) { Stop-Here 'gh is still not found. Close this window, open a new PowerShell and run this again.' }
    Ok ((gh --version) | Select-Object -First 1)
  }

  # 4. Claude Code
  Say '4. Claude Code'
  if (Has claude) { Ok "claude $((claude --version) | Select-Object -First 1)" }
  elseif ($Check) { Todo 'install Claude Code' }
  else {
    if (-not (Ask "Install Claude Code (Anthropic's official installer, claude.ai/install.ps1)?")) { Stop-Here 'Claude Code runs your team.' 'sops\SOP-01-Check-your-computer.md' }
    # Run it in its own scope: the installer can set session-wide preferences (e.g. stop on any error)
    # that would otherwise leak into the rest of this script.
    & { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression }
    $ErrorActionPreference = 'Continue'
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
  # Through cmd so a 'not logged in' message on stderr can never become a PowerShell error; only the exit code counts.
  cmd /c "gh auth status --hostname github.com >nul 2>&1"
  if ($LASTEXITCODE -eq 0) { Ok 'signed in' }
  elseif ($Check) { Todo 'sign in to GitHub' }
  else {
    Say 'Next, GitHub shows an 8-character code here and opens your browser. Sign in with the GitHub account that accepted the Level 3 invitation, type the code there and press Authorize. The code goes only into that GitHub page, never into a chat.'
    Say 'If it asks "Authenticate Git with your GitHub credentials?", answer Yes.'
    gh auth login --hostname github.com --git-protocol https --web
    if ($LASTEXITCODE -ne 0) { Stop-Here 'the GitHub sign-in did not finish.' 'sops\SOP-02-Set-up-your-folders.md, Step 6' }
    cmd /c "gh auth setup-git --hostname github.com >nul 2>&1"
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
