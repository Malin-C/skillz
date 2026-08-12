# Testing

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #79 — Not categorizing tests [verify]

**Pattern to look for:**
- A single `go test ./...` run that mixes fast, isolated tests with tests that reach a database, a network service, or the file system.
- No build tag, no naming convention, and no separate `Makefile` or CI target to split test kinds apart.
- A CI pipeline that always runs the full test suite, with no fast path for local, per-commit checks.

**Why this is a mistake:**
Unit tests, integration tests, and end-to-end tests differ in speed and in what they depend on. When all tests run as one group, a developer cannot run only the fast unit tests during local work, and a slow or flaky integration test slows down or blocks every run.

**Fix:**
Split test kinds with a build tag, such as `//go:build integration`, or with a naming convention plus a short flag check. Give each kind its own `go test` invocation in the `Makefile` and in CI, so unit tests run on every commit and slower tests run on a separate schedule.

**Before:**
```go
func TestOrderTotal(t *testing.T) {
    total := computeTotal(items)
    // pure function, no external dependency
    if total != want {
        t.Errorf("got %d, want %d", total, want)
    }
}

func TestOrderSavesToDB(t *testing.T) {
    db := connectRealDatabase(t)
    // reaches a live database, runs in the same suite as the fast test above
    err := saveOrder(db, order)
    if err != nil {
        t.Fatal(err)
    }
}
```

**After:**
```go
//go:build integration

func TestOrderSavesToDB(t *testing.T) {
    db := connectRealDatabase(t)
    err := saveOrder(db, order)
    if err != nil {
        t.Fatal(err)
    }
}
// run with: go test -tags=integration ./...
// unit tests, with no tag, stay fast in the default run
```

**Related:** [[mistake-80-not-enabling-the-race-flag]], [[mistake-81-not-using-test-execution-modes]]

---

### #80 — Not enabling the `-race` flag [verify]

**Pattern to look for:**
- A `go test` command, in a local script or in CI, that runs with no `-race` flag.
- Concurrent code, such as goroutines that share a map or a struct field, tested with no race check.
- A bug report about a value that changes at random between test runs, with no clear cause in the test logic itself.

**Why this is a mistake:**
Go's race detector finds unsynchronized concurrent access to shared memory. A test suite that never runs with `-race` can pass every time in CI, while the same code corrupts data or panics under real concurrent load in production.

**Fix:**
Add `-race` to the `go test` command in CI, at least on one platform per pipeline run. Treat a race detector failure as a build-breaking error, not a warning to defer.

**Before:**
```bash
go test ./...
# a data race in a goroutine that writes to a shared map
# passes silently, since the race detector never runs
```

**After:**
```bash
go test -race ./...
# the race detector flags the unsynchronized write
# WARNING: DATA RACE ... previous write ... at ...
```

**Related:** [[mistake-79-not-categorizing-tests]]

---

### #81 — Not using test execution modes [verify]

**Pattern to look for:**
- A large test suite with no call to `t.Parallel()` in any test function, so every test runs one after another.
- A test suite that always runs in the same, fixed order, with tests that pass only because of that order.
- No use of the `-shuffle` flag to check whether tests depend on run order or on each other's side effects.

**Why this is a mistake:**
Tests that run in strict sequence, one at a time, waste time on a large suite when many tests do not share state. Tests that always run in the same order can also hide a hidden dependency between tests, where one test's side effect makes a later test pass.

**Fix:**
Call `t.Parallel()` in independent test functions to run them concurrently and cut suite time. Run `go test -shuffle=on` from time to time to catch tests that rely on a fixed run order or on leftover state from another test.

**Before:**
```go
func TestParseA(t *testing.T) {
    // no t.Parallel(), runs strictly after the previous test
    result := parse(inputA)
    assertValid(t, result)
}

func TestParseB(t *testing.T) {
    result := parse(inputB)
    assertValid(t, result)
}
```

**After:**
```go
func TestParseA(t *testing.T) {
    t.Parallel()
    result := parse(inputA)
    assertValid(t, result)
}

func TestParseB(t *testing.T) {
    t.Parallel()
    result := parse(inputB)
    assertValid(t, result)
}
// go test -shuffle=on ./... checks for order dependencies too
```

**Related:** [[mistake-79-not-categorizing-tests]], [[mistake-83-sleeping-in-tests]]

---

### #82 — Not using table-driven tests [verify]

**Pattern to look for:**
- Several test functions, such as `TestValidateEmpty`, `TestValidateTooLong`, `TestValidateBadFormat`, that each repeat the same setup and assertion logic with one input changed.
- Copy-pasted test bodies with only a literal value or two changed between them.
- A new test case added as a whole new function instead of a new row of data.

**Why this is a mistake:**
Repeated test functions that differ only in input and expected output duplicate the setup and assertion code many times over. A fix to the assertion logic then needs the same edit in every copy, and a missed copy leaves stale, inconsistent test logic behind.

**Fix:**
Collect the input and expected output pairs into a slice of structs, then loop over the slice with a single test body and a subtest per case through `t.Run`.

**Before:**
```go
func TestValidateEmpty(t *testing.T) {
    err := validate("")
    if err == nil {
        t.Error("want error for empty input")
    }
}

func TestValidateTooLong(t *testing.T) {
    err := validate(strings.Repeat("a", 100))
    if err == nil {
        t.Error("want error for long input")
    }
}
```

**After:**
```go
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"empty", "", true},
        {"too long", strings.Repeat("a", 100), true},
        {"valid", "ok", false},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("validate(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
        })
    }
}
```

**Related:** [[mistake-81-not-using-test-execution-modes]]

---

### #83 — Sleeping in tests [verify]

**Pattern to look for:**
- A call to `time.Sleep` in a test, placed before an assertion that checks the result of an asynchronous operation.
- A comment such as `// give it time to finish` next to a fixed sleep duration.
- A test that fails at random on a slow CI runner but passes on a fast local machine.

**Why this is a mistake:**
A fixed sleep duration is a guess about how long an asynchronous operation takes. A sleep that is too short leaves a flaky test that fails when the system runs slower than usual, and a sleep that is long enough to be safe wastes time on every run.

**Fix:**
Replace the sleep with a wait on a channel, a `sync.WaitGroup`, or a poll loop that checks the condition on a short interval with a bounded timeout, such as through `require.Eventually` or a hand-written loop with `context.WithTimeout`.

**Before:**
```go
func TestAsyncJobCompletes(t *testing.T) {
    startJob()
    time.Sleep(2 * time.Second)
    // guesses the job finished in time; flaky on a slow runner
    if !jobDone() {
        t.Fatal("job did not complete")
    }
}
```

**After:**
```go
func TestAsyncJobCompletes(t *testing.T) {
    done := startJob()
    select {
    case <-done:
        // proceeds as soon as the job signals completion
    case <-time.After(5 * time.Second):
        t.Fatal("job did not complete in time")
    }
}
```

**Related:** [[mistake-84-not-dealing-with-the-time-api-efficiently]]

---

### #84 — Not dealing with the `time` API efficiently [verify]

**Pattern to look for:**
- Business logic that calls `time.Now()` directly inside a function, with no way for a test to control the returned value.
- A test that asserts on a computed expiry or duration and must tolerate a small, unexplained margin of error to avoid flakiness.
- No interface or function type in the code that stands in for the clock.

**Why this is a mistake:**
Code that calls `time.Now()` directly ties its behavior to the real, ever-moving clock. A test for that code cannot set a fixed point in time, so the test must either accept a slack margin around the expected result or skip the time-dependent path.

**Fix:**
Inject the time source, such as through a `func() time.Time` field, a small clock interface, or a passed-in `time.Time` argument, so a test can supply a fixed value. Keep the direct `time.Now()` call only at the outermost layer that wires the real clock in.

**Before:**
```go
func isExpired(createdAt time.Time) bool {
    return time.Now().Sub(createdAt) > 24*time.Hour
    // time.Now() ties the check to the real clock, no fixed point for a test
}
```

**After:**
```go
type Clock func() time.Time

func isExpired(now Clock, createdAt time.Time) bool {
    return now().Sub(createdAt) > 24*time.Hour
}
// a test passes a fixed Clock: func() time.Time { return fixedTime }
```

**Related:** [[mistake-83-sleeping-in-tests]]

---

### #85 — Not using testing utilities [verify]

**Pattern to look for:**
- A test for an HTTP handler that spins up a real `net.Listener` on a live port instead of using `httptest.NewServer` or `httptest.NewRecorder`.
- A test for `io.Reader` or `io.Writer` code that exercises only the happy path, with no check for a short read, a delayed write, or an error mid-stream.
- Hand-written mock structs that reimplement behavior the standard library already provides through `httptest` or `iotest`.

**Why this is a mistake:**
The standard library ships tested, purpose-built helpers for common test scenarios. Code that skips these helpers either under-tests edge cases, such as partial reads, or spends effort on custom test infrastructure that duplicates what `net/http/httptest` and `testing/iotest` already do.

**Fix:**
Use `httptest.NewRecorder` and `httptest.NewServer` to test HTTP handlers and clients without a real network listener. Use `iotest.TestReader`, `iotest.ErrReader`, and similar helpers from `testing/iotest` to check `io.Reader` and `io.Writer` implementations against odd input.

**Before:**
```go
func TestHandler(t *testing.T) {
    ln, _ := net.Listen("tcp", ":0")
    // spins up a real listener just to test a handler function
    srv := &http.Server{Handler: myHandler}
    go srv.Serve(ln)
    defer srv.Close()
    resp, _ := http.Get("http://" + ln.Addr().String())
    // ...
}
```

**After:**
```go
func TestHandler(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/", nil)
    rec := httptest.NewRecorder()
    myHandler(rec, req)
    if rec.Code != http.StatusOK {
        t.Errorf("got status %d, want %d", rec.Code, http.StatusOK)
    }
}
```

**Related:** [[mistake-79-not-categorizing-tests]]

---

### #86 — Writing inaccurate benchmarks [verify]

**Pattern to look for:**
- A benchmark function whose result the compiler can discard, because the loop's output value is never used or stored outside the loop.
- Setup work, such as building a large input slice, placed inside the timed section of a `Benchmark` function with no `b.ResetTimer()` call after it.
- A benchmark that calls `b.RunParallel` with no clear reason, or one that never uses it where contention is the actual concern.

**Why this is a mistake:**
The Go compiler can eliminate a computation whose result nothing uses, so a benchmark loop can end up timing an empty operation instead of the real work. Setup code left inside the timed section adds a fixed cost to every benchmark result and skews the reported per-operation time.

**Fix:**
Store the loop's result in a package-level variable so the compiler cannot discard the computation. Call `b.ResetTimer()` right after one-time setup work, and reach for `b.RunParallel` only when the benchmark specifically checks behavior under concurrent load.

**Before:**
```go
func BenchmarkCompute(b *testing.B) {
    data := loadLargeFixture()
    // setup cost counted inside the timed section
    for i := 0; i < b.N; i++ {
        compute(data)
        // result discarded; the compiler may optimize the call away
    }
}
```

**After:**
```go
var result int

func BenchmarkCompute(b *testing.B) {
    data := loadLargeFixture()
    b.ResetTimer()
    var r int
    for i := 0; i < b.N; i++ {
        r = compute(data)
    }
    result = r
}
```

**Related:** [[mistake-84-not-dealing-with-the-time-api-efficiently]]

---

### #87 — Not using `t.Helper()` and other Go testing features [verify]

**Pattern to look for:**
- A shared assertion function, called from many tests, that reports failures with `t.Errorf` but never calls `t.Helper()`.
- A test suite that opens temporary files or servers and closes or removes them by hand in every test, instead of registering the cleanup with `t.Cleanup`.
- No use of `testing.F` fuzz targets on functions that parse or decode untrusted input, and no use of `t.Run` subtests to group related cases under one parent test.

**Why this is a mistake:**
A failure inside a helper function that skips `t.Helper()` reports the line inside the helper, not the line in the test that called it, which slows down debugging. Manual cleanup code, repeated in every test, is easy to forget on one new test, which leaves temporary resources behind and can leak state between test runs.

**Fix:**
Call `t.Helper()` at the top of any function that performs assertions or setup on behalf of a test. Register cleanup with `t.Cleanup` right after a resource opens, use `t.Run` to organize related cases as subtests, and use `testing.F` fuzz targets to explore parser and decoder edge cases the developer would not think to write by hand.

**Before:**
```go
func assertNoError(t *testing.T, err error) {
    // no t.Helper(); failures point at this line, not the caller
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
}

func TestOpen(t *testing.T) {
    f, err := os.Open("data.txt")
    assertNoError(t, err)
    // f.Close() must be remembered by hand in every test like this one
}
```

**After:**
```go
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
}

func TestOpen(t *testing.T) {
    f, err := os.Open("data.txt")
    assertNoError(t, err)
    t.Cleanup(func() { f.Close() })
}
```

**Related:** [[mistake-82-not-using-table-driven-tests]]

---
