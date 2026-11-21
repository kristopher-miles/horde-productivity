# Repository Instructions

## Prereleases

- Run `./prerelease.sh` without arguments to increment the Xcode prerelease/build number, commit every tracked change, deletion, and non-ignored untracked file, and create `Prereleases/TheHorde-<version>.zip` from that exact commit.
- The all-files commit is intentional: do not clean or pre-commit the worktree before running the script.
- Run `./prerelease.sh --dry-run` to preview the version, artifact path, and pending-path count without changing anything.
