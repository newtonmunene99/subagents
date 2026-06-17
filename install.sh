#!/usr/bin/env bash
#
# install.sh
# ----------
# Install the subagents in this repo into the agent directories of one
# or more supported harnesses. Each subagent is symlinked, not copied,
# so pulling updates in this repo immediately takes effect everywhere.
#
# Supported harnesses:
#   cursor → ~/.cursor/agents
#   claude → ~/.claude/agents
#   gemini → ~/.gemini/agents
#   codex  → ~/.codex/agents
#
# Usage:
#   ./install.sh                          Install to all harnesses
#   ./install.sh claude                   Install to claude only
#   ./install.sh claude cursor            Install to claude and cursor
#   ./install.sh all                      Same as no arguments
#   ./install.sh --uninstall              Remove links from all harnesses
#   ./install.sh --uninstall claude       Remove links from claude only
#   ./install.sh --dry-run claude         Preview what would change
#   ./install.sh --help                   Show this message
#
# Safe to re-run. Existing real (non-symlink) files at the target paths
# are left alone with a warning, so the script will never clobber a
# subagent the user authored by hand outside this repo.

set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------

# REPO_DIR is the absolute path of the directory this script lives in.
# Resolving it this way means the script behaves identically whether it is
# invoked from the repo root, from a parent directory, or via a symlink
# placed somewhere else on $PATH.
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Every harness this script knows how to install to. To add a new one,
# append the name here and add a matching case to harness_dir() below.
ALL_HARNESSES=(cursor claude gemini codex)

# EXCLUDE lists Markdown filenames at the repo root that are NOT
# subagents and must be skipped during installation. Extend this list
# when adding new top-level docs to the repo (for example, ROADMAP.md).
EXCLUDE=(
  "README.md"
  "CONTRIBUTING.md"
  "CHANGELOG.md"
  "LICENSE.md"
)

# harness_dir returns the absolute install directory for a given
# harness name. A case statement (rather than an associative array)
# keeps the script compatible with the bash 3.2 that ships on macOS,
# so contributors do not need a newer bash from Homebrew to run it.
harness_dir() {
  case "$1" in
    cursor) echo "$HOME/.cursor/agents" ;;
    claude) echo "$HOME/.claude/agents" ;;
    gemini) echo "$HOME/.gemini/agents" ;;
    codex)  echo "$HOME/.codex/agents" ;;
    *)
      echo "unknown harness: $1" >&2
      return 1
      ;;
  esac
}

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------

# usage prints a help summary covering every supported mode and harness.
usage() {
  cat <<EOF
Install subagents from this repo into one or more harness agent dirs.

Usage:
  $0                                Install to all harnesses
  $0 <harness>...                   Install to a subset
  $0 all                            Same as no arguments
  $0 --uninstall [<harness>...]     Remove links this script created
  $0 --dry-run [<harness>...]       Preview without changing anything
  $0 --help                         Show this message

Harnesses:
  cursor  →  ~/.cursor/agents
  claude  →  ~/.claude/agents
  gemini  →  ~/.gemini/agents
  codex   →  ~/.codex/agents
EOF
}

# MODE is what the script does to each symlink: install creates them,
# uninstall removes ones the script previously created, dry-run prints
# the planned actions without touching the filesystem.
MODE="install"

# HARNESSES collects the harness names the user selected. It is filled
# from positional arguments and falls back to ALL_HARNESSES when empty,
# so a bare invocation acts on every supported harness.
HARNESSES=()

for arg in "$@"; do
  case "$arg" in
    --uninstall) MODE="uninstall" ;;
    --dry-run)   MODE="dry-run" ;;
    -h|--help)   usage; exit 0 ;;
    all)         HARNESSES=("${ALL_HARNESSES[@]}") ;;
    cursor|claude|gemini|codex)
      HARNESSES+=("$arg")
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

# Default to every supported harness when none were given. This makes
# `./install.sh` and `./install.sh --uninstall` do the obvious thing
# without requiring the user to repeat the full list of harnesses.
if [[ ${#HARNESSES[@]} -eq 0 ]]; then
  HARNESSES=("${ALL_HARNESSES[@]}")
fi

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------

# is_excluded returns 0 (success) when the given basename matches an
# entry in the EXCLUDE list. Used to filter out top-level docs before
# they are mistaken for subagents.
is_excluded() {
  local name="$1"
  local excluded
  for excluded in "${EXCLUDE[@]}"; do
    [[ "$name" == "$excluded" ]] && return 0
  done
  return 1
}

# link_subagent operates on a single subagent file. It creates (or
# removes) a symlink in each selected harness directory according to
# the current MODE. The function deliberately refuses to overwrite real
# files at the target path: that protects user-authored subagents
# elsewhere on the system from being clobbered by a stray re-run.
link_subagent() {
  local src="$1"
  local name link target_dir harness
  name="$(basename "$src")"

  for harness in "${HARNESSES[@]}"; do
    target_dir="$(harness_dir "$harness")"
    link="$target_dir/$name"

    case "$MODE" in
      install)
        mkdir -p "$target_dir"
        # Refuse to touch a path that already holds a real file. The
        # user almost certainly wants that file preserved; let them
        # resolve the conflict by hand.
        if [[ -e "$link" && ! -L "$link" ]]; then
          echo "skip    $link (exists and is not a symlink)" >&2
          continue
        fi
        ln -sfn "$src" "$link"
        echo "linked  $link"
        ;;
      uninstall)
        # Only remove links that point back into this repo. Anything
        # else (real files, or links sourced from other repos) is left
        # untouched so uninstalling this collection cannot remove an
        # unrelated subagent the user installed separately.
        if [[ -L "$link" && "$(readlink "$link")" == "$src" ]]; then
          rm "$link"
          echo "removed $link"
        fi
        ;;
      dry-run)
        echo "would link $link -> $src"
        ;;
    esac
  done
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

# Echo the plan before doing anything so the user can sanity-check
# both the mode and the selected harnesses without enabling --dry-run.
echo "Mode:      $MODE"
echo "Harnesses: ${HARNESSES[*]}"
echo

# Walk the repo root non-recursively. The flat layout is intentional;
# if category folders are introduced later (engineering/, meta/, …),
# enable globstar with `shopt -s globstar` and change the glob below
# to `"$REPO_DIR"/**/*.md`.
shopt -s nullglob

count=0
for md in "$REPO_DIR"/*.md; do
  name="$(basename "$md")"
  is_excluded "$name" && continue
  link_subagent "$md"
  count=$((count + 1))
done

if [[ "$count" -eq 0 ]]; then
  echo "No subagent files found in $REPO_DIR" >&2
  exit 1
fi

echo
echo "Done. $count subagent(s) processed in $MODE mode."