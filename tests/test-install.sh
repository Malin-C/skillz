#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

tmp=$(mktemp -d)
fake="$REPO_ROOT/skills/_fake-test-skill"

cleanup() {
  rm -rf "$tmp"
  rm -rf "$fake"
}
trap 'cleanup' EXIT

# Set up a fake skill under skills/ so tests do not depend on real content
mkdir -p "$fake"
cat > "$fake/SKILL.md" <<'EOF'
---
name: fake-test-skill
description: A fake skill used by install.sh tests
---
body
EOF

# Case 1: install to explicit target directory creates symlink
"$INSTALL" _fake-test-skill "$tmp"
link="$tmp/.claude/skills/_fake-test-skill"
if [ ! -L "$link" ]; then
  echo "FAIL: expected symlink at $link"; exit 1
fi
target=$(readlink "$link")
if [ "$target" != "$fake" ]; then
  echo "FAIL: symlink points to $target, expected $fake"; exit 1
fi

# Case 2: --list prints the fake skill with its description
out=$("$INSTALL" --list)
if ! echo "$out" | grep -q "_fake-test-skill"; then
  echo "FAIL: --list did not include fake skill"; exit 1
fi
if ! echo "$out" | grep -q "A fake skill used by install.sh tests"; then
  echo "FAIL: --list did not include description"; exit 1
fi

# Case 3: --uninstall removes the symlink
"$INSTALL" --uninstall _fake-test-skill "$tmp"
if [ -L "$link" ]; then
  echo "FAIL: symlink still present after uninstall"; exit 1
fi

# Case 4: install a non-existent skill errors
if "$INSTALL" nonexistent-skill "$tmp" 2>/dev/null; then
  echo "FAIL: install of non-existent skill did not error"; exit 1
fi

echo "OK"
