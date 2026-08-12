#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$REPO_ROOT/tests/validate-skill.sh"

tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT

# Case 1: missing SKILL.md fails
mkdir -p "$tmp/broken-skill"
if "$VALIDATE" "$tmp/broken-skill" 2>/dev/null; then
  echo "FAIL: validator passed on missing SKILL.md"
  exit 1
fi

# Case 2: SKILL.md without frontmatter fails
echo "no frontmatter here" > "$tmp/broken-skill/SKILL.md"
if "$VALIDATE" "$tmp/broken-skill" 2>/dev/null; then
  echo "FAIL: validator passed on missing frontmatter"
  exit 1
fi

# Case 3: index entry with no matching reference fails
mkdir -p "$tmp/skill-with-gap/references"
cat > "$tmp/skill-with-gap/SKILL.md" <<'EOF'
---
name: test
description: test
---

## Index

#1 A mistake [verify]
EOF
if "$VALIDATE" "$tmp/skill-with-gap" 2>/dev/null; then
  echo "FAIL: validator passed with orphan index entry"
  exit 1
fi

# Case 4: matched index + reference passes
cat > "$tmp/skill-with-gap/references/cat.md" <<'EOF'
### #1 — A mistake [verify]
body
EOF
if ! "$VALIDATE" "$tmp/skill-with-gap"; then
  echo "FAIL: validator rejected valid skill"
  exit 1
fi

echo "OK"
