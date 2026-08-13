# Design — `review-go-mistakes` skill

**Date:** 2026-08-12
**Status:** Approved for planning
**Repo:** `skillz` (this repository will host multiple installable skills over time)

## 1. Purpose

Give Claude a repeatable procedure for reviewing Go code against every mistake in *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi, Manning, 2022). The skill produces a markdown report grouped by book category, written in ASD-STE100 Simplified Technical English.

## 2. Scope

- Covers all 100 mistakes from the book.
- Includes mistakes that Go linters (`go vet`, `staticcheck`, `golangci-lint`, `gosec`) already catch — the report is self-contained.
- Explicit invocation only. No auto-trigger.
- Report output only. No auto-fix, no PR comment posting in v1.

## 3. Repo layout

```
skillz/
├── README.md              # what this repo is + how to install skills
├── install.sh             # symlink a named skill into a target location
├── docs/
│   └── superpowers/
│       └── specs/         # design specs live here
└── skills/
    └── review-go-mistakes/
        ├── SKILL.md
        └── references/
            ├── code-and-project-organization.md
            ├── data-types.md
            ├── control-structures.md
            ├── strings.md
            ├── functions-and-methods.md
            ├── error-management.md
            ├── concurrency-foundations.md
            ├── concurrency-practice.md
            ├── standard-library.md
            ├── testing.md
            ├── optimizations.md
            └── production.md
```

Each skill is self-contained under `skills/<skill-name>/`. Adding a new skill later is a new folder under `skills/`.

The exact category filenames match the book's chapter titles. The list above is the working set; final names are locked in during implementation against the book's table of contents.

## 4. Skill structure

### 4.1 `SKILL.md`

Always loaded when Claude invokes the skill. Kept compact.

Contents:

- **Frontmatter** — `name`, `description`. The description is specific enough that Claude picks the skill for prompts like "review this Go code for common mistakes" or an explicit slash command.
- **When to use** — explicit invocation only.
- **Inputs** — the skill accepts one optional argument:
  - No argument → target is `git diff HEAD`, scoped to `*.go` files.
  - File path → that file (must end in `.go`).
  - Directory path → recursive walk of all `*.go` files under the directory. Standard ignores apply: `vendor/`, `.git/`, `testdata/`. User can override the ignore list.
  - PR number (`#123`) or PR URL → the diff is fetched with `gh pr diff`.
- **Workflow** — the six-step procedure in section 5.
- **Index of all 100 mistakes** — one line per mistake, grouped by category:
  ```
  #63 Not using errgroup for goroutine coordination [verify]
  ```
- **Output format spec** — the report structure in section 6.
- **Failure modes** — false-positive guardrails from section 5.6.
- **Language** — all content authored in ASD-STE100 Simplified Technical English.

### 4.2 `references/<category>.md`

Loaded on demand. One file per book chapter.

Each entry in the file has this shape:

```markdown
### #63 — Not using errgroup for goroutine coordination [verify]

**Pattern to look for:**
- Multiple goroutines started with `go func(){}()` coordinated only through `sync.WaitGroup`.
- Errors from goroutines are lost or collected through ad-hoc channels.
- No cancellation when one goroutine fails.

**Why this is a mistake:**
When one goroutine fails, the other goroutines continue to run. Error
propagation is difficult. No shared context can cancel the operation.

**Fix:**
Use `golang.org/x/sync/errgroup`. It captures the first error, cancels
through a shared context, and aggregates with `Wait()`.

**Before → After:**
[5–10 line code example]

**Related:** [[mistake-62-goroutine-lifecycle]], [[mistake-71-context-cancellation]]
```

### 4.3 Load pattern at review time

1. Claude reads `SKILL.md` (always).
2. Claude scans the target Go code and notes categories with plausible hits.
3. For each such category, Claude reads that `references/<category>.md`.
4. Categories with zero hits do not load their reference file.

## 5. Review workflow

### 5.1 Parse invocation argument

Resolve the target as described in section 4.1. If the resolved target contains no `.go` files, print a short message and stop.

### 5.2 Determine review scope

- For diffs: review changed lines plus enough surrounding context (usually the enclosing function) to judge patterns that depend on control flow, goroutine lifetime, and error propagation.
- For whole files: review the full file.
- List the exact files and paths covered at the top of the report.

### 5.3 First pass — categorize

Claude reads all target code. For each of the 12 categories, Claude records whether any patterns from the one-liner index in `SKILL.md` are plausibly present. The result is a shortlist: `{category → [suspect locations]}`.

### 5.4 Second pass — deep check per category

For each category on the shortlist:

1. Load `references/<category>.md`.
2. Re-examine each suspect against the detailed pattern description.
3. Discard suspects that do not match on close reading.
4. For each kept finding, collect: `file:line`, the offending code excerpt (≤10 lines), the mistake number, the reason it applies here, and the suggested fix.

### 5.5 Write the report

- Assemble the report in the format from section 6.
- Save to `go-review-<YYYY-MM-DD-HHMM>.md` in the current working directory. The timestamp prevents overwrites when the skill runs more than once in a session.
- Print the file path back to the user with a one-line summary (for example, "12 findings across 5 categories").

### 5.6 Guardrails

- Every finding cites `file:line` and quotes the offending code (≤10 lines).
- Every finding names the mistake number and category from the book.
- A finding that cannot cite specifics is dropped. Vague guidance ("consider reviewing goroutine safety") is not permitted.
- Within a category, findings are ordered by severity: correctness before concurrency safety, before performance, before style.

## 6. Report format

The output file uses this structure:

```markdown
# Go Code Review — 100 Go Mistakes

**Reviewed:** 2026-08-12 14:32
**Target:** git diff HEAD   (or: <files>, or: PR #123)
**Files scanned:** 8 .go files
**Findings:** 12 across 5 categories

---

## Summary

| Category                    | Findings |
|-----------------------------|----------|
| Concurrency (foundations)   | 4        |
| Error management            | 3        |
| Data types                  | 2        |
| Standard library            | 2        |
| Testing                     | 1        |

---

## Concurrency (foundations)

### #63 — Not using errgroup for goroutine coordination

**File:** `internal/fetcher/pool.go:42`

**Code:**
```go
[code excerpt, up to 10 lines]
```

**Why this is a mistake:**
[STE prose from the reference entry]

**Fix:**
[STE prose from the reference entry]

**Suggested rewrite:**
```go
[compact rewrite]
```

---

### #62 — Starting a goroutine without knowing when it stops
[next finding]
```

Rules:

- Categories with zero findings are omitted. No empty sections.
- Findings inside a category are ordered by severity (see section 5.6).
- Code excerpts are capped at 10 lines. Longer blocks are elided with an ellipsis.
- Every finding shows the mistake number, name, `file:line`, code, why, and fix.
- The footer notes the skill version and any paths skipped (for example, "`vendor/` was not scanned").

## 7. Language — ASD-STE100

All skill content — `SKILL.md`, every `references/<category>.md`, and the report Claude produces — is written in ASD-STE100 Simplified Technical English.

Key rules to apply:

- Use approved words from the STE dictionary.
- One word, one meaning. One part of speech per word.
- Active voice.
- Sentences no longer than 20 words for procedures, 25 words for descriptive text.
- Present tense preferred.
- No gerunds as nouns ("the process", not "the processing").
- Sequential steps for procedures.
- No idioms.

Authoring content in STE from the start (instead of relying on Claude to rewrite at review time) keeps report language consistent.

## 8. Content authoring plan

Day-one deliverables:

- `SKILL.md` — full workflow + index of all 100 mistakes as one-liners, each tagged `[verify]`.
- ~12 `references/<category>.md` files — one detailed entry per mistake, each tagged `[verify]`.

Total content volume: approximately 2,000–3,000 lines.

Category counts (working estimates, adjusted during implementation against the book's actual table of contents to sum to exactly 100):

1. Code and project organization (~9)
2. Data types (~8)
3. Control structures (~5)
4. Strings (~7)
5. Functions and methods (~7)
6. Error management (~8)
7. Concurrency: foundations (~9)
8. Concurrency: practice (~11)
9. Standard library (~9)
10. Testing (~10)
11. Optimizations (~12)
12. Production (~5)

Sourcing:

- Public knowledge of well-known Go pitfalls (blogs, talks, community documentation, the book's companion GitHub repo).
- Standard Go idioms and community conventions.
- No verbatim book text. Copyright is respected.

Confidence tagging:

- `[verify]` — draft is ready for use but has not been cross-checked against the book.
- `[verify][low-confidence]` — I am reconstructing from partial recall. Higher priority for user review.

If some mistakes cannot be reconstructed with confidence, the index lists only the mistakes that can be, and a note at the bottom names the gap. The skill does not invent mistakes to reach 100.

Post-launch verification workflow (owned by the user):

- Use the skill on real code.
- When a finding surfaces or a chapter is reread, cross-check the corresponding entry.
- Edit the entry as needed and remove the `[verify]` tag.
- Over time, the skill converges to fully verified content.

## 9. Installation mechanism

`install.sh` at the repo root. Approximate usage:

```bash
# Install a skill globally (into ~/.claude/skills/)
./install.sh review-go-mistakes

# Install into a specific project's .claude/skills/
./install.sh review-go-mistakes ~/Work/my-go-project

# List available skills
./install.sh --list

# Uninstall
./install.sh --uninstall review-go-mistakes
```

Behavior:

- Creates a symlink from `<target>/.claude/skills/<skill-name>` (or `~/.claude/skills/<skill-name>` for the global case) to `<skillz-repo>/skills/<skill-name>/`.
- Symlink (not copy) so edits in the `skillz` repo are picked up immediately.
- Prompts before overwriting if the target already exists.
- `--list` walks `skills/` and prints each folder name with the first-line description from its `SKILL.md`.

Size target: ~40–60 lines of bash.

## 10. Out of scope for v1

- Plugin or MCP packaging (the layout does not preclude it later).
- Version pinning (git tags can be added later if needed).
- Auto-fix or auto-apply.
- Posting findings as PR comments.
- Auto-trigger on Go files without explicit invocation.

## 11. Deliverables

1. `skills/review-go-mistakes/SKILL.md`
2. `skills/review-go-mistakes/references/*.md` (~12 files)
3. `install.sh`
4. `README.md` at repo root (brief: what the repo is + how to install skills)
