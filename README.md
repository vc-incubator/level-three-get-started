# Level 3: get started

Two setup scripts for Level 3 students. Each one installs what Level 3 needs, asking before every
install, signs you in to GitHub, copies your private Level 3 package into `Agent-Team` in your
home folder, and offers to start Set Up My Team.

**Mac**, in Terminal:

```
curl -fsSL https://raw.githubusercontent.com/vc-incubator/level-three-get-started/main/get-started-mac.sh | bash
```

**Windows**, in PowerShell:

```
irm https://raw.githubusercontent.com/vc-incubator/level-three-get-started/main/get-started-windows.ps1 | iex
```

Running a script again skips whatever is already done. To only see what it would do, without
changing anything, download it and run it with `--check` (Mac) or `-Check` (Windows).

What it installs: git, Node.js 20 or newer, the GitHub CLI and Claude Code, each only with your yes.
The scripts hold no keys, no passwords and no personal data. Your package stays private: you can
only copy it after signing in with the GitHub account that was invited.

The source of these files is the `get-started/` folder of the Level 3 package. Change them there
first, then copy them here.
