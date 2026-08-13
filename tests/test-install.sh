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

# Case 5: overwrite prompt - deny path (default N via empty input)
"$INSTALL" _fake-test-skill "$tmp" >/dev/null
rc=0
err=$(printf '\n' | "$INSTALL" _fake-test-skill "$tmp" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: overwrite deny path should exit non-zero"; exit 1
fi
if ! echo "$err" | grep -q "aborted"; then
  echo "FAIL: overwrite deny path did not print 'aborted': $err"; exit 1
fi
if [ ! -L "$link" ]; then
  echo "FAIL: symlink should still be present after declined overwrite"; exit 1
fi
target=$(readlink "$link")
if [ "$target" != "$fake" ]; then
  echo "FAIL: symlink target changed after declined overwrite: $target"; exit 1
fi

# Case 6: overwrite prompt - accept path
rc=0
out=$(printf 'y\n' | "$INSTALL" _fake-test-skill "$tmp") || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: overwrite accept path should exit 0"; exit 1
fi
if ! echo "$out" | grep -q "installed:"; then
  echo "FAIL: overwrite accept path did not print 'installed:': $out"; exit 1
fi
if [ ! -L "$link" ]; then
  echo "FAIL: symlink should be present after accepted overwrite"; exit 1
fi
target=$(readlink "$link")
if [ "$target" != "$fake" ]; then
  echo "FAIL: symlink target wrong after accepted overwrite: $target"; exit 1
fi

# cleanup for subsequent cases
"$INSTALL" --uninstall _fake-test-skill "$tmp" >/dev/null

# Case 7: uninstall refuses to touch a real (non-symlink) directory
realdir="$tmp/.claude/skills/realdir"
mkdir -p "$realdir"
echo "important data" > "$realdir/file.txt"
rc=0
err=$("$INSTALL" --uninstall realdir "$tmp" 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: uninstall of real directory should error"; exit 1
fi
if [ ! -d "$realdir" ] || [ ! -f "$realdir/file.txt" ]; then
  echo "FAIL: real directory or its contents were removed"; exit 1
fi

# Case 8: uninstall of a nonexistent skill exits 0 with 'not installed'
rc=0
out=$("$INSTALL" --uninstall does-not-exist "$tmp" 2>&1) || rc=$?
if [ "$rc" -ne 0 ]; then
  echo "FAIL: uninstall of nonexistent skill should exit 0"; exit 1
fi
if ! echo "$out" | grep -q "not installed"; then
  echo "FAIL: uninstall of nonexistent skill did not print 'not installed': $out"; exit 1
fi

# Case 9: invalid skill name with path traversal errors
rc=0
"$INSTALL" ../foo "$tmp" >/dev/null 2>&1 || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: install with path-traversal name should error"; exit 1
fi

# Case 10: non-interactive EOF on overwrite prompt aborts gracefully
"$INSTALL" _fake-test-skill "$tmp" >/dev/null
rc=0
err=$("$INSTALL" _fake-test-skill "$tmp" </dev/null 2>&1 >/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  echo "FAIL: EOF on overwrite prompt should exit non-zero"; exit 1
fi
if ! echo "$err" | grep -q "aborted"; then
  echo "FAIL: EOF on overwrite prompt did not print 'aborted': $err"; exit 1
fi
"$INSTALL" --uninstall _fake-test-skill "$tmp" >/dev/null

echo "OK"
