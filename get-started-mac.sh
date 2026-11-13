#!/bin/bash
# Get started on a Mac: everything guides 01 and 02 (Step 1) do by hand, in one window.
#
#   Checks for, and with your yes installs: git, Node.js 20+, the GitHub CLI (gh), Claude Code.
#   Asks your name and email for git if they are not set.
#   Signs you in to GitHub in your browser.
#   Copies the package to ~/Agent-Team/student-package (or updates it if it is already there).
#   Offers to open Set Up My Team, which takes it from there.
#
# It asks before every install. Your Mac password is asked only by the Node and gh installers
# (macOS asks, not this script), and only if you do not use Homebrew.
# Run it again any time: it skips whatever is already done.
#
#   --check   report what is installed and what it would do, and change nothing.
#
# NOT YET VERIFIED on a brand-new Mac (written 10 Nov 2026). If a step stops, the long version is
# in sops/SOP-01-Check-your-computer.md and sops/SOP-02-Set-up-your-folders.md.

set -u

REPO="vc-incubator/level-three-student-package"
PARENT="$HOME/Agent-Team"
DEST="$PARENT/student-package"
SETUP="$DEST/board/Set Up My Team.command"
NODE_LINE="latest-v24.x"   # the long-term-support line on nodejs.org
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

say()  { printf '\n%s\n' "$*"; }
ok()   { printf '  ok: %s\n' "$*"; }
todo() { printf '  to do: %s\n' "$*"; }
stop() { printf '\nStopped: %s\n' "$*"; [ -n "${2:-}" ] && printf 'The long version: %s\n' "$2"; exit 1; }

# When this runs as `curl ... | bash`, the script itself is on standard input, so answers are read
# from the keyboard directly.
ask() {
  local answer
  printf '\n%s [y/N] ' "$1"
  read -r answer < /dev/tty || answer=""
  case "$answer" in y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}
ask_text() {
  local answer
  printf '%s ' "$1" > /dev/tty
  read -r answer < /dev/tty || answer=""
  printf '%s' "$answer"
}

if [ "$(uname -s)" != "Darwin" ] && [ $CHECK -eq 0 ]; then
  stop "this script is for a Mac. On Windows, use get-started-windows.ps1." "INSTALL.md"
fi

has() { command -v "$1" >/dev/null 2>&1; }
has_brew() { has brew; }
node_major() { node --version 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/'; }

# Claude Code's installer puts it in ~/.local/bin; this window does not know that yet.
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac

install_pkg_from() { # $1 = web address of a macOS .pkg, $2 = what it is
  local tmp
  tmp="$(mktemp -d)" || stop "could not make a temporary folder"
  say "Downloading $2 from $(printf '%s' "$1" | sed -E 's#^https://([^/]+)/.*#\1#') ..."
  curl -fL --progress-bar -o "$tmp/installer.pkg" "$1" || stop "the $2 download failed. Check your internet connection and run this again."
  say "Installing $2. macOS asks for your Mac login password next: it is the installer putting $2 where every app can find it."
  sudo installer -pkg "$tmp/installer.pkg" -target / || stop "the $2 installer did not finish."
  rm -rf "$tmp"
}

say "Getting your computer ready for Level 3. Nothing is installed without your yes."

# 1. git (comes with Apple's command line developer tools)
say "1. git"
if xcode-select -p >/dev/null 2>&1 && git --version >/dev/null 2>&1; then
  ok "$(git --version)"
elif [ $CHECK -eq 1 ]; then
  todo "install Apple's command line developer tools (they include git)"
else
  if ask "git is missing. It comes with Apple's free command line developer tools. Open Apple's installer now?"; then
    xcode-select --install >/dev/null 2>&1
    say "A box from macOS asks to install the tools: press Install. It can take 10 minutes or more."
    say "Waiting for it to finish (this window checks every 10 seconds) ..."
    waited=0
    until xcode-select -p >/dev/null 2>&1 && git --version >/dev/null 2>&1; do
      sleep 10; waited=$((waited + 10))
      [ $waited -ge 3600 ] && stop "the developer tools did not finish within an hour. Run this script again once they have." "sops/SOP-01-Check-your-computer.md, Step 4"
    done
    ok "$(git --version)"
  else
    stop "git is needed to copy the package." "sops/SOP-01-Check-your-computer.md, Step 4"
  fi
fi

# 2. Node.js 20 or newer
say "2. Node.js (20 or newer)"
major="$(node_major)"
if [ -n "$major" ] && [ "$major" -ge 20 ]; then
  ok "node $(node --version)"
elif [ $CHECK -eq 1 ]; then
  todo "install Node.js (found: ${major:-none})"
else
  if has_brew; then
    ask "Install Node.js with Homebrew (brew install node)?" || stop "Node.js 20 or newer is needed for the board." "sops/SOP-01-Check-your-computer.md, Step 3"
    brew install node || stop "brew install node did not finish."
  else
    ask "Install Node.js from nodejs.org (the long-term-support version)?" || stop "Node.js 20 or newer is needed for the board." "sops/SOP-01-Check-your-computer.md, Step 3"
    pkg="$(curl -fsSL "https://nodejs.org/dist/$NODE_LINE/" | grep -o 'node-v[0-9.]*\.pkg' | head -n 1)"
    [ -n "$pkg" ] || stop "could not find the Node.js installer on nodejs.org." "sops/SOP-01-Check-your-computer.md, Step 3"
    install_pkg_from "https://nodejs.org/dist/$NODE_LINE/$pkg" "Node.js"
    PATH="/usr/local/bin:$PATH"
  fi
  major="$(node_major)"
  [ -n "$major" ] && [ "$major" -ge 20 ] || stop "Node.js still reads as ${major:-missing}. Close this window, open a new one and run this again."
  ok "node $(node --version)"
fi

# 3. GitHub CLI (gh): the browser sign-in that git on a Mac does not have
say "3. GitHub CLI (gh)"
if has gh; then
  ok "$(gh --version | head -n 1)"
elif [ $CHECK -eq 1 ]; then
  todo "install the GitHub CLI"
else
  if has_brew; then
    ask "Install the GitHub CLI with Homebrew (brew install gh)?" || stop "gh is how this Mac signs in to GitHub." "sops/SOP-02-Set-up-your-folders.md, Step 6"
    brew install gh || stop "brew install gh did not finish."
  else
    ask "Install the GitHub CLI from GitHub (cli.github.com)?" || stop "gh is how this Mac signs in to GitHub." "sops/SOP-02-Set-up-your-folders.md, Step 6"
    tag="$(curl -fsSIL -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | sed -E 's#.*/tag/v##')"
    [ -n "$tag" ] || stop "could not find the latest GitHub CLI version." "sops/SOP-02-Set-up-your-folders.md, Step 6"
    install_pkg_from "https://github.com/cli/cli/releases/download/v$tag/gh_${tag}_macOS_universal.pkg" "the GitHub CLI"
    PATH="/usr/local/bin:$PATH"
  fi
  has gh || stop "gh is still not found. Close this window, open a new one and run this again."
  ok "$(gh --version | head -n 1)"
fi

# 4. Claude Code
say "4. Claude Code"
if has claude; then
  ok "claude $(claude --version 2>/dev/null | head -n 1)"
elif [ $CHECK -eq 1 ]; then
  todo "install Claude Code"
else
  ask "Install Claude Code (Anthropic's official installer, claude.ai/install.sh)?" || stop "Claude Code runs your team." "sops/SOP-01-Check-your-computer.md"
  curl -fsSL https://claude.ai/install.sh | bash || stop "the Claude Code installer did not finish."
  has claude || stop "claude is still not found. Close this window, open a new one and run this again."
  ok "claude $(claude --version 2>/dev/null | head -n 1)"
fi

# New Terminal windows must find claude too. The installer puts it in ~/.local/bin but, run from here,
# writes no startup file (seen on macOS 15, 13 Nov 2026), so a new window said "command not found: claude".
if [ $CHECK -eq 0 ] && [ -x "$HOME/.local/bin/claude" ]; then
  case "$(basename "${SHELL:-/bin/zsh}")" in
    bash) rc="$HOME/.bash_profile" ;;
    *)    rc="$HOME/.zprofile" ;;
  esac
  if ! grep -qs '\.local/bin' "$rc"; then
    printf '\n# Added by Level 3 get-started: Claude Code lives here\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$rc" \
      && ok "added ~/.local/bin to $(basename "$rc"), so new Terminal windows find claude"
  fi
fi

# 5. git name and email (written into every commit and visible on GitHub)
say "5. Your name and email for git"
gname="$(git config --global user.name 2>/dev/null)"
gmail="$(git config --global user.email 2>/dev/null)"
if [ -n "$gname" ] && [ -n "$gmail" ]; then
  ok "$gname <$gmail>"
elif [ $CHECK -eq 1 ]; then
  todo "set your git name and email"
else
  say "git writes a name and an email into every save, and they show on GitHub. Use ones you are happy to show."
  [ -n "$gname" ] || { gname="$(ask_text 'Your name:')"; [ -n "$gname" ] && git config --global user.name "$gname"; }
  [ -n "$gmail" ] || { gmail="$(ask_text 'Your email:')"; [ -n "$gmail" ] && git config --global user.email "$gmail"; }
  [ -n "$(git config --global user.name)" ] && [ -n "$(git config --global user.email)" ] || stop "git still has no name or email." "sops/SOP-01-Check-your-computer.md, Step 5"
  ok "$(git config --global user.name) <$(git config --global user.email)>"
fi

# 6. Sign in to GitHub
say "6. Signed in to GitHub"
if has gh && gh auth status --hostname github.com >/dev/null 2>&1; then
  # Signed in before this script ran: make sure git uses that sign-in too, or step 7 asks for a password.
  [ $CHECK -eq 1 ] || gh auth setup-git --hostname github.com >/dev/null 2>&1
  ok "$(gh auth status --hostname github.com 2>&1 | grep -m1 -o 'account [^ ]*' || echo 'signed in')"
elif [ $CHECK -eq 1 ]; then
  todo "sign in to GitHub"
else
  say "Next, GitHub shows an 8-character code here and opens your browser. Sign in with the GitHub account that accepted the Level 3 invitation, type the code there and press Authorize. The code goes only into that GitHub page, never into a chat."
  say "If it asks \"Authenticate Git with your GitHub credentials?\", answer Yes."
  gh auth login --hostname github.com --git-protocol https --web < /dev/tty || stop "the GitHub sign-in did not finish." "sops/SOP-02-Set-up-your-folders.md, Step 6"
  gh auth setup-git --hostname github.com >/dev/null 2>&1
  ok "signed in"
fi

# 7. The package
say "7. The package in $DEST"
if [ -d "$DEST/.git" ]; then
  if [ $CHECK -eq 1 ]; then
    ok "already there (would update it with git pull)"
  else
    git -C "$DEST" pull --ff-only || stop "the package could not be updated. Nothing was changed." "sops/SOP-02-Set-up-your-folders.md, Getting updates"
    ok "up to date"
  fi
elif [ -e "$DEST" ]; then
  stop "$DEST exists but is not a copy of the package. Rename or move it, then run this again."
elif [ $CHECK -eq 1 ]; then
  todo "copy the package"
else
  mkdir -p "$PARENT" || stop "could not make $PARENT"
  if ! git clone "https://github.com/$REPO.git" "$DEST"; then
    say "If it said \"repository not found\": accept the invitation in the email from GitHub first, and check this computer is signed in with that same account (gh auth status)."
    stop "the package could not be copied." "sops/SOP-02-Set-up-your-folders.md, Step 1"
  fi
  ok "copied"
fi

if [ $CHECK -eq 1 ]; then
  say "Check only: nothing was changed."
  exit 0
fi

say "Your computer is ready, and the package is in $DEST."
if [ -f "$SETUP" ] && ask "Open Set Up My Team now? It takes it from here, and it asks before it does anything."; then
  exec bash "$SETUP" < /dev/tty
fi
say "When you are ready, double-click Set Up My Team.command in Agent-Team > student-package > board, or open INSTALL.md."
