# Concurrency (practice)

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #61 — Providing a wrong channel size [verify]

**Pattern to look for:**
- A channel created with `make(chan T)` where a sender must not block on a fast-producer, slow-consumer path.
- A buffered channel with a fixed size chosen with no stated reason, such as `make(chan T, 100)`.
- Code that treats an unbuffered channel and a buffered channel as interchangeable.

**Why this is a mistake:**
An unbuffered channel makes every send block until a receiver is ready, which is the correct choice for a pure signal or a handoff. A buffered channel with an arbitrary size can hide a slow consumer for a while and then block anyway, or waste memory holding values no one reads for a long stretch. Neither problem shows up until load grows.

**Fix:**
Default to an unbuffered channel for synchronization. Choose a buffer size only for a known, bounded reason, such as a fixed number of workers, and write down that reason next to the `make` call.

**Before:**
```go
ch := make(chan int, 100)
// 100 picked with no analysis; may still block under load,
// or hold 100 stale values that no one has read yet
for _, v := range values {
    ch <- v
}
```

**After:**
```go
// unbuffered: each send waits for a worker to be ready
ch := make(chan int)
go func() {
    for _, v := range values {
        ch <- v
    }
    close(ch)
}()
```

**Related:** [[mistake-54-being-puzzled-about-when-to-use-channels-vs-mutexes]]

---

### #62 — Forgetting about possible side effects with string formatting [verify]

**Pattern to look for:**
- A call to `fmt.Sprintf`, `fmt.Println`, or a similar formatting function on a struct that embeds a `sync.Mutex` or another `sync` type.
- A `String()` method defined on a type that also exposes a `Lock`/`Unlock` pair, called while the same lock may be held elsewhere.
- Logging or debug code that formats a shared struct with no check for a lock field inside it.

**Why this is a mistake:**
The `fmt` package uses reflection to walk a struct's fields when no `String()` method exists, and this walk can call `String()` on the struct itself if the struct's method set includes it. When that method locks the same mutex the formatting call reaches through reflection, or when the struct changes concurrently while a formatting call reads it with no lock, the result ranges from a data race to a deadlock.

**Fix:**
Do not format a struct that holds a `sync.Mutex` or another `sync` type directly. Write an explicit `String()` method that locks the mutex before it reads the guarded fields, or format only a snapshot copy taken under the lock.

**Before:**
```go
type Counter struct {
    mu    sync.Mutex
    count int
}
c := &Counter{}
// reflection walks mu too; a concurrent Lock() call races this read
fmt.Println(c)
```

**After:**
```go
func (c *Counter) String() string {
    c.mu.Lock()
    defer c.mu.Unlock()
    return fmt.Sprintf("count=%d", c.count)
}
fmt.Println(c)
```

**Related:** [[mistake-68-copying-a-sync-type-after-first-use]]

---

### #63 — Creating data races with append on a shared slice [verify]

**Pattern to look for:**
- The same slice variable passed to more than one goroutine, with `append` called on it from more than one of them.
- A parent slice with spare capacity, sliced into per-goroutine views that each still call `append`.
- No mutex or channel around a slice write reachable from more than one goroutine.

**Why this is a mistake:**
`append` can write into the slice's backing array in place when capacity allows, and it always reads and updates the slice header's length. Two goroutines that call `append` on views of the same backing array, or that share one slice variable, race on both the array contents and the header, even when each goroutine appears to work with its "own" slice.

**Fix:**
Give each goroutine an independent backing array, sized so no `append` call can touch another goroutine's region, or guard every append to the shared slice with a mutex. Merge per-goroutine results after all goroutines finish.

**Before:**
```go
var result []int
var wg sync.WaitGroup
for _, v := range values {
    wg.Add(1)
    go func(v int) {
        defer wg.Done()
        // concurrent append on one shared slice: a data race
        result = append(result, v*v)
    }(v)
}
wg.Wait()
```

**After:**
```go
var mu sync.Mutex
var result []int
var wg sync.WaitGroup
for _, v := range values {
    wg.Add(1)
    go func(v int) {
        defer wg.Done()
        sq := v * v
        mu.Lock()
        result = append(result, sq)
        mu.Unlock()
    }(v)
}
wg.Wait()
```

**Related:** [[mistake-20-unexpected-side-effects-using-slice-append]], [[mistake-64-using-mutexes-inaccurately-with-slices-and-maps]]

---

### #64 — Using mutexes inaccurately with slices and maps [verify]

**Pattern to look for:**
- A struct field of slice or map type, with a mutex declared next to it but locked only around some of the accesses.
- A getter method that returns the slice or map field itself, taken while the lock is held, and handed to a caller that reads it after the lock releases.
- Read access to a shared slice or map with no `RLock`/`Lock` at all, next to write access that does lock.

**Why this is a mistake:**
A mutex protects a field only while every access, read and write alike, goes through the lock. Returning the shared slice or map value itself, rather than a copy, hands the caller a reference that keeps changing after the lock releases, so the caller reads unguarded data even though the method looked correct.

**Fix:**
Lock around every read and every write to the guarded field, including reads. Return a copy of the slice or map from an accessor method taken while the lock is held, not the shared value itself.

**Before:**
```go
type Store struct {
    mu    sync.Mutex
    items []string
}
func (s *Store) Items() []string {
    s.mu.Lock()
    defer s.mu.Unlock()
    return s.items
    // caller now holds a reference to the live, shared slice
}
```

**After:**
```go
func (s *Store) Items() []string {
    s.mu.Lock()
    defer s.mu.Unlock()
    out := make([]string, len(s.items))
    copy(out, s.items)
    return out
}
```

**Related:** [[mistake-63-creating-data-races-with-append-on-a-shared-slice]], [[mistake-54-being-puzzled-about-when-to-use-channels-vs-mutexes]]

---

### #65 — Misusing sync.WaitGroup [verify]

**Pattern to look for:**
- A `wg.Add(1)` call placed inside the goroutine it counts, instead of before the `go` statement that launches it.
- A `wg.Wait()` call that starts to run before every `Add` call it depends on has completed.
- A loop that launches goroutines with no fixed count of `Add` calls made ahead of the loop's `go` statements.

**Why this is a mistake:**
`Add` and `Wait` race when `Add` runs inside the goroutine, because the scheduler may run `Wait` before the goroutine starts and calls `Add`. `Wait` can then return before all goroutines have registered, and the caller proceeds as if every task finished when some may not have even started.

**Fix:**
Call `wg.Add(1)` in the parent goroutine, immediately before the matching `go` statement, never inside the launched goroutine. Call `wg.Done()`, typically deferred, as the first action inside the goroutine.

**Before:**
```go
var wg sync.WaitGroup
for _, v := range values {
    go func(v int) {
        wg.Add(1)
        // Wait may already have returned by the time Add runs here
        defer wg.Done()
        process(v)
    }(v)
}
wg.Wait()
```

**After:**
```go
var wg sync.WaitGroup
for _, v := range values {
    wg.Add(1)
    go func(v int) {
        defer wg.Done()
        process(v)
    }(v)
}
wg.Wait()
```

**Related:** [[mistake-68-copying-a-sync-type-after-first-use]], [[mistake-67-not-using-errgroup-for-goroutine-coordination]]

---

### #66 — Forgetting about sync.Cond [verify]

**Pattern to look for:**
- A goroutine that polls a shared condition in a tight loop with `time.Sleep` between checks, guarded by a mutex.
- Custom code that reimplements a wait-for-condition-then-wake pattern with a channel closed and recreated over and over.
- A one-to-many notification need, where more than one waiting goroutine must wake on the same state change, solved with a `chan struct{}` sized for only one receiver.

**Why this is a mistake:**
A closed channel notifies every waiter once, but the pattern falls apart when the condition can become true and false again, since a channel cannot reopen. Polling with `time.Sleep` wastes CPU and adds latency between the state change and the moment a waiter notices it. `sync.Cond` exists for exactly this case: wait on a condition guarded by a lock, and wake one or all waiters on a change, with no busy loop.

**Fix:**
Use `sync.Cond` with `Wait`, `Signal`, and `Broadcast` when goroutines must block until a condition tied to shared, mutex-guarded state becomes true, especially when the condition can flip more than once.

**Before:**
```go
for {
    mu.Lock()
    ready := queueReady
    mu.Unlock()
    if ready {
        break
    }
    time.Sleep(10 * time.Millisecond)
    // busy-waits and adds up to 10ms of needless latency
}
```

**After:**
```go
cond := sync.NewCond(&mu)
mu.Lock()
for !queueReady {
    cond.Wait()
}
mu.Unlock()
// a producer calls cond.Broadcast() or cond.Signal() after setting queueReady
```

**Related:** [[mistake-59-not-using-notification-channels-correctly]]

---

### #67 — Not using errgroup for goroutine coordination [verify]

**Pattern to look for:**
- Several goroutines launched to do related work, each able to fail, with a hand-rolled `sync.WaitGroup` plus a separate shared variable or channel to collect the first error.
- No cancellation of the remaining goroutines when one of them returns an error.
- Manual `context.WithCancel` plumbing next to a `sync.WaitGroup`, built by hand to reach what `errgroup` already provides.

**Why this is a mistake:**
A plain `sync.WaitGroup` has no built-in way to carry an error back from a goroutine or to stop sibling goroutines once one fails. Code that reimplements this by hand tends to race on the shared error variable, or it forgets to cancel the remaining work, so goroutines keep running past the point where their result no longer matters.

**Fix:**
Use `golang.org/x/sync/errgroup` for a group of goroutines that share a common fate: any one's error is enough to cancel the rest through the group's context, and `Wait` returns the first non-nil error safely.

**Before:**
```go
var wg sync.WaitGroup
var mu sync.Mutex
var firstErr error
for _, url := range urls {
    wg.Add(1)
    go func(url string) {
        defer wg.Done()
        if err := fetch(url); err != nil {
            mu.Lock()
            if firstErr == nil {
                firstErr = err
            }
            mu.Unlock()
            // sibling goroutines keep running with no cancellation
        }
    }(url)
}
wg.Wait()
```

**After:**
```go
g, ctx := errgroup.WithContext(context.Background())
for _, url := range urls {
    url := url
    g.Go(func() error {
        return fetch(ctx, url)
    })
}
if err := g.Wait(); err != nil {
    return err
}
```

**Related:** [[mistake-65-misusing-sync-waitgroup]], [[mistake-70-common-mistakes-with-context-context]]

---

### #68 — Copying a sync type after first use [verify]

**Pattern to look for:**
- A struct that embeds or holds a `sync.Mutex`, `sync.WaitGroup`, or another `sync` type, passed by value to a function or assigned to a new variable.
- A method with a value receiver on a struct that contains a `sync` type.
- A slice or map of structs that hold a `sync` type, where an element gets copied out by value.

**Why this is a mistake:**
Every type in the `sync` package carries internal state, such as a lock word or a wait counter, that must stay a single, shared instance across every goroutine that uses it. A copy, made by value assignment, a value receiver, or a copy out of a slice, starts its own independent state disconnected from the original, so a lock taken on the copy does not exclude a goroutine still holding the original.

**Fix:**
Hold a `sync` type by pointer, or embed it in a struct that is itself always passed by pointer. Run `go vet`, which flags a `sync.Mutex` or similar type copied by value.

**Before:**
```go
type Safe struct {
    mu    sync.Mutex
    count int
}
func increment(s Safe) {
    // s is a copy: this locks a different mutex than the caller's
    s.mu.Lock()
    defer s.mu.Unlock()
    s.count++
}
```

**After:**
```go
func increment(s *Safe) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.count++
}
```

**Related:** [[mistake-65-misusing-sync-waitgroup]], [[mistake-62-forgetting-about-possible-side-effects-with-string-formatting]]

---

### #69 — Using time.After and leaking resources [verify]

**Pattern to look for:**
- A `time.After(d)` call inside a `select` that runs inside a `for` loop, with no cap on how many times the loop repeats.
- A long-running loop where the timeout branch of a `select` is rarely the one that fires.
- No reused `time.Timer` in a loop that needs a repeated timeout against the same duration.

**Why this is a mistake:**
`time.After` allocates a new `time.Timer` on every call and that timer's underlying channel stays allocated until it fires, however far in the future that is. A `select` inside a loop that calls `time.After` on each pass, and that usually takes some other branch, builds up one live timer per iteration, and none of them free their resources until each one's full duration elapses.

**Fix:**
Create one `time.NewTimer` or `time.NewTicker` outside the loop and reuse it, resetting it with `Reset` as needed, or call `Stop` on a timer once its result is no longer needed. Reserve `time.After` for a `select` that runs once, not one inside a loop.

**Before:**
```go
for {
    select {
    case msg := <-ch:
        handle(msg)
    case <-time.After(time.Minute):
        // a fresh timer, and a fresh leaked resource, every iteration
        return
    }
}
```

**After:**
```go
timer := time.NewTimer(time.Minute)
defer timer.Stop()
for {
    select {
    case msg := <-ch:
        handle(msg)
    case <-timer.C:
        return
    }
}
```

**Related:** [[mistake-56-creating-goroutines-without-understanding-when-to-stop-them]]

---

### #70 — Common mistakes with context.Context [verify]

**Pattern to look for:**
- A call to `context.Background()` or `context.TODO()` made deep inside a call chain where a request-scoped `context.Context` already exists and could be passed down instead.
- A goroutine started with a parent's `context.Context` that outlives the request the context belongs to, with no separate lifetime given to the goroutine's own context.
- A cancellation function returned by `context.WithCancel`, `WithTimeout`, or `WithDeadline` that is never called, on any code path.

**Why this is a mistake:**
`context.Background()` carries no deadline and no cancellation signal, so code that reaches for it instead of the request's real context loses the ability to cancel that work when the request ends, and loses any values or deadlines the caller set. A cancel function left uncalled keeps the context's internal timer or goroutine alive until its deadline passes on its own, which leaks resources for however long that takes.

**Fix:**
Pass the caller's `context.Context` down through a call chain instead of starting a fresh `context.Background()` partway through. Always call the cancel function returned by a `With*` constructor, typically with `defer`, on every path, including error paths.

**Before:**
```go
func handle(ctx context.Context) {
    go func() {
        // detached from the caller's context and its cancellation
        process(context.Background())
    }()
}
func withTimeout() {
    ctx, cancel := context.WithTimeout(context.Background(), time.Second)
    // no defer cancel(): the timer stays alive until it fires on its own
    doWork(ctx)
}
```

**After:**
```go
func handle(ctx context.Context) {
    go func() {
        process(ctx)
    }()
}
func withTimeout() {
    ctx, cancel := context.WithTimeout(context.Background(), time.Second)
    defer cancel()
    doWork(ctx)
}
```

**Related:** [[mistake-56-creating-goroutines-without-understanding-when-to-stop-them]], [[mistake-67-not-using-errgroup-for-goroutine-coordination]]

---
</content>
