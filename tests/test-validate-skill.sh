#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE="$REPO_ROOT/tests/validate-skill.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

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

- #1 A mistake [verify]
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

# Case 5: orphan reference fails (reference has #1 and #2, index only has #1)
mkdir -p "$tmp/orphan-ref/references"
cat > "$tmp/orphan-ref/SKILL.md" <<'EOF'
---
name: test
description: test
---

## Index

- #1 A mistake [verify]
EOF
cat > "$tmp/orphan-ref/references/cat.md" <<'EOF'
### #1 — A mistake [verify]
body

### #2 — Another mistake [verify]
body
EOF
if "$VALIDATE" "$tmp/orphan-ref" 2>/dev/null; then
  echo "FAIL: validator passed with orphan reference entry (#2 not in index)"
  exit 1
fi

# Case 6: malformed reference heading (### #123abc) does not satisfy index #123
mkdir -p "$tmp/malformed-ref/references"
cat > "$tmp/malformed-ref/SKILL.md" <<'EOF'
---
name: test
description: test
---

## Index

- #123 A mistake [verify]
EOF
cat > "$tmp/malformed-ref/references/cat.md" <<'EOF'
### #123abc — A mistake [verify]
body
EOF
if "$VALIDATE" "$tmp/malformed-ref" 2>/dev/null; then
  echo "FAIL: validator passed with malformed reference heading (### #123abc treated as #123)"
  exit 1
fi

# Case 7: prose mentioning "#999" elsewhere in SKILL.md does not create a
# false orphan when the index itself is scoped correctly (only #1 is a real
# index entry, and #1 has a matching reference). "#999" appears mid-line in
# prose and mid-line inside a fenced code example, never at line start, so
# an anchored index scan must not pick it up.
mkdir -p "$tmp/prose-mention/references"
cat > "$tmp/prose-mention/SKILL.md" <<'EOF'
---
name: test
description: test
---

## Index

- #1 A mistake [verify]

See also mistake #999 in another skill for comparison.

## Notes

```go
// example referencing mistake #999 in a comment
fmt.Println("see #999")
```
EOF
cat > "$tmp/prose-mention/references/cat.md" <<'EOF'
### #1 — A mistake [verify]
body
EOF
if ! "$VALIDATE" "$tmp/prose-mention"; then
  echo "FAIL: validator rejected valid skill due to unrelated #999 prose mention"
  exit 1
fi

# Case 8: missing closing frontmatter "---" fails
mkdir -p "$tmp/no-closing-frontmatter"
cat > "$tmp/no-closing-frontmatter/SKILL.md" <<'EOF'
---
name: test
description: test

## Index

- #1 A mistake [verify]
EOF
if "$VALIDATE" "$tmp/no-closing-frontmatter" 2>/dev/null; then
  echo "FAIL: validator passed with missing closing frontmatter ---"
  exit 1
fi

# Case 9: malformed index line (- #123abc Title) is not treated as #123.
# With a real #123 reference and no valid #123 index entry, this must fail
# with an orphan-reference error, not silently pass.
mkdir -p "$tmp/malformed-index/references"
cat > "$tmp/malformed-index/SKILL.md" <<'EOF'
---
name: test
description: test
---

## Index

- #123abc A mistake [verify]
EOF
cat > "$tmp/malformed-index/references/cat.md" <<'EOF'
### #123 — A mistake [verify]
body
EOF
if "$VALIDATE" "$tmp/malformed-index" 2>/dev/null; then
  echo "FAIL: validator passed with malformed index line (- #123abc treated as #123)"
  exit 1
fi

echo "OK"
