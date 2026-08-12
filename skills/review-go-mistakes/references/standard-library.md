# Standard library

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #71 — Providing a wrong time duration [verify]

**Pattern to look for:**
- A call such as `time.Sleep(1000)` or `time.NewTicker(5)`, with a bare integer where the API wants a `time.Duration`.
- A constant multiplied by the wrong unit, such as `time.Second * 1000` where the intent was one second, not a thousand.
- A duration value read from config or a flag, held as an `int`, passed straight into a `time` function with no unit conversion.

**Why this is a mistake:**
A `time.Duration` is a count of nanoseconds under the hood, but the Go compiler accepts a bare integer literal since it converts to the named type. Code that assumes the unit is seconds or milliseconds compiles clean, but the sleep, timeout, or tick fires after the wrong number of nanoseconds.

**Fix:**
Build every duration from the `time` constants, such as `time.Second`, `time.Millisecond`, or `time.Minute`, multiplied by the count. Never pass a bare integer literal to a function that wants a `time.Duration`.

**Before:**
```go
// intent: sleep for 1000 milliseconds (one second)
time.Sleep(1000)
// actual: 1000 nanoseconds, far short of one second
```

**After:**
```go
time.Sleep(1000 * time.Millisecond)
// the unit is explicit; the compiler checks the type too
```

**Related:** [[mistake-77-using-the-default-http-client-and-server]]

---

### #72 — Compiling a regular expression on every call [verify]

**Pattern to look for:**
- A call to `regexp.Compile` or `regexp.MustCompile` inside a function body, a request handler, or a loop body.
- A regular expression pattern that is a fixed string literal, built fresh on each call instead of once.
- Profile output that shows a hot path spending time inside `regexp.Compile`.

**Why this is a mistake:**
Compiling a regular expression parses the pattern and builds an internal matching engine, work that costs far more than running a match against an already-compiled expression. A fixed pattern rebuilt on every call repeats this cost for no benefit and slows the hot path.

**Fix:**
Compile a fixed pattern once, at package scope, with `regexp.MustCompile`. Reuse the resulting `*regexp.Regexp` value across calls; it is safe for concurrent use.

**Before:**
```go
func isValidID(id string) bool {
    re := regexp.MustCompile(`^[A-Z]{2}\d{4}$`)
    // recompiled on every call
    return re.MatchString(id)
}
```

**After:**
```go
var idPattern = regexp.MustCompile(`^[A-Z]{2}\d{4}$`)

func isValidID(id string) bool {
    return idPattern.MatchString(id)
}
```

**Related:** [[mistake-16-inefficient-slice-initialization]]

---

### #73 — Common JSON handling mistakes [verify]

**Pattern to look for:**
- An embedded struct type that also carries JSON tags on its own fields, where the outer struct expects those fields to marshal as its own top-level keys.
- A `time.Time` value serialized to JSON, then compared with `==` or `reflect.DeepEqual` against a value decoded back from that JSON.
- Numeric values that pass through `encoding/json` into a `float64` field or an `any` field, then get compared or summed as if they held exact integers.

**Why this is a mistake:**
Type embedding does not flatten JSON tags the way it flattens method sets; an embedded type with its own `json` tags can marshal to nested or unexpected keys. A `time.Time` value carries a monotonic reading that a JSON round trip strips, so the decoded value differs from the original under a strict comparison. And JSON numbers decode to `float64` by default, so a large integer can lose precision.

**Fix:**
Give an embedded type no JSON tag of its own when the fields must appear at the outer level, or embed it without JSON-specific naming conflicts. Compare `time.Time` values with `Equal`, not `==`. Decode large integers with `json.Number` or into an explicit integer field, not into `any`.

**Before:**
```go
type Event struct {
    Timestamp time.Time
}
data, _ := json.Marshal(Event{Timestamp: time.Now()})
var out Event
json.Unmarshal(data, &out)
// out.Timestamp == original fails: JSON strips the monotonic reading
```

**After:**
```go
type Event struct {
    Timestamp time.Time
}
data, _ := json.Marshal(Event{Timestamp: time.Now()})
var out Event
json.Unmarshal(data, &out)
fmt.Println(out.Timestamp.Equal(original.Timestamp))
```

**Related:** [[mistake-17-being-confused-about-nil-vs-empty-slices]], [[mistake-10-problems-with-type-embedding]]

---

### #74 — Common SQL mistakes [verify]

**Pattern to look for:**
- A call to `db.Query` or `Stmt.Query` with no matching `rows.Close()` call, on any return path.
- A `for rows.Next() { ... }` loop with no check of `rows.Err()` after the loop ends.
- Query parameters built by string concatenation or `fmt.Sprintf` instead of placeholder arguments passed to `Query` or `Exec`.

**Why this is a mistake:**
`Rows.Close` releases the underlying connection back to the pool; skip it, and connections leak until the pool runs dry. `rows.Next()` returns `false` both when the rows are exhausted and when an error interrupts the scan, so a loop that never checks `rows.Err()` can treat a failed read as a clean, complete result. Concatenated SQL text opens the door to SQL injection.

**Fix:**
Call `defer rows.Close()` right after a successful `Query` call, on every code path. Check `rows.Err()` right after the `for rows.Next()` loop. Pass values as placeholder arguments, never as concatenated text.

**Before:**
```go
rows, err := db.Query("SELECT id FROM users WHERE name = '" + name + "'")
if err != nil {
    return err
}
for rows.Next() {
    // ...
}
// no rows.Close(), no rows.Err() check
```

**After:**
```go
rows, err := db.Query("SELECT id FROM users WHERE name = ?", name)
if err != nil {
    return err
}
defer rows.Close()
for rows.Next() {
    // ...
}
if err := rows.Err(); err != nil {
    return err
}
```

**Related:** [[mistake-75-not-closing-transient-resources]]

---

### #75 — Not closing transient resources [verify]

**Pattern to look for:**
- An `http.Response` returned from `http.Get`, `http.Do`, or similar, with no `resp.Body.Close()` call.
- An `os.Open` or `os.Create` result with no matching `Close`, or a `Close` call placed after code that can return early.
- A `sql.Rows` value from a query, read without a `defer rows.Close()` right after the error check.

**Why this is a mistake:**
A response body, an open file, and a result-set cursor each hold on to an operating-system resource, such as a file descriptor or a network connection, until code calls `Close`. Skip the call, or place it after a path that returns early, and the resource stays held until the process runs out of descriptors or connections.

**Fix:**
Call `defer resp.Body.Close()`, `defer f.Close()`, or `defer rows.Close()` immediately after the error check that follows the call that opens the resource, before any other code runs.

**Before:**
```go
resp, err := http.Get(url)
if err != nil {
    return err
}
body, err := io.ReadAll(resp.Body)
// resp.Body.Close() never runs; the connection is never returned
```

**After:**
```go
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
body, err := io.ReadAll(resp.Body)
```

**Related:** [[mistake-74-common-sql-mistakes]], [[mistake-50-not-handling-defer-errors]]

---

### #76 — Forgetting the return statement after http.Error [verify]

**Pattern to look for:**
- A call to `http.Error(w, msg, code)` inside an HTTP handler, with more handler code below it that runs unconditionally.
- A validation check that writes an error response, with no `return` right after, followed by code that writes to `w` again.
- A handler that writes a second header or body after an error response already wrote one.

**Why this is a mistake:**
`http.Error` writes a status code and a body to the response writer, but it does not stop the handler function. Code that runs after it can write a second header, which Go logs as a warning and ignores, or write more body content that gets appended after the error message, confusing the client.

**Fix:**
Place a `return` statement directly after every `http.Error` call, unless the call is already the last statement on that path.

**Before:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        // falls through to the code below
    }
    processRequest(w, r)
}
```

**After:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
        return
    }
    processRequest(w, r)
}
```

**Related:** [[mistake-77-using-the-default-http-client-and-server]]

---

### #77 — Using the default HTTP client and server [verify]

**Pattern to look for:**
- A call to `http.Get`, `http.Post`, or `http.Head`, which use `http.DefaultClient` under the hood, in code that talks to an external service.
- A call to `http.ListenAndServe` with no `http.Server` value that sets read, write, or idle timeouts.
- No shutdown path for a running server, such as a call to `Server.Shutdown` on an interrupt signal.

**Why this is a mistake:**
`http.DefaultClient` sets no timeout, so a call that never gets a response can block a goroutine for good. `http.ListenAndServe` builds a server with no read, write, or idle timeouts either, so a slow or stalled client connection can hold a server goroutine open indefinitely. Neither path offers a way to drain in-flight requests before the process exits.

**Fix:**
Build an explicit `http.Client` with a `Timeout` field set for outgoing calls. Build an explicit `http.Server` with `ReadTimeout`, `WriteTimeout`, and `IdleTimeout` set, and call `Shutdown` on a termination signal.

**Before:**
```go
resp, err := http.Get(url)
// no timeout: a stalled server can block this call forever
```

**After:**
```go
client := &http.Client{Timeout: 10 * time.Second}
resp, err := client.Get(url)
```

**Related:** [[mistake-71-providing-a-wrong-time-duration]], [[mistake-76-forgetting-the-return-statement-after-http-error]]

---

### #78 — Concurrent map access without synchronization [verify]

**Pattern to look for:**
- A plain `map[K]V` value read from one goroutine and written from another, with no mutex or channel guarding the access.
- A shared map read and written inside goroutines launched from a loop, with no `sync.Mutex`, `sync.RWMutex`, or `sync.Map` in sight.
- Code that only sometimes takes a lock around map access, on some call paths but not others.

**Why this is a mistake:**
The built-in map type is not safe for concurrent use. A concurrent read and write, or two concurrent writes, on a plain map can corrupt its internal state; Go's race detector flags this, and an unguarded build can crash the process outright with a fatal, unrecoverable error.

**Fix:**
Guard a plain map's reads and writes with a `sync.Mutex` or `sync.RWMutex` held around every access. Use `sync.Map` instead when the access pattern is dominated by disjoint keys read and written from many goroutines with little contention.

**Before:**
```go
var cache = map[string]int{}

func increment(key string) {
    cache[key]++
    // no lock: concurrent calls race on the same map
}
```

**After:**
```go
var (
    cache = map[string]int{}
    mu    sync.Mutex
)

func increment(key string) {
    mu.Lock()
    defer mu.Unlock()
    cache[key]++
}
```

**Related:** [[mistake-64-using-mutexes-inaccurately-with-slices-and-maps]], [[mistake-54-being-puzzled-about-when-to-use-channels-vs-mutexes]]

---
