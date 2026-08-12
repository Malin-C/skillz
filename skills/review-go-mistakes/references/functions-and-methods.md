# Functions and methods

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #37 — Not knowing which type of receiver to use [verify]

**Pattern to look for:**
- A type with some methods on a value receiver and other methods on a pointer receiver, with no consistent rule.
- A method that changes a field of the receiver, declared with a value receiver.
- A large struct type passed as a value receiver on every method, with no need to share state.

**Why this is a mistake:**
A value receiver method works on a copy of the value, so a change made inside it does not reach the caller. Mixed receiver types on one type also confuse callers about whether a value satisfies an interface.

**Fix:**
Use a pointer receiver when the method must change the receiver, when the receiver holds a field that must not be copied (such as a `sync.Mutex`), or when the receiver is large. Use a value receiver for small types with no need for changes. Keep the receiver type consistent across a type's methods.

**Before:**
```go
type Counter struct {
    count int
}

func (c Counter) Increment() {
    c.count++
}

func main() {
    c := Counter{}
    c.Increment()
    fmt.Println(c.count) // still 0
}
```

**After:**
```go
type Counter struct {
    count int
}

func (c *Counter) Increment() {
    c.count++
}

func main() {
    c := Counter{}
    c.Increment()
    fmt.Println(c.count) // 1
}
```

**Related:** [[mistake-40-returning-a-nil-receiver]]

---

### #38 — Never using named result parameters [verify]

**Pattern to look for:**
- A function signature with several return values of the same type, with no names, that leaves callers to infer meaning from position.
- A function that implements an interface method, where the interface declares named results as documentation.
- Godoc output for a function where the return values carry no explanation.

**Why this is a mistake:**
Unnamed result parameters give a reader no clue about the meaning of each return value, beyond its type. This raises the risk that a caller mixes up the order of returned values, most of all when several results share one type.

**Fix:**
Name result parameters when the name adds clarity beyond the type, such as for two or more values of the same type. Skip names when the meaning is already clear, such as a lone `error` return.

**Before:**
```go
func getCoordinates(address string) (float64, float64, error) {
    // ...
    return lat, lng, nil
}
// the signature does not tell the caller which float is which
```

**After:**
```go
func getCoordinates(address string) (lat, lng float64, err error) {
    // ...
    return lat, lng, nil
}
// the signature itself documents the two return values
```

**Related:** [[mistake-39-unintended-side-effects-with-named-result-parameters]]

---

### #39 — Unintended side effects with named result parameters [verify]

**Pattern to look for:**
- A `defer` statement inside a function with named result parameters, that assigns to the named result.
- A naked `return` statement in a function with named results, where a local variable of the same name also exists in an inner scope.
- A named result parameter reused as a working variable through a long function body, so its role as the return value stays unclear.

**Why this is a mistake:**
A named result parameter is a variable in scope for the whole function body. Code that shadows it in an inner block, or a naked `return` that runs before a deferred assignment, can return a value the author did not intend.

**Fix:**
Use named result parameters mainly for documentation or for a deferred function that must set the result, such as error wrapping. Avoid naked returns in long functions. Check that no inner scope shadows the named result.

**Before:**
```go
func compute(x int) (result int, err error) {
    if x < 0 {
        result, err := 0, errors.New("negative")
        // := creates new local vars, shadows the named results
        return result, err
    }
    return x * 2, nil
}
// the shadowed err never reaches the caller
```

**After:**
```go
func compute(x int) (result int, err error) {
    if x < 0 {
        result, err = 0, errors.New("negative")
        // = assigns to the named results, no shadowing
        return result, err
    }
    return x * 2, nil
}
```

**Related:** [[mistake-38-never-using-named-result-parameters]], [[mistake-1-unintended-variable-shadowing]]

---

### #40 — Returning a nil receiver [verify]

**Pattern to look for:**
- A function that returns an interface type, with one return path that gives back a typed `nil` pointer.
- A `== nil` check on an error or interface value returned from a function that can return a typed nil pointer.
- A custom error type built with a pointer receiver, returned through the `error` interface.

**Why this is a mistake:**
An interface value is nil only when both its type and its value are nil. A typed nil pointer stored in an interface produces a non-nil interface value, so a `== nil` check on that interface fails even though the pointer itself is nil.

**Fix:**
Return the interface type as a plain `nil` when there is no error or value, instead of returning a typed nil pointer through the interface. Avoid storing a possibly-nil concrete pointer directly in a variable of interface type.

**Before:**
```go
func process() *MyError {
    return nil
}

func run() error {
    var err *MyError = process()
    return err // wraps a nil *MyError in a non-nil error interface
}

func main() {
    if run() != nil {
        fmt.Println("error occurred") // prints, though process() returned nil
    }
}
```

**After:**
```go
func process() *MyError {
    return nil
}

func run() error {
    if err := process(); err != nil {
        return err
    }
    return nil // returns a true nil error interface
}
```

**Related:** [[mistake-37-not-knowing-which-type-of-receiver-to-use]]

---

### #41 — Using a filename as a function input [verify]

**Pattern to look for:**
- A function parameter of type `string` that holds a file path, used only to open and read the file inside the function.
- A function that reads test data or configuration through `os.Open` on a parameter, with no other way for a caller to supply the data.
- Unit tests for such a function that write a temporary file to disk just to run the read path.

**Why this is a mistake:**
A function that takes a filename can read only from the local filesystem. This limits reuse to disk-backed sources, and it forces tests to create real files instead of passing data directly.

**Fix:**
Accept an `io.Reader` parameter instead of a filename. The caller opens the file, or supplies any other reader, such as a buffer or a network stream, and the function stays independent of the data source.

**Before:**
```go
func countLines(filename string) (int, error) {
    f, err := os.Open(filename)
    if err != nil {
        return 0, err
    }
    defer f.Close()
    return countLinesFromReader(f)
}
// works only with an on-disk file
```

**After:**
```go
func countLines(r io.Reader) (int, error) {
    scanner := bufio.NewScanner(r)
    count := 0
    for scanner.Scan() {
        count++
    }
    return count, scanner.Err()
}
// works with a file, a buffer, or any other io.Reader
```

**Related:** [[mistake-42-ignoring-how-defer-arguments-and-receivers-are-evaluated]]

---

### #42 — Ignoring how defer arguments and receivers are evaluated [verify]

**Pattern to look for:**
- A `defer` call with a function argument that is a variable that changes value later in the same function.
- A `defer` call on a method with a value receiver, where the receiver's fields change after the `defer` statement runs.
- Log or cleanup code inside a `defer` call, meant to report a value's final state, but written as a plain function call rather than a closure.

**Why this is a mistake:**
Go evaluates a deferred function's arguments and its receiver at the point where the `defer` statement runs, not at the point where the deferred call executes. Code that expects the deferred call to see a later value instead captures the value from the `defer` point.

**Fix:**
Wrap the deferred call in a closure when it must read a value's state at the time the function returns, not at the time `defer` runs.

**Before:**
```go
func process() {
    status := "started"
    defer fmt.Println("status:", status)
    status = "done"
}
// prints "status: started", not "status: done"
```

**After:**
```go
func process() {
    status := "started"
    defer func() { fmt.Println("status:", status) }()
    status = "done"
}
// the closure reads status at return time, prints "status: done"
```

**Related:** [[mistake-43-misusing-pointers-to-defer-function-calls]], [[mistake-29-using-defer-inside-a-loop]]

---

### #43 — Misusing pointers to defer function calls [verify]

**Pattern to look for:**
- A `defer` call passed a pointer argument, with the pointed-to value read only after the deferred call runs.
- Code that relies on `defer` to capture a pointer's target value at defer time, though the target changes before the function returns.
- A mix of pointer-argument defers and closure defers in the same codebase, with no clear rule for which to use.

**Why this is a mistake:**
Go fixes a deferred call's pointer argument at defer time, but the pointer itself, not its target, is what gets fixed. The value behind the pointer can still change before the deferred call runs, so the call can report a value the author did not expect.

**Fix:**
Pass a pointer to a deferred call only when a later read of the pointed-to value is the intent. Use a closure that copies the value at defer time when the exact value at that point must be reported.

**Before:**
```go
func process() {
    n := 1
    p := &n
    defer fmt.Println("value:", *p)
    // *p is read only when the deferred call runs, not now
    n = 2
}
// prints "value: 2", not the value at the defer statement
```

**After:**
```go
func process() {
    n := 1
    v := n
    defer fmt.Println("value:", v)
    // v is copied at defer time, unaffected by later changes to n
    n = 2
}
// prints "value: 1"
```

**Related:** [[mistake-42-ignoring-how-defer-arguments-and-receivers-are-evaluated]]

---
</content>
