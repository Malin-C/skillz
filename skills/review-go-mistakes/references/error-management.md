# Error management

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #44 — Panicking [verify]

**Pattern to look for:**
- A `panic` call raised for a condition an ordinary caller can meet, such as bad input or a missing file.
- Library code that calls `panic` instead of returning an `error` from an exported function.
- No `recover` call anywhere near the `panic`, so the whole program stops.

**Why this is a mistake:**
A `panic` stops the normal flow of the program and, with no `recover`, ends the process. An expected condition, such as bad input, is a case for an `error` return value, not a program stop.

**Fix:**
Return an `error` value for a condition a caller can expect and handle. Reserve `panic` for a state that marks a fault the program cannot recover from, such as a broken invariant at startup.

**Before:**
```go
func divide(a, b int) int {
    if b == 0 {
        panic("division by zero")
    }
    return a / b
}
// a caller cannot recover from a bad input without a recover call
```

**After:**
```go
func divide(a, b int) (int, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
}
```

**Related:** [[mistake-49-not-handling-an-error]]

---

### #45 — Ignoring when to wrap an error [verify]

**Pattern to look for:**
- An error returned as-is across many function layers, with no added context on where it happened.
- A wrap with `fmt.Errorf("%w", err)` at every layer, so the message grows long and repeats detail.
- No stated rule in the codebase for when a layer wraps and when it passes an error through.

**Why this is a mistake:**
An error passed through with no context leaves a caller with no clue where it happened. An error wrapped at every layer produces a long, repetitive message and can leak internal detail across an API boundary.

**Fix:**
Wrap an error at a layer that adds useful context, such as the operation that failed. Pass an error through unwrapped when the layer adds no new information.

**Before:**
```go
func readConfig(path string) (Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return Config{}, err
    }
    // caller sees only "no such file or directory", no path or step
    return parse(data)
}
```

**After:**
```go
func readConfig(path string) (Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return Config{}, fmt.Errorf("read config at %s: %w", path, err)
    }
    return parse(data)
}
```

**Related:** [[mistake-51-not-using-errors-is-and-errors-as-after-go-1-13]]

---

### #46 — Comparing an error type inaccurately [verify]

**Pattern to look for:**
- A type assertion or type switch on an error value, such as `err.(*MyError)`, with no check for a wrapped chain.
- Code that fails to match a custom error type after the error passed through a `fmt.Errorf("%w", err)` wrap.
- A direct type comparison on an error that a lower layer may wrap before it returns.

**Why this is a mistake:**
A wrapped error hides the target type behind one or more layers. A plain type assertion checks only the outer value and misses a match that sits deeper in the chain.

**Fix:**
Use `errors.As` to test whether an error in the chain matches a given type. `errors.As` walks the chain through each `Unwrap` call.

**Before:**
```go
var myErr *MyError
if e, ok := err.(*MyError); ok {
    myErr = e
}
// misses a *MyError wrapped by an outer fmt.Errorf("%w", ...) call
```

**After:**
```go
var myErr *MyError
if errors.As(err, &myErr) {
    // matches a *MyError anywhere in the chain
    handle(myErr)
}
```

**Related:** [[mistake-47-comparing-an-error-value-inaccurately]], [[mistake-51-not-using-errors-is-and-errors-as-after-go-1-13]]

---

### #47 — Comparing an error value inaccurately [verify]

**Pattern to look for:**
- A direct `==` comparison between an error value and a sentinel error, such as `err == sql.ErrNoRows`.
- Code that fails to match a known sentinel error after the error passed through a wrap.
- No use of `errors.Is` where a sentinel error comparison happens.

**Why this is a mistake:**
A wrapped error hides the target sentinel value behind one or more layers. A plain `==` comparison checks only the outer value and misses a match that sits deeper in the chain.

**Fix:**
Use `errors.Is` to test whether an error in the chain matches a given sentinel value. `errors.Is` walks the chain through each `Unwrap` call.

**Before:**
```go
if err == sql.ErrNoRows {
    return nil, nil
}
// misses sql.ErrNoRows wrapped by an outer fmt.Errorf("%w", ...) call
```

**After:**
```go
if errors.Is(err, sql.ErrNoRows) {
    return nil, nil
}
```

**Related:** [[mistake-46-comparing-an-error-type-inaccurately]], [[mistake-51-not-using-errors-is-and-errors-as-after-go-1-13]]

---

### #48 — Handling the same error twice [verify]

**Pattern to look for:**
- A log call for an error at one layer, followed by a return of the same error, followed by another log call at a higher layer.
- Duplicate log lines in output for what traces back to one failure.
- No stated rule in the codebase for which layer logs an error and which layer only returns it.

**Why this is a mistake:**
An error logged at more than one layer produces duplicate entries for a single failure. The duplicate entries make logs noisy and harder to trace back to one root cause.

**Fix:**
Handle an error once: either log it at the layer that cannot pass it further, or wrap and return it. Do not do both at every layer.

**Before:**
```go
func process() error {
    if err := step(); err != nil {
        log.Println("step failed:", err)
        return err
        // caller logs this same error again
    }
    return nil
}
```

**After:**
```go
func process() error {
    if err := step(); err != nil {
        return fmt.Errorf("process: %w", err)
        // the top-level caller logs once, after the final return
    }
    return nil
}
```

**Related:** [[mistake-45-ignoring-when-to-wrap-an-error]]

---

### #49 — Not handling an error [verify]

**Pattern to look for:**
- An error return value assigned to `_` with no comment on why the error is safe to skip.
- A function call that returns an error, with the return value dropped entirely.
- A linter warning for an unchecked error return, left unaddressed.

**Why this is a mistake:**
A dropped error hides a failure from the rest of the program. The program proceeds on data or state that the failed call did not produce, and the fault surfaces later, far from its cause.

**Fix:**
Check every error return value. When an error is truly safe to skip, assign it to `_` with a comment that states why.

**Before:**
```go
data, _ := os.ReadFile(path)
// a missing or unreadable file leaves data empty, with no signal
process(data)
```

**After:**
```go
data, err := os.ReadFile(path)
if err != nil {
    return fmt.Errorf("read %s: %w", path, err)
}
process(data)
```

**Related:** [[mistake-44-panicking]], [[mistake-50-not-handling-defer-errors]]

---

### #50 — Not handling defer errors [verify]

**Pattern to look for:**
- A `defer f.Close()` call, or a similar deferred call, with the returned error dropped.
- A resource, such as a file or a network connection, closed only in a `defer` with no error check.
- A write operation whose error return matters, closed through a bare `defer` call.

**Why this is a mistake:**
A resource such as a file can fail to close or flush, and that failure can point to lost or corrupted data. A bare `defer f.Close()` drops this error, so the caller never learns of the failure.

**Fix:**
Wrap the deferred call in a closure that checks the error and reports it, for example by setting a named return value.

**Before:**
```go
func writeAll(path string, data []byte) error {
    f, err := os.Create(path)
    if err != nil {
        return err
    }
    defer f.Close()
    // a close failure after a successful write is never reported
    _, err = f.Write(data)
    return err
}
```

**After:**
```go
func writeAll(path string, data []byte) (err error) {
    f, cerr := os.Create(path)
    if cerr != nil {
        return cerr
    }
    defer func() {
        if cerr := f.Close(); cerr != nil && err == nil {
            err = fmt.Errorf("close: %w", cerr)
        }
    }()
    _, err = f.Write(data)
    return err
}
```

**Related:** [[mistake-49-not-handling-an-error]]

---

### #51 — Not using errors.Is and errors.As after Go 1.13 [verify]

**Pattern to look for:**
- A direct `==` comparison against a sentinel error, or a type assertion on a custom error type, in code targeting Go 1.13 or later.
- No `Unwrap` method on a custom error type that wraps an inner error.
- Error-handling code written before Go 1.13 and never updated to the `errors.Is` and `errors.As` style.

**Why this is a mistake:**
Go 1.13 added error wrapping through `%w` and the `errors.Is`, `errors.As`, and `errors.Unwrap` functions. Code that skips these functions and relies on `==` or a type assertion misses matches on any wrapped error in the chain.

**Fix:**
Use `errors.Is` for sentinel value checks and `errors.As` for type checks. Add an `Unwrap` method to a custom error type that wraps another error, so the chain stays walkable.

**Before:**
```go
type QueryError struct {
    Err error
}

func (e *QueryError) Error() string { return e.Err.Error() }
// no Unwrap method, so errors.Is and errors.As cannot see through it
```

**After:**
```go
type QueryError struct {
    Err error
}

func (e *QueryError) Error() string { return e.Err.Error() }
func (e *QueryError) Unwrap() error { return e.Err }
// errors.Is(err, sql.ErrNoRows) now matches through a *QueryError wrap
```

**Related:** [[mistake-46-comparing-an-error-type-inaccurately]], [[mistake-47-comparing-an-error-value-inaccurately]]

---
</content>
