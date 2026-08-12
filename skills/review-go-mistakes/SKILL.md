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

### Code and project organization
- #1 Unintended variable shadowing [verify]
- #2 Unnecessary nested code [verify]
- #3 Misusing init functions [verify]
- #4 Overusing getters and setters [verify]
- #5 Interface pollution [verify]
- #6 Interface on the wrong side [verify]
- #7 Returning interfaces [verify]
- #8 any says nothing [verify]
- #9 Being confused about when to use generics [verify]
- #10 Problems with type embedding [verify]
- #11 Not using the functional options pattern [verify]

### Data types
- #12 Creating confusion with octal literals [verify]
- #13 Neglecting integer overflows [verify]
- #14 Not understanding floating points [verify]
- #15 Not understanding slice length and capacity [verify]
- #16 Inefficient slice initialization [verify]
- #17 Being confused about nil vs. empty slices [verify]
- #18 Not properly checking if a slice is empty [verify]
- #19 Not making slice copies correctly [verify]
- #20 Unexpected side effects using slice append [verify]
- #21 Slices and memory leaks [verify]
- #22 Inefficient map initialization [verify]
- #23 Maps and memory leaks [verify]

### Control structures
- #24 Ignoring that elements are copied in range loops [verify]
- #25 Ignoring how arguments are evaluated in range loops [verify]
- #26 Ignoring the impact of using pointer elements in range loops [verify]
- #27 Making wrong assumptions during map iterations [verify]
- #28 Ignoring how break works with switch and select [verify]
- #29 Using defer inside a loop [verify]

### Strings
- #30 Not understanding the concept of a rune [verify]
- #31 Inaccurate string iteration [verify]
- #32 Misusing trim functions [verify]
- #33 Under-optimized string concatenation [verify]
- #34 Useless string conversions [verify]
- #35 Substring and memory leaks [verify]
- #36 Passing a byte slice to a function that keeps a reference [verify][low-confidence]

### Functions and methods
- #37 Not knowing which type of receiver to use [verify]
- #38 Never using named result parameters [verify]
- #39 Unintended side effects with named result parameters [verify]
- #40 Returning a nil receiver [verify]
- #41 Using a filename as a function input [verify]
- #42 Ignoring how defer arguments and receivers are evaluated [verify]
- #43 Misusing pointers to defer function calls [verify]

### Error management
- #44 Panicking [verify]
- #45 Ignoring when to wrap an error [verify]
- #46 Comparing an error type inaccurately [verify]
- #47 Comparing an error value inaccurately [verify]
- #48 Handling the same error twice [verify]
- #49 Not handling an error [verify]
- #50 Not handling defer errors [verify]
- #51 Not using errors.Is and errors.As after Go 1.13 [verify]

### Concurrency (foundations)
- #52 Mixing up concurrency and parallelism [verify]
- #53 Thinking concurrency is always faster [verify]
- #54 Being puzzled about when to use channels vs mutexes [verify]
- #55 Not understanding the Go memory model and happens-before [verify]
- #56 Creating goroutines without understanding when to stop them [verify]
- #57 Not being careful with goroutines and loop variables [verify]
- #58 Expecting deterministic behavior in select with multiple ready channels [verify]
- #59 Not using notification channels correctly [verify]
- #60 Not using nil channels intentionally [verify]

### Concurrency (practice)
- #61 Providing a wrong channel size [verify]
- #62 Forgetting about possible side effects with string formatting [verify]
- #63 Creating data races with append on a shared slice [verify]
- #64 Using mutexes inaccurately with slices and maps [verify]
- #65 Misusing sync.WaitGroup [verify]
- #66 Forgetting about sync.Cond [verify]
- #67 Not using errgroup for goroutine coordination [verify]
- #68 Copying a sync type after first use [verify]
- #69 Using time.After and leaking resources [verify]
- #70 Common mistakes with context.Context [verify]

### Standard library
- #71 Providing a wrong time duration [verify]
- #72 Compiling a regular expression on every call [verify]
- #73 Common JSON handling mistakes [verify]
- #74 Common SQL mistakes [verify]
- #75 Not closing transient resources [verify]
- #76 Forgetting the return statement after http.Error [verify]
- #77 Using the default HTTP client and server [verify]
- #78 Concurrent map access without synchronization [verify]

### Testing
- #79 Not categorizing tests [verify]
- #80 Not enabling the `-race` flag [verify]
- #81 Not using test execution modes [verify]
- #82 Not using table-driven tests [verify]
- #83 Sleeping in tests [verify]
- #84 Not dealing with the `time` API efficiently [verify]
- #85 Not using testing utilities [verify]
- #86 Writing inaccurate benchmarks [verify]
- #87 Not using `t.Helper()` and other Go testing features [verify]

### Optimizations
- #88 Not understanding CPU caches [verify]
- #89 Writing concurrent code that leads to false sharing [verify]
- #90 Not being aware of data alignment [verify]
- #91 Not understanding stack vs heap [verify]
- #92 Not knowing how to reduce allocations [verify]
- #93 Not using Go diagnostic tools [verify]
- #94 Not understanding how the garbage collector works [verify]
- #95 Not understanding the impact of running Go inside Docker and Kubernetes [verify]

### Production
- #96 Not exposing metrics [verify]
- #97 Not enabling profiling endpoints in production [verify]
- #98 Not using structured logging [verify]
- #99 Not handling graceful shutdown [verify]
- #100 Not being aware of runtime configuration [verify]

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
