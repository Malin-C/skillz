#!/usr/bin/env bash
# Validate a skill folder: SKILL.md exists with frontmatter, and the
# index in SKILL.md matches the reference entries.
#
# Usage: validate-skill.sh <path-to-skill-folder>

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <skill-folder>" >&2
  exit 2
fi

SKILL_DIR="$1"

if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "error: $SKILL_DIR/SKILL.md not found" >&2
  exit 1
fi

# Frontmatter check: first line must be "---", a closing "---" must exist,
# and the frontmatter block (between the two "---" lines) must contain
# name: and description:.
first=$(head -n 1 "$SKILL_DIR/SKILL.md")
if [ "$first" != "---" ]; then
  echo "error: SKILL.md missing frontmatter (first line must be ---)" >&2
  exit 1
fi

closing_line=$(awk 'NR>1 && /^---$/ { print NR; exit }' "$SKILL_DIR/SKILL.md")
if [ -z "$closing_line" ]; then
  echo "error: SKILL.md frontmatter missing closing '---'" >&2
  exit 1
fi

frontmatter=$(sed -n "2,$((closing_line - 1))p" "$SKILL_DIR/SKILL.md")
if ! echo "$frontmatter" | grep -qE '^name:'; then
  echo "error: SKILL.md frontmatter missing 'name:'" >&2
  exit 1
fi
if ! echo "$frontmatter" | grep -qE '^description:'; then
  echo "error: SKILL.md frontmatter missing 'description:'" >&2
  exit 1
fi

# Extract mistake numbers from the index in SKILL.md.
# Index lines look like: "- #123 Some title [verify]"
# Anchored to the start of the line so prose mentions like "see #45" or
# a "#123" inside a fenced code example don't get picked up. Also require
# a boundary (whitespace or end of line) after the number so "- #123abc"
# is not mistaken for "#123".
index_nums=$(grep -oE '^- #[0-9]+([[:space:]]|$)' "$SKILL_DIR/SKILL.md" | grep -oE '#[0-9]+' | sort -u || true)

# Extract mistake numbers from reference headings.
# Heading lines look like: "### #123 — Some title [verify]"
# Require a boundary (whitespace or end of line) after the number so
# "### #123abc" is not mistaken for "#123".
ref_nums=""
if [ -d "$SKILL_DIR/references" ]; then
  ref_nums=$(grep -horE '^### #[0-9]+([[:space:]]|$)' "$SKILL_DIR/references"/*.md 2>/dev/null \
             | grep -oE '#[0-9]+' | sort -u || true)
fi

# Orphan index entries (in index but no reference)
orphans=$(comm -23 <(echo "$index_nums") <(echo "$ref_nums") | grep -v '^$' || true)
if [ -n "$orphans" ]; then
  echo "error: index entries with no matching reference:" >&2
  echo "$orphans" >&2
  exit 1
fi

# Orphan references (in reference but no index)
missing_index=$(comm -13 <(echo "$index_nums") <(echo "$ref_nums") | grep -v '^$' || true)
if [ -n "$missing_index" ]; then
  echo "error: reference entries missing from index:" >&2
  echo "$missing_index" >&2
  exit 1
fi

echo "OK: $SKILL_DIR"
