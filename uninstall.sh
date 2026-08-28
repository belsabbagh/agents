#!/usr/bin/env bash
# uninstall.sh — remove symlinks created by install.sh (only links that point
# into this repo are removed; your other files are never touched).
# Backups made by install.sh (<path>.bak.<timestamp>) are left in place — restore
# them manually if wanted.
#
# Usage:
#   ./uninstall.sh                            Remove everything, all agents
#   ./uninstall.sh --agents opencode          Only these agents
#   ./uninstall.sh --skills using-jq          Only these skills
#   ./uninstall.sh --dry-run                  Print what would happen
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_AGENTS=(opencode codex claude)

DRY_RUN=0
AGENTS=()
SKILLS=()
SKILLS_EXPLICIT=0

die() { printf 'uninstall: error: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--agent|--agents)
      shift; [ $# -gt 0 ] && [[ "$1" != -* ]] || die "$1 needs at least one value"
      while [ $# -gt 0 ] && [[ "$1" != -* ]]; do AGENTS+=("$1"); shift; done
      ;;
    -s|--skill|--skills)
      SKILLS_EXPLICIT=1
      shift; [ $# -gt 0 ] && [[ "$1" != -* ]] || die "$1 needs at least one value"
      while [ $# -gt 0 ] && [[ "$1" != -* ]]; do SKILLS+=("$1"); shift; done
      ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[ ${#AGENTS[@]} -eq 0 ] && AGENTS=("${ALL_AGENTS[@]}")
if [ ${#SKILLS[@]} -eq 0 ]; then
  for d in "$REPO_DIR"/skills/*/; do
    [ -f "$d/SKILL.md" ] && SKILLS+=("$(basename "$d")")
  done
fi

agent_home() { case "$1" in
  opencode) echo "$HOME/.config/opencode" ;;
  codex)    echo "$HOME/.codex" ;;
  claude)   echo "$HOME/.claude" ;;
esac; }

instructions_name() { case "$1" in claude) echo "CLAUDE.md" ;; *) echo "AGENTS.md" ;; esac; }

skills_home() { case "$1" in
  codex) echo "$HOME/.agents/skills" ;;
  *)     echo "$(agent_home "$1")/skills" ;;
esac; }

# unlink <dst> — remove dst only if it is a symlink pointing into this repo.
unlink() {
  local dst="$1"
  [ -L "$dst" ] || return 0
  case "$(readlink "$dst")" in
    "$REPO_DIR"/*) ;;
    *) return 0 ;;
  esac
  if [ "$DRY_RUN" -eq 1 ]; then printf '[dry-run] remove %s\n' "$dst"; return; fi
  rm "$dst"
  printf '  removed  %s\n' "$dst"
}

for a in "${AGENTS[@]}"; do
  home="$(agent_home "$a")"
  printf '== %s ==\n' "$a"
  # An explicit --skills filter scopes the run to skills only; harness files
  # (instructions, agents, hooks) are removed only on a full uninstall.
  if [ "$SKILLS_EXPLICIT" -eq 0 ]; then
    unlink "$home/$(instructions_name "$a")"
  fi
  for s in "${SKILLS[@]}"; do
    unlink "$(skills_home "$a")/$s"
  done
  if [ "$SKILLS_EXPLICIT" -eq 0 ]; then
    if [ -d "$REPO_DIR/agents" ]; then
      for f in "$REPO_DIR"/agents/*.md; do
        [ -e "$f" ] || continue
        unlink "$home/agents/$(basename "$f")"
      done
    fi
    [ "$a" = "claude" ] && unlink "$home/hooks/block-nonrg-grep.sh"
  fi
done

printf 'done.%s\n' "$([ "$DRY_RUN" -eq 1 ] && printf ' (dry-run — nothing changed)')"
printf 'note: the claude hook entry in ~/.claude/settings.json (if any) and .bak backups were left untouched.\n'
