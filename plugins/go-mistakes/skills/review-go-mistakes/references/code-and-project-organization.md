# Code and project organization

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #1 — Unintended variable shadowing [verify]

**Pattern to look for:**
- A `:=` assignment inside an `if`, `for`, or other block that reuses an outer variable name.
- A variable set in an outer scope, then not read after a nested block that redeclares it.
- Error variables named `err` that get a new declaration inside an `if` block.

**Why this is a mistake:**
The inner `:=` creates a new local variable. The outer variable keeps its old value. The code compiles, but the outer variable does not get the update the author expected.

**Fix:**
Declare the outer variable first with `var`. Use plain `=` inside the nested block to assign to it, not `:=`.

**Before:**
```go
var client *Client
if config.UseTLS {
    client, err := newTLSClient()
    _ = err
    fmt.Println(client)
}
// client is still nil here
```

**After:**
```go
var client *Client
var err error
if config.UseTLS {
    client, err = newTLSClient()
    if err != nil {
        return err
    }
}
// client holds the new value here
```

**Related:** [[mistake-2-unnecessary-nested-code]]

---

### #2 — Unnecessary nested code [verify]

**Pattern to look for:**
- An `if` block that holds the main logic, followed by an `else` block.
- More than two levels of nested `if` statements in one function.
- A function where the happy path sits deep inside nested blocks.

**Why this is a mistake:**
Deep nesting hides the main flow of the function. The reader must track many open conditions at once. This raises the chance of a logic error.

**Fix:**
Return early on the error or exception case. Keep the happy path at the lowest indentation level.

**Before:**
```go
func process(v int) error {
    if v >= 0 {
        if v < 100 {
            return doWork(v)
        } else {
            return errors.New("too large")
        }
    } else {
        return errors.New("negative")
    }
}
```

**After:**
```go
func process(v int) error {
    if v < 0 {
        return errors.New("negative")
    }
    if v >= 100 {
        return errors.New("too large")
    }
    return doWork(v)
}
```

**Related:** [[mistake-1-unintended-variable-shadowing]]

---

### #3 — Misusing init functions [verify]

**Pattern to look for:**
- A package-level `func init()` that opens a database connection, reads a file, or calls a network service.
- An `init` function that can fail and calls `log.Fatal` or `panic`.
- Package-level state set by `init` that later code depends on for correct order.

**Why this is a mistake:**
An `init` function runs before `main` and cannot return an error to the caller. A failure inside `init` forces a crash or a panic, and the caller gets no chance to handle it.

**Fix:**
Move setup code into an explicit function, such as `New` or `Setup`. Call it from `main` and check the returned error.

**Before:**
```go
var db *sql.DB

func init() {
    var err error
    db, err = sql.Open("postgres", dsn)
    if err != nil {
        log.Fatal(err)
    }
}
```

**After:**
```go
func NewDB(dsn string) (*sql.DB, error) {
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        return nil, err
    }
    return db, nil
}
// main calls NewDB and checks the error
```

**Related:** [[mistake-1-unintended-variable-shadowing]]

---

### #4 — Overusing getters and setters [verify]

**Pattern to look for:**
- Methods named `GetX` that only return a field with no other logic.
- A `SetX` method that only assigns a field with no validation or side effect.
- A struct where every field has a matching getter and setter pair.

**Why this is a mistake:**
A plain getter or setter adds code but no behavior. Go does not need this pattern for encapsulation, since exported fields already give direct access when that is the goal.

**Fix:**
Export the field directly when no extra logic applies. Add a method only when it does real work, such as validation or a computed value.

**Before:**
```go
type Account struct {
    balance int
}

func (a *Account) GetBalance() int {
    return a.balance
}

func (a *Account) SetBalance(v int) {
    a.balance = v
}
```

**After:**
```go
type Account struct {
    Balance int
}

func (a *Account) Withdraw(amount int) error {
    if amount > a.Balance {
        return errors.New("insufficient funds")
    }
    a.Balance -= amount
    return nil
}
```

**Related:** [[mistake-5-interface-pollution]]

---

### #5 — Interface pollution [verify]

**Pattern to look for:**
- An interface defined in the same package as its single concrete implementation.
- An interface with many methods, created before a second implementation exists.
- A package that exports an interface type for every exported struct.

**Why this is a mistake:**
An interface created ahead of need adds an abstraction layer with no consumer that requires it. Extra abstraction makes the code harder to read and adds an indirection cost with no benefit.

**Fix:**
Write the concrete type first. Add an interface only when a second implementation exists or a consumer package needs one.

**Before:**
```go
package store

type Store interface {
    Get(id string) (string, error)
    Set(id, value string) error
}

type memStore struct{ data map[string]string }

func (m *memStore) Get(id string) (string, error) { /* ... */ return "", nil }
func (m *memStore) Set(id, value string) error     { /* ... */ return nil }
```

**After:**
```go
package store

type Store struct{ data map[string]string }

func (m *Store) Get(id string) (string, error) { /* ... */ return "", nil }
func (m *Store) Set(id, value string) error     { /* ... */ return nil }
// a consumer package defines its own interface if it needs one
```

**Related:** [[mistake-6-interface-on-the-wrong-side]], [[mistake-7-returning-interfaces]]

---

### #6 — Interface on the wrong side [verify]

**Pattern to look for:**
- An interface type declared in the same package as the code that implements it.
- A producer package that exports both the interface and its only implementation.
- Consumer code that imports an interface from the producer package instead of declaring its own.

**Why this is a mistake:**
An interface declared on the producer side forces every consumer to depend on that shape, even when each consumer needs a different subset of methods. This couples the producer to assumptions about future callers.

**Fix:**
Declare the interface in the consumer package. Keep the producer package exporting only the concrete type.

**Before:**
```go
package sender

type Sender interface {
    Send(msg string) error
}

type EmailSender struct{}

func (e *EmailSender) Send(msg string) error { return nil }
```

**After:**
```go
package sender

type EmailSender struct{}

func (e *EmailSender) Send(msg string) error { return nil }

// consumer package:
// type sender interface { Send(msg string) error }
```

**Related:** [[mistake-5-interface-pollution]]

---

### #7 — Returning interfaces [verify]

**Pattern to look for:**
- A function signature that returns an interface type instead of a concrete struct or pointer.
- A constructor named `New...` with an interface as its return type.
- Only one concrete type ever satisfies the returned interface.

**Why this is a mistake:**
A returned interface hides the concrete type from the caller and limits it to the interface's methods. This blocks the caller from later changes and adds indirection with no clear benefit.

**Fix:**
Return the concrete type from the function. Let the caller declare an interface if it needs one for a dependency it consumes.

**Before:**
```go
func NewWriter(path string) (io.Writer, error) {
    f, err := os.Create(path)
    if err != nil {
        return nil, err
    }
    return f, nil
}
```

**After:**
```go
func NewWriter(path string) (*os.File, error) {
    f, err := os.Create(path)
    if err != nil {
        return nil, err
    }
    return f, nil
}
```

**Related:** [[mistake-5-interface-pollution]], [[mistake-6-interface-on-the-wrong-side]]

---

### #8 — any says nothing [verify]

**Pattern to look for:**
- A function parameter or struct field typed as `any` or `interface{}` with no type check inside.
- A function that immediately type-asserts an `any` argument to one concrete type.
- Public API functions that accept `any` where a fixed set of types is the real requirement.

**Why this is a mistake:**
The `any` type carries no information about the accepted values. The compiler cannot catch a wrong argument type, so the check moves to runtime and the API becomes unclear.

**Fix:**
Use a concrete type, a defined set of types, or a generic type parameter with a constraint. Reserve `any` for cases where a value truly can hold anything, such as generic containers.

**Before:**
```go
func Sum(values []any) int {
    total := 0
    for _, v := range values {
        total += v.(int)
    }
    return total
}
```

**After:**
```go
func Sum(values []int) int {
    total := 0
    for _, v := range values {
        total += v
    }
    return total
}
```

**Related:** [[mistake-9-confused-about-generics]]

---

### #9 — Being confused about when to use generics [verify]

**Pattern to look for:**
- A generic function whose type parameter is used with only one concrete type at each call site.
- Repeated near-duplicate functions that differ only by parameter type, a candidate for one generic function.
- A generic type parameter with no constraint, where the body only needs common methods.

**Why this is a mistake:**
Generics add a layer of abstraction. Applied where a plain function or interface would work, generics make the code harder to read with no gain in reuse.

**Fix:**
Use generics only when the same logic must run across several types with no change in behavior. Otherwise, write a plain function or use an interface.

**Before:**
```go
func PrintInt(v int) {
    fmt.Println(v)
}

func PrintString(v string) {
    fmt.Println(v)
}
```

**After:**
```go
func Print[T any](v T) {
    fmt.Println(v)
}
```

**Related:** [[mistake-8-any-says-nothing]]

---

### #10 — Problems with type embedding [verify]

**Pattern to look for:**
- A struct that embeds another struct or interface only to reach its methods, with no real "is-a" relationship.
- An embedded type whose methods leak into the outer type's exported API by accident.
- A struct field that should stay private but becomes exported because embedding promotes it.

**Why this is a mistake:**
Embedding promotes all the methods and fields of the embedded type into the outer type. This can expose methods the author did not intend to export and can break when the embedded type changes.

**Fix:**
Use a named field and forward only the methods the outer type needs to expose. Reserve embedding for a true substitutable relationship.

**Before:**
```go
type Logger struct{ *log.Logger }

type Server struct {
    Logger
    addr string
}
// Server now exposes every *log.Logger method directly
```

**After:**
```go
type Server struct {
    logger *log.Logger
    addr   string
}

func (s *Server) Log(msg string) {
    s.logger.Println(msg)
}
```

**Related:** [[mistake-4-overusing-getters-and-setters]]

---

### #11 — Not using the functional options pattern [verify]

**Pattern to look for:**
- A constructor with many parameters, several of them optional or boolean flags.
- Multiple overloaded constructor names, such as `NewClient`, `NewClientWithTimeout`, `NewClientWithTLS`.
- Callers that pass zero values or `nil` just to skip an optional parameter.

**Why this is a mistake:**
A long parameter list is hard to read at the call site and breaks every caller when a new parameter is added. Overloaded constructor names do not scale as the number of options grows.

**Fix:**
Define an option type as a function that modifies a config struct. Accept a variadic list of options in the constructor.

**Before:**
```go
func NewClient(host string, timeout time.Duration, retries int, useTLS bool) *Client {
    return &Client{host: host, timeout: timeout, retries: retries, useTLS: useTLS}
}

c := NewClient("api.example.com", 0, 0, false)
```

**After:**
```go
type Option func(*Client)

func WithTimeout(d time.Duration) Option {
    return func(c *Client) { c.timeout = d }
}

func NewClient(host string, opts ...Option) *Client {
    c := &Client{host: host}
    for _, opt := range opts {
        opt(c)
    }
    return c
}
```

**Related:** [[mistake-4-overusing-getters-and-setters]]

---
