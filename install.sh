#!/usr/bin/env bash
# Install, list, or uninstall a skill from this repo into a target
# .claude/skills/ directory.
#
# Usage:
#   install.sh <skill-name>                 # global (~/.claude/skills)
#   install.sh <skill-name> <target-dir>    # target/.claude/skills
#   install.sh --list
#   install.sh --uninstall <skill> [target-dir]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

usage() {
  cat >&2 <<EOF
usage: install.sh <skill-name> [target-dir]
       install.sh --list
       install.sh --uninstall <skill-name> [target-dir]
EOF
  exit 2
}

skills_root_for_target() {
  local target="${1:-}"
  if [ -z "$target" ]; then
    echo "$HOME/.claude/skills"
  else
    echo "$target/.claude/skills"
  fi
}

cmd_list() {
  if [ ! -d "$SKILLS_DIR" ]; then
    echo "no skills directory found at $SKILLS_DIR" >&2
    return 0
  fi
  for dir in "$SKILLS_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    skill_md="$dir/SKILL.md"
    desc=""
    if [ -f "$skill_md" ]; then
      desc=$(grep -m1 -E '^description:' "$skill_md" | sed -E 's/^description:[[:space:]]*//')
    fi
    printf '%s — %s\n' "$name" "$desc"
  done
}

cmd_install() {
  local name="$1"
  local target="${2:-}"
  local src="$SKILLS_DIR/$name"
  if [ ! -d "$src" ]; then
    echo "error: skill '$name' not found at $src" >&2
    exit 1
  fi
  local dest_root; dest_root=$(skills_root_for_target "$target")
  local dest="$dest_root/$name"
  mkdir -p "$dest_root"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    printf 'target %s already exists. overwrite? [y/N] ' "$dest" >&2
    read -r reply
    case "$reply" in
      y|Y|yes|YES) rm -rf "$dest" ;;
      *) echo "aborted" >&2; exit 1 ;;
    esac
  fi
  ln -s "$src" "$dest"
  echo "installed: $dest -> $src"
}

cmd_uninstall() {
  local name="$1"
  local target="${2:-}"
  local dest_root; dest_root=$(skills_root_for_target "$target")
  local dest="$dest_root/$name"
  if [ ! -L "$dest" ] && [ ! -e "$dest" ]; then
    echo "not installed: $dest" >&2
    exit 0
  fi
  rm -rf "$dest"
  echo "uninstalled: $dest"
}

if [ $# -lt 1 ]; then usage; fi

case "$1" in
  --list)
    cmd_list
    ;;
  --uninstall)
    shift
    [ $# -ge 1 ] || usage
    cmd_uninstall "$@"
    ;;
  -h|--help)
    usage
    ;;
  -*)
    usage
    ;;
  *)
    cmd_install "$@"
    ;;
esac
