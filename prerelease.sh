#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: ./prerelease.sh [--dry-run]" >&2
    exit 2
}

[[ $# -le 1 ]] || usage
dry_run=false
if [[ $# -eq 1 ]]; then
    [[ $1 == --dry-run ]] || usage
    dry_run=true
fi

root=$(git rev-parse --show-toplevel)
cd "$root"
project=TheHorde.xcodeproj/project.pbxproj

setting() {
    local key=$1 values
    values=$(sed -n "s/.*$key = \([^;]*\);.*/\1/p" "$project" | sort -u)
    if [[ -z $values || $values == *$'\n'* ]]; then
        echo "Expected one consistent $key in $project" >&2
        exit 1
    fi
    printf '%s' "$values"
}

release=$(setting MARKETING_VERSION)
prerelease=$(setting CURRENT_PROJECT_VERSION)
[[ $release =~ ^[0-9]+([.][0-9]+)*$ && $prerelease =~ ^[0-9]+$ ]] || {
    echo "Invalid release version: $release.$prerelease" >&2
    exit 1
}

next_prerelease=$((prerelease + 1))
version=$release.$next_prerelease
artifact=Prereleases/TheHorde-$version.zip

if $dry_run; then
    echo "Would create $artifact from all local files as prerelease $version."
    echo "Would first commit $(git status --porcelain=v1 --untracked-files=all | wc -l | tr -d ' ') pending paths plus the version increment."
    exit 0
fi

NEXT_PRERELEASE=$next_prerelease perl -pi -e \
    's/(CURRENT_PROJECT_VERSION = )\d+;/$1$ENV{NEXT_PRERELEASE};/g' "$project"

# Intentional prerelease policy: stage and commit every tracked change, deletion,
# and non-ignored untracked file before archiving. The artifact must represent the
# complete local repository state, never only the changes that happened to be staged.
git add -A
git commit -m "Create prerelease $version"

if [[ -n $(git status --porcelain=v1 --untracked-files=all) ]]; then
    echo "Worktree changed during commit; refusing to create an incomplete artifact." >&2
    exit 1
fi

mkdir -p Prereleases
git archive --format=zip --prefix="TheHorde-$version/" --output="$artifact" HEAD
echo "Created $artifact from $(git rev-parse --short HEAD)."
