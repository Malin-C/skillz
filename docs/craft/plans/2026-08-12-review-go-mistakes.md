# review-go-mistakes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use craft:subagent-driven-development (recommended) or craft:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the first skill in the `skillz` monorepo — a Go code review skill that checks source against all 100 mistakes from Harsanyi's book, writes findings to a category-grouped markdown report in ASD-STE100 English, and installs into any project via a small bash script.

**Architecture:** Skill lives at `skills/review-go-mistakes/`. `SKILL.md` is the always-loaded entry point (workflow + 100-mistake one-liner index). Detailed patterns live in `references/<category>.md`, loaded on demand. `install.sh` symlinks a named skill into a target `.claude/skills/` directory. A `validate.sh` script cross-checks the index against the reference entries during authoring.

**Tech Stack:** Markdown (skill files), Bash (install + validation), `bats` or plain bash test scripts for install-script tests.

**Spec:** `docs/craft/specs/2026-08-12-review-go-mistakes-design.md`

**Language rule (applies to all authored content):** All text in `SKILL.md`, every `references/*.md`, `README.md`, and any output the skill produces must follow ASD-STE100 Simplified Technical English:
- Approved words from the STE dictionary.
- One word, one meaning. One part of speech per word.
- Active voice.
- ≤20 words per procedural sentence, ≤25 per descriptive sentence.
- Present tense preferred.
- No gerunds as nouns ("the process", not "the processing").
- Sequential steps in procedures.
- No idioms.

---

## File Structure

**To create:**
- `README.md` — repo-root description + install instructions.
- `install.sh` — install/uninstall/list script.
- `tests/install.bats` — behavior tests for `install.sh`.
- `tests/validate-skill.sh` — schema check for a skill folder (SKILL.md + references consistency).
- `skills/review-go-mistakes/SKILL.md` — entry point.
- `skills/review-go-mistakes/references/code-and-project-organization.md`
- `skills/review-go-mistakes/references/data-types.md`
- `skills/review-go-mistakes/references/control-structures.md`
- `skills/review-go-mistakes/references/strings.md`
- `skills/review-go-mistakes/references/functions-and-methods.md`
- `skills/review-go-mistakes/references/error-management.md`
- `skills/review-go-mistakes/references/concurrency-foundations.md`
- `skills/review-go-mistakes/references/concurrency-practice.md`
- `skills/review-go-mistakes/references/standard-library.md`
- `skills/review-go-mistakes/references/testing.md`
- `skills/review-go-mistakes/references/optimizations.md`
- `skills/review-go-mistakes/references/production.md`

**To modify:** none (empty repo apart from spec + `.gitignore`).

---

## Task ordering rationale

1. **Foundations first** (Tasks 1–2) — repo scaffolding + a validation script we reuse for every reference file. This gives every later content task a "test" to pass.
2. **Installer with TDD** (Task 3) — the one piece of real code in the plan. `install.sh` has clear pass/fail behaviors.
3. **SKILL.md skeleton** (Task 4) — workflow, inputs, output format. No 100-mistake index yet.
4. **Reference files one per category** (Tasks 5–16, 12 tasks) — bulk of authoring. Each task follows the same pattern: confirm chapter mistakes → write entries → validate → commit.
5. **SKILL.md index populated** (Task 17) — assemble the one-liner index from all reference files.
6. **End-to-end install smoke test** (Task 18) — install to a temp location, verify structure, uninstall.
7. **README polish** (Task 19).

---

## Task 1: Repo scaffolding + top-level README skeleton

**Files:**
- Create: `README.md`
- Create: `skills/.gitkeep`
- Create: `tests/.gitkeep`

- [ ] **Step 1: Create the directory structure**

Run:
```bash
cd /Users/malin/Work/skillz
mkdir -p skills tests
touch skills/.gitkeep tests/.gitkeep
```

- [ ] **Step 2: Write the top-level README (STE-compliant)**

Write `README.md`:

````markdown
# skillz

A collection of custom skills for Claude Code. Each skill is self-contained under `skills/<skill-name>/` and can be installed into a Claude Code environment with `./install.sh`.

## Layout

```
skills/                         one directory per skill
install.sh                      installer script
tests/                          shared test scripts
docs/craft/specs/         design specs
docs/craft/plans/         implementation plans
```

## Install a skill

Global install (all projects):

```bash
./install.sh <skill-name>
```

Project install (single repo):

```bash
./install.sh <skill-name> /path/to/target/repo
```

List available skills:

```bash
./install.sh --list
```

Uninstall:

```bash
./install.sh --uninstall <skill-name>
```

## Skills

See individual skill folders under `skills/` for details.
````

- [ ] **Step 3: Commit**

```bash
cd /Users/malin/Work/skillz
git add README.md skills/.gitkeep tests/.gitkeep
git commit -m "Scaffold repo layout for skillz monorepo"
```

---

## Task 2: Schema validator for skill folders

**Files:**
- Create: `tests/validate-skill.sh`

**Purpose:** A bash script that checks a `skills/<name>/` folder for:
- `SKILL.md` exists and has frontmatter (`name:`, `description:` fields).
- Every mistake number in `SKILL.md`'s index (lines matching `#\d+`) has a matching heading in some `references/*.md` file.
- Every heading in `references/*.md` (matching `### #\d+`) appears in `SKILL.md`'s index.

- [ ] **Step 1: Write the failing test — validator against an empty skill folder**

Create `tests/test-validate-skill.sh`:

```bash
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
```

Make it executable: `chmod +x tests/test-validate-skill.sh`.

- [ ] **Step 2: Run the test to verify it fails (validator does not exist yet)**

Run: `./tests/test-validate-skill.sh`
Expected: FAIL with "validate-skill.sh: No such file or directory" or similar.

- [ ] **Step 3: Write the validator**

Create `tests/validate-skill.sh`:

```bash
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

# Frontmatter check: first line must be "---", must contain name: and description:
first=$(head -n 1 "$SKILL_DIR/SKILL.md")
if [ "$first" != "---" ]; then
  echo "error: SKILL.md missing frontmatter (first line must be ---)" >&2
  exit 1
fi
if ! grep -qE '^name:' "$SKILL_DIR/SKILL.md"; then
  echo "error: SKILL.md frontmatter missing 'name:'" >&2
  exit 1
fi
if ! grep -qE '^description:' "$SKILL_DIR/SKILL.md"; then
  echo "error: SKILL.md frontmatter missing 'description:'" >&2
  exit 1
fi

# Extract mistake numbers from the index in SKILL.md
# Format expected: "#123 Some title [verify]" or "#123 Some title"
index_nums=$(grep -oE '#[0-9]+' "$SKILL_DIR/SKILL.md" | sort -u || true)

# Extract mistake numbers from reference headings
ref_nums=""
if [ -d "$SKILL_DIR/references" ]; then
  ref_nums=$(grep -horE '^### #[0-9]+' "$SKILL_DIR/references"/*.md 2>/dev/null \
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
```

Make executable: `chmod +x tests/validate-skill.sh`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test-validate-skill.sh`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add tests/validate-skill.sh tests/test-validate-skill.sh
git commit -m "Add skill-folder schema validator"
```

---

## Task 3: `install.sh` with TDD

**Files:**
- Create: `install.sh`
- Create: `tests/test-install.sh`

**Behaviors to support:**
- `install.sh <skill>` → symlink `~/.claude/skills/<skill>` → `<repo>/skills/<skill>`.
- `install.sh <skill> <target>` → symlink `<target>/.claude/skills/<skill>` → `<repo>/skills/<skill>`.
- `install.sh --list` → prints "`<skill> — <description>`" per folder in `skills/`, reading the description from each `SKILL.md` frontmatter.
- `install.sh --uninstall <skill>` → removes the symlink from `~/.claude/skills/<skill>` (or with a target arg, from `<target>/.claude/skills/<skill>`).
- Prompts before overwriting an existing target link.
- Errors if the skill folder does not exist under `skills/`.

- [ ] **Step 1: Write the failing test**

Create `tests/test-install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL="$REPO_ROOT/install.sh"

tmp=$(mktemp -d)
trap "rm -rf $tmp" EXIT

# Set up a fake skill under skills/ so the tests do not depend on real content
fake="$REPO_ROOT/skills/_fake-test-skill"
mkdir -p "$fake"
cat > "$fake/SKILL.md" <<'EOF'
---
name: fake-test-skill
description: A fake skill used by install.sh tests
---
body
EOF
cleanup_fake() { rm -rf "$fake"; }
trap "rm -rf $tmp; cleanup_fake" EXIT

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
```

Make executable: `chmod +x tests/test-install.sh`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `./tests/test-install.sh`
Expected: FAIL with "install.sh: No such file or directory".

- [ ] **Step 3: Write `install.sh`**

Create `install.sh`:

```bash
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
  # Argument: target base dir (may be empty for global)
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

# Argument parsing
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
```

Make executable: `chmod +x install.sh`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test-install.sh`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add install.sh tests/test-install.sh
git commit -m "Add install.sh with install/list/uninstall behaviors"
```

---

## Task 4: `SKILL.md` skeleton (no 100-mistake index yet)

**Files:**
- Create: `skills/review-go-mistakes/SKILL.md`

**Notes:**
- The 100-mistake index is added in Task 17 after all reference files exist.
- The category list here uses the same 12 categories as the reference files.
- All text in STE.

- [ ] **Step 1: Create the skill folder**

Run:
```bash
mkdir -p /Users/malin/Work/skillz/skills/review-go-mistakes/references
```

- [ ] **Step 2: Write `SKILL.md`**

Create `skills/review-go-mistakes/SKILL.md`:

````markdown
---
name: review-go-mistakes
description: Reviews Go source code against the 100 mistakes from Harsanyi's "100 Go Mistakes and How to Avoid Them". Produces a markdown report grouped by book category. Invoke this skill for any Go code review, quality audit, or pre-merge check on `.go` files. Language of the report follows ASD-STE100 Simplified Technical English.
---

# review-go-mistakes

This skill reviews Go source code against the 100 mistakes from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi, Manning, 2022). It writes a markdown report to disk. All output text follows ASD-STE100 Simplified Technical English.

## When to use

Use this skill only when the user asks for it. The skill does not auto-trigger on Go files.

Triggers:
- The user says "review this Go code", "check this Go code for common mistakes", or a similar request.
- The user runs a slash command mapped to this skill.

## Input

The skill accepts one optional argument:

| Argument                  | Meaning                                                                 |
|---------------------------|-------------------------------------------------------------------------|
| (none)                    | Target is `git diff HEAD`, scoped to `*.go` files.                      |
| Path to a `.go` file      | Target is that single file.                                             |
| Path to a directory       | Target is all `*.go` files under that directory (recursive).            |
| PR number (`#123`)        | Target is the diff of that pull request, fetched with `gh pr diff 123`. |
| PR URL                    | Same as PR number.                                                      |

Directory scans skip these paths by default: `vendor/`, `.git/`, `testdata/`. The user can override the skip list.

If the resolved target contains no `.go` files, print a short message and stop.

## Workflow

Do these steps in order.

### Step 1 — Resolve the target

Apply the input rules above. Print the list of files to be scanned before you start the review.

### Step 2 — Determine review scope

- For diffs, review the changed lines plus the enclosing function of each change.
- For whole files, review the full file.

### Step 3 — First pass: categorize

Read all target code. For each of the 12 categories below, note whether any patterns from the one-liner index in section "Index of the 100 mistakes" plausibly appear. Keep an internal shortlist: `category → suspect locations`.

### Step 4 — Second pass: deep check per category

For each category on the shortlist:
1. Read `references/<category>.md`.
2. Compare each suspect against the detailed pattern.
3. Discard suspects that do not match.
4. For each kept finding, collect: `file:line`, code excerpt (≤10 lines), mistake number, reason it applies, suggested fix.

Do not load reference files for categories with no suspects.

### Step 5 — Write the report

- Structure the file per section "Report format" below.
- Save to `go-review-<YYYY-MM-DD-HHMM>.md` in the current working directory.
- Print the file path and a one-line summary (for example: "12 findings across 5 categories").

## Guardrails (false positive control)

- Every finding must cite `file:line` and quote the offending code (≤10 lines).
- Every finding must name the mistake number and category from the book.
- Drop any finding that cannot cite specifics. Vague guidance is not permitted.
- Within a category, order findings by severity: correctness first, then concurrency safety, then performance, then style.

## Categories

1. Code and project organization
2. Data types
3. Control structures
4. Strings
5. Functions and methods
6. Error management
7. Concurrency (foundations)
8. Concurrency (practice)
9. Standard library
10. Testing
11. Optimizations
12. Production

## Report format

```markdown
# Go Code Review — 100 Go Mistakes

**Reviewed:** <YYYY-MM-DD HH:MM>
**Target:** <arg>
**Files scanned:** <N> .go files
**Findings:** <N> across <C> categories

---

## Summary

| Category | Findings |
|----------|----------|
| ...      | ...      |

---

## <Category name>

### #<N> — <mistake name>

**File:** `<path>:<line>`

**Code:**
```go
<code, up to 10 lines>
```

**Why this is a mistake:**
<STE prose>

**Fix:**
<STE prose>

**Suggested rewrite:**
```go
<compact rewrite>
```

---
```

Rules:
- Omit categories with zero findings.
- Order findings within a category by severity.
- Code excerpts are capped at 10 lines. Longer blocks show an ellipsis.
- The footer lists the skill version and any paths that were skipped.

## Index of the 100 mistakes

<!-- This section is populated in Task 17 of the implementation plan. -->

## Language

Write all report text in ASD-STE100 Simplified Technical English. Key rules:
- Use approved STE dictionary words.
- One word, one meaning. One part of speech per word.
- Active voice.
- Sentences: ≤20 words for procedural, ≤25 words for descriptive.
- Present tense preferred.
- No gerunds as nouns.
- Sequential steps for procedures.
- No idioms.
````

- [ ] **Step 3: Commit**

```bash
cd /Users/malin/Work/skillz
git add skills/review-go-mistakes/SKILL.md
git commit -m "Add SKILL.md skeleton for review-go-mistakes"
```

---

## Reference file authoring — common template (applies to Tasks 5–16)

Each reference file has the shape below. Author every entry in STE.

**File header (top of each reference file):**

```markdown
# <Category name>

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.
```

**Entry shape:**

````markdown
### #<N> — <short name> [verify]

**Pattern to look for:**
- <bullet 1>
- <bullet 2>

**Why this is a mistake:**
<one to three STE sentences>

**Fix:**
<one to three STE sentences, name the standard remedy>

**Before:**
```go
<5–10 lines that show the mistake>
```

**After:**
```go
<5–10 lines that show the correct form>
```

**Related:** [[mistake-N-slug]], [[mistake-M-slug]]

---
````

**Steps used by every reference-file task:**

1. Create the file with the header.
2. For each mistake in the category, write the entry using the template.
3. Run `./tests/validate-skill.sh skills/review-go-mistakes` — expect the "orphan references" error (because the index in SKILL.md is empty until Task 17). This confirms the reference file is picked up. Task 17 flips this to a clean pass.
4. Commit the file.

**Confidence tags:**

- Default: `[verify]` on every entry.
- If the executor is unsure of the mistake name, category placement, or numbering, use `[verify][low-confidence]`.

**Mistake lists per category (from best-recall against the book's table of contents):**

The lists below are the executor's starting point. If the executor has access to the book's public TOC (marketing page, publisher summary, GitHub companion repo README), the executor may correct titles and reassign a mistake to a different category. Adjust final numbering so all reference files together cover exactly 100 unique mistake numbers.

---

## Task 5: `references/code-and-project-organization.md`

**Files:**
- Create: `skills/review-go-mistakes/references/code-and-project-organization.md`

**Mistakes in this category (approximately 11, numbers #1–#11):**

- Unintended variable shadowing
- Unnecessary nested code
- Misusing init functions
- Overusing getters and setters
- Interface pollution (defining interfaces on the producer side)
- Interface on the wrong side (should be consumer-side)
- Returning interfaces (instead of concrete types)
- `any` says nothing (overuse of empty interface)
- Being confused about when to use generics
- Not being aware of the possible problems with type embedding
- Not using the functional options pattern

- [ ] **Step 1: Create the file with header (see common template).**
- [ ] **Step 2: Write one entry per mistake using the entry shape (see common template). All in STE. Each entry tagged `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.**
  Expected: an "orphan references" error listing #1 through #11 (index is still empty). This confirms the file is picked up.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/code-and-project-organization.md
git commit -m "Add reference entries for code and project organization"
```

---

## Task 6: `references/data-types.md`

**Files:**
- Create: `skills/review-go-mistakes/references/data-types.md`

**Mistakes in this category (approximately 10, numbers #12–#21):**

- Creating confusion with octal literals
- Neglecting integer overflows
- Not understanding floating points
- Not understanding slice length vs. capacity
- Inefficient slice initialization
- Being confused about nil vs empty slices
- Not properly checking if a slice is empty
- Not making slice copies correctly
- Unexpected side effects using slice append
- Slices and memory leaks (retaining backing arrays)
- Inefficient map initialization
- Maps and memory leaks

- [ ] **Step 1: Create the file with the header shown in the "Reference file authoring — common template" section above.**
- [ ] **Step 2: Write one entry per mistake in the list above, using the entry shape from the common template. All text in STE. Each entry tagged `[verify]` (or `[verify][low-confidence]` when unsure).**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.**
  Expected: an "orphan references" error listing this file's mistake numbers. This confirms the file is picked up. Task 17 flips this to a clean pass.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/data-types.md
git commit -m "Add reference entries for data types"
```

---

## Task 7: `references/control-structures.md`

**Files:**
- Create: `skills/review-go-mistakes/references/control-structures.md`

**Mistakes in this category (approximately 6, numbers #30–#35 or nearby — check final numbering):**

- Ignoring how `range` copies elements
- Ignoring how arguments are evaluated in `range`
- Ignoring the impact of using pointer elements in `range` loops
- Making wrong assumptions during map iterations (ordering, insertion during iteration)
- Ignoring how `break` works with `switch`/`select` inside a loop
- Using `defer` inside a loop

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error listing this file's mistake numbers.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/control-structures.md
git commit -m "Add reference entries for control structures"
```

---

## Task 8: `references/strings.md`

**Files:**
- Create: `skills/review-go-mistakes/references/strings.md`

**Mistakes in this category (approximately 7):**

- Not understanding the concept of a rune
- Inaccurate string iteration
- Misusing trim functions (e.g. TrimLeft vs TrimPrefix)
- Under-optimized string concatenation
- Useless string conversions
- Substring and memory leaks (retaining full backing string)
- Passing a byte slice to a function that keeps a reference

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/strings.md
git commit -m "Add reference entries for strings"
```

---

## Task 9: `references/functions-and-methods.md`

**Files:**
- Create: `skills/review-go-mistakes/references/functions-and-methods.md`

**Mistakes in this category (approximately 7):**

- Not knowing which type of receiver to use (value vs pointer)
- Never using named result parameters
- Unintended side effects with named result parameters (naked returns hiding shadowing)
- Returning a nil receiver (typed nil vs untyped nil)
- Using a filename as a function input (should accept `io.Reader`)
- Ignoring how `defer` arguments and receivers are evaluated
- Misusing pointers to defer function calls

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/functions-and-methods.md
git commit -m "Add reference entries for functions and methods"
```

---

## Task 10: `references/error-management.md`

**Files:**
- Create: `skills/review-go-mistakes/references/error-management.md`

**Mistakes in this category (approximately 8):**

- Panicking (using panic for expected errors)
- Ignoring when to wrap an error
- Comparing error type inaccurately (using `==` instead of `errors.As`)
- Comparing an error value inaccurately (using `==` instead of `errors.Is`)
- Handling the same error twice
- Not handling an error
- Not handling `defer` errors (e.g. `defer f.Close()` swallows error)
- Not using `errors.Is` / `errors.As` after Go 1.13

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/error-management.md
git commit -m "Add reference entries for error management"
```

---

## Task 11: `references/concurrency-foundations.md`

**Files:**
- Create: `skills/review-go-mistakes/references/concurrency-foundations.md`

**Mistakes in this category (approximately 9):**

- Mixing up concurrency and parallelism
- Thinking concurrency is always faster
- Being puzzled about when to use channels vs mutexes
- Not understanding Go memory model / happens-before
- Creating goroutines without understanding when to stop them
- Not being careful with goroutines and loop variables
- Expecting deterministic behavior in select with multiple ready channels
- Not using notification channels correctly (send vs close semantics)
- Not using nil channels intentionally (nil channel disables a select case)

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/concurrency-foundations.md
git commit -m "Add reference entries for concurrency foundations"
```

---

## Task 12: `references/concurrency-practice.md`

**Files:**
- Create: `skills/review-go-mistakes/references/concurrency-practice.md`

**Mistakes in this category (approximately 11):**

- Providing a wrong channel size
- Forgetting about possible side effects with string formatting (formatting a mutex-holding struct in a log line)
- Creating data races with append on a shared slice
- Using mutexes inaccurately with slices and maps
- Misusing `sync.WaitGroup` (calling Add inside the goroutine)
- Forgetting about `sync.Cond`
- Not using `errgroup` for goroutine coordination
- Copying a `sync` type (mutex, WaitGroup) after first use
- Using `time.After` and leaking resources
- Common mistakes with `context.Context` (using Background where a parent exists, mishandling cancellation)
- Not being careful with select and channel closing

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/concurrency-practice.md
git commit -m "Add reference entries for concurrency practice"
```

---

## Task 13: `references/standard-library.md`

**Files:**
- Create: `skills/review-go-mistakes/references/standard-library.md`

**Mistakes in this category (approximately 9):**

- Providing a wrong time duration (mixing units)
- `time.After` and memory leaks
- Common JSON handling mistakes (type embedding + JSON tags, monotonic time in JSON, floating-point precision)
- Common SQL mistakes (forgetting `Rows.Close`, forgetting `Rows.Err`, using `db.Query` without `defer rows.Close()`)
- Not closing transient resources (HTTP response bodies, files)
- Forgetting the return statement after `http.Error`
- Using the default HTTP client (no timeout) and server
- Ignoring HTTP body handling (io.Copy to io.Discard)
- Concurrent map access without sync

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/standard-library.md
git commit -m "Add reference entries for standard library"
```

---

## Task 14: `references/testing.md`

**Files:**
- Create: `skills/review-go-mistakes/references/testing.md`

**Mistakes in this category (approximately 10):**

- Not categorizing tests (unit / integration / e2e without build tags)
- Not enabling the `-race` flag
- Not using test execution modes (parallel, shuffle)
- Not using table-driven tests
- Sleeping in tests (flakiness)
- Not dealing with the `time` API efficiently (no injection point)
- Not using testing utilities (`httptest`, `iotest`)
- Writing inaccurate benchmarks (compiler optimizations, timer reset, parallel benchmarks)
- Not exploring all Go testing features (fuzzing, subtests, cleanup, helpers)
- Not using `t.Helper()` in test helpers

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/testing.md
git commit -m "Add reference entries for testing"
```

---

## Task 15: `references/optimizations.md`

**Files:**
- Create: `skills/review-go-mistakes/references/optimizations.md`

**Mistakes in this category (approximately 12):**

- Not understanding CPU caches (cache lines, false sharing)
- Writing concurrent code that leads to false sharing
- Not taking into account instruction-level parallelism
- Not being aware of data alignment (struct field ordering)
- Not understanding stack vs heap
- Not knowing how to reduce allocations (sync.Pool, pre-allocated slices)
- Not relying on inlining
- Not using Go diagnostic tools (pprof, execution tracer)
- Not understanding how the garbage collector works
- Not understanding the impact of running Go inside Docker/K8s (GOMAXPROCS)
- Overusing pointers (pointer chasing, escape analysis)
- Being unaware of value copy costs vs pointer indirection costs

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/optimizations.md
git commit -m "Add reference entries for optimizations"
```

---

## Task 16: `references/production.md`

**Files:**
- Create: `skills/review-go-mistakes/references/production.md`

**Mistakes in this category (approximately 5):**

- Not exposing metrics (Prometheus, OpenTelemetry)
- Not enabling profiling endpoints (pprof) in production
- Not using structured logging
- Not handling graceful shutdown (context cancellation on SIGTERM)
- Not being aware of runtime configuration (GOGC, GOMAXPROCS, GOMEMLIMIT)

- [ ] **Step 1: Create the file with the header from the common template.**
- [ ] **Step 2: Write one entry per mistake using the common entry shape. STE + `[verify]`.**
- [ ] **Step 3: Run `./tests/validate-skill.sh skills/review-go-mistakes`.** Expected: orphan-references error.
- [ ] **Step 4: Commit.**

```bash
git add skills/review-go-mistakes/references/production.md
git commit -m "Add reference entries for production"
```

---

## Task 17: Populate the 100-mistake index in `SKILL.md`

**Files:**
- Modify: `skills/review-go-mistakes/SKILL.md` (replace the placeholder in the "Index of the 100 mistakes" section)

- [ ] **Step 1: Extract mistake headings from all reference files**

Run:
```bash
cd /Users/malin/Work/skillz
grep -hE '^### #' skills/review-go-mistakes/references/*.md | sort -t'#' -k2 -n
```

Expected: 100 lines, one per mistake. If the count is not 100, adjust reference files first (may require redistributing between categories or adding entries with `[verify][low-confidence]`).

- [ ] **Step 2: Format the index for `SKILL.md`**

For each category (in the order shown in section "Categories"), produce a block like:

```markdown
### Code and project organization
- #1 Unintended variable shadowing [verify]
- #2 Unnecessary nested code [verify]
- ...
```

- [ ] **Step 3: Replace the placeholder comment in `SKILL.md`**

Replace `<!-- This section is populated in Task 17 of the implementation plan. -->` with the assembled 12 blocks.

- [ ] **Step 4: Run the validator to confirm no orphans in either direction**

Run: `./tests/validate-skill.sh skills/review-go-mistakes`
Expected: `OK: skills/review-go-mistakes`

- [ ] **Step 5: Commit**

```bash
git add skills/review-go-mistakes/SKILL.md
git commit -m "Populate 100-mistake index in review-go-mistakes SKILL.md"
```

---

## Task 18: End-to-end install smoke test

**Purpose:** Confirm the real skill installs cleanly into both a temp target and (dry-run) the global location.

- [ ] **Step 1: Install into a temporary target**

Run:
```bash
cd /Users/malin/Work/skillz
tmp=$(mktemp -d)
./install.sh review-go-mistakes "$tmp"
ls -l "$tmp/.claude/skills/review-go-mistakes"
```

Expected: A symlink pointing to `/Users/malin/Work/skillz/skills/review-go-mistakes`.

- [ ] **Step 2: Verify SKILL.md is reachable via the symlink**

Run:
```bash
cat "$tmp/.claude/skills/review-go-mistakes/SKILL.md" | head -20
```

Expected: The frontmatter with `name: review-go-mistakes`.

- [ ] **Step 3: Verify the validator passes on the installed copy**

Run: `./tests/validate-skill.sh "$tmp/.claude/skills/review-go-mistakes"`
Expected: `OK`

- [ ] **Step 4: Uninstall and confirm the symlink is gone**

Run:
```bash
./install.sh --uninstall review-go-mistakes "$tmp"
ls "$tmp/.claude/skills/" || true
rm -rf "$tmp"
```

Expected: No symlink for `review-go-mistakes`, no error.

- [ ] **Step 5: Confirm `--list` shows the skill**

Run: `./install.sh --list`
Expected output contains: `review-go-mistakes — Reviews Go source code against the 100 mistakes...`

- [ ] **Step 6: No commit — this is a manual smoke test with no code changes**

If any step fails, open a follow-up task and fix in place.

---

## Task 19: README polish

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a "Skills" section listing `review-go-mistakes` with a one-line description in STE**

Append under the "## Skills" section:

```markdown
### review-go-mistakes

Reviews Go source code against the 100 mistakes from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi, Manning, 2022). Produces a markdown report grouped by book category. Language of the report follows ASD-STE100 Simplified Technical English.

Install:

```bash
./install.sh review-go-mistakes                 # global
./install.sh review-go-mistakes /path/to/repo   # single project
```

See `skills/review-go-mistakes/SKILL.md` for full details.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "List review-go-mistakes in top-level README"
```

---

## Definition of done

- [ ] `./tests/test-validate-skill.sh` passes.
- [ ] `./tests/test-install.sh` passes.
- [ ] `./tests/validate-skill.sh skills/review-go-mistakes` passes.
- [ ] `skills/review-go-mistakes/SKILL.md` indexes exactly 100 mistakes across 12 categories.
- [ ] Every entry in every `references/*.md` follows the entry template and is tagged `[verify]` (or `[verify][low-confidence]` for uncertain entries).
- [ ] All authored text follows ASD-STE100.
- [ ] `install.sh review-go-mistakes <tmp>` installs cleanly; `--uninstall` reverses it; `--list` shows the skill.
- [ ] `README.md` mentions the skill and shows install commands.
