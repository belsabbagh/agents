#!/usr/bin/env bash
# install.sh — wire this repo into opencode, codex, and/or claude code.
#
# Everything is symlinked, so `git pull` in this repo updates all agents at once.
# Existing files are backed up to <path>.bak.<timestamp> before being replaced.
#
# Usage:
#   ./install.sh                              Install everything for all agents
#   ./install.sh --agents opencode claude     Only these agents (opencode|codex|claude)
#   ./install.sh --skills using-jq using-rg   Only these skills (names under skills/)
#   ./install.sh -a opencode -s using-jq      Short flags; repeatable
#   ./install.sh --dry-run                    Print what would happen, change nothing
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_AGENTS=(opencode codex claude)
HOOK_NAME="block-nonrg-grep.sh"

DRY_RUN=0
AGENTS=()
SKILLS=()

die() { printf 'install: error: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--agent|--agents)
      shift; [ $# -gt 0 ] && [[ "$1" != -* ]] || die "$1 needs at least one value"
      while [ $# -gt 0 ] && [[ "$1" != -* ]]; do AGENTS+=("$1"); shift; done
      ;;
    -s|--skill|--skills)
      shift; [ $# -gt 0 ] && [[ "$1" != -* ]] || die "$1 needs at least one value"
      while [ $# -gt 0 ] && [[ "$1" != -* ]]; do SKILLS+=("$1"); shift; done
      ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

# Defaults: all agents, all skills found in the repo.
[ ${#AGENTS[@]} -eq 0 ] && AGENTS=("${ALL_AGENTS[@]}")
if [ ${#SKILLS[@]} -eq 0 ]; then
  for d in "$REPO_DIR"/skills/*/; do
    [ -f "$d/SKILL.md" ] && SKILLS+=("$(basename "$d")")
  done
fi

for a in "${AGENTS[@]}"; do
  case " ${ALL_AGENTS[*]} " in *" $a "*) ;; *) die "unknown agent '$a' (choose from: ${ALL_AGENTS[*]})" ;; esac
done
for s in "${SKILLS[@]}"; do
  [ -f "$REPO_DIR/skills/$s/SKILL.md" ] || die "skill '$s' not found (expected skills/$s/SKILL.md)"
done

agent_home() { case "$1" in
  opencode) echo "$HOME/.config/opencode" ;;
  codex)    echo "$HOME/.codex" ;;
  claude)   echo "$HOME/.claude" ;;
esac; }

instructions_name() { case "$1" in claude) echo "CLAUDE.md" ;; *) echo "AGENTS.md" ;; esac; }

skills_home() { case "$1" in
  codex) echo "$HOME/.agents/skills" ;;        # codex's native user-scope skills dir
  *)     echo "$(agent_home "$1")/skills" ;;
esac; }

# link <src> <dst> — symlink dst -> src, backing up any existing file first.
link() {
  local src="$1" dst="$2"
  if [ "$DRY_RUN" -eq 1 ]; then printf '[dry-run] %s -> %s\n' "$dst" "$src"; return; fi
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  already linked  %s\n' "$dst"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$bak"
    printf '  backed up       %s -> %s\n' "$dst" "$bak"
  fi
  ln -s "$src" "$dst"
  printf '  linked          %s -> %s\n' "$dst" "$src"
}

register_claude_hook() {
  local settings="$HOME/.claude/settings.json"
  local hook_cmd="bash \"\$HOME/.claude/hooks/$HOOK_NAME\""
  if [ "$DRY_RUN" -eq 1 ]; then printf '[dry-run] register %s in %s\n' "$HOOK_NAME" "$settings"; return; fi
  if ! command -v jq >/dev/null 2>&1; then
    printf '  note: jq not found — add this to %s manually:\n' "$settings"
    printf '    {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"%s","timeout":10}]}]}}\n' "$hook_cmd"
    return
  fi
  [ -f "$settings" ] || printf '{}\n' > "$settings"
  if jq -e '(.hooks.PreToolUse // []) | tostring | contains("block-nonrg-grep")' "$settings" >/dev/null; then
    printf '  already registered hook in %s\n' "$settings"
    return
  fi
  cp "$settings" "$settings.bak.$(date +%Y%m%d%H%M%S)"
  jq --arg cmd "$hook_cmd" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [{"matcher":"Bash","hooks":[{"type":"command","command":$cmd,"timeout":10}]}]
  ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
  printf '  registered      hook in %s (backup alongside)\n' "$settings"
}

for a in "${AGENTS[@]}"; do
  home="$(agent_home "$a")"
  printf '== %s ==\n' "$a"
  link "$REPO_DIR/AGENTS.md" "$home/$(instructions_name "$a")"
  for s in "${SKILLS[@]}"; do
    link "$REPO_DIR/skills/$s" "$(skills_home "$a")/$s"
  done
  # Subagent definitions: markdown format shared by opencode and claude.
  # Codex uses TOML agent files — skipped (see README).
  if [ "$a" != "codex" ] && [ -d "$REPO_DIR/agents" ]; then
    for f in "$REPO_DIR"/agents/*.md; do
      [ -e "$f" ] || continue
      link "$f" "$home/agents/$(basename "$f")"
    done
  fi
  if [ "$a" = "claude" ] && [ -f "$REPO_DIR/hooks/$HOOK_NAME" ]; then
    link "$REPO_DIR/hooks/$HOOK_NAME" "$home/hooks/$HOOK_NAME"
    register_claude_hook
  fi
done

printf 'done.%s\n' "$([ "$DRY_RUN" -eq 1 ] && printf ' (dry-run — nothing changed)')"
