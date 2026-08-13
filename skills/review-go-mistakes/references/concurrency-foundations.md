# Concurrency (foundations)

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #52 — Mixing up concurrency and parallelism [verify]

**Pattern to look for:**
- Comments or names that use "concurrent" and "parallel" as the same word.
- Code that adds goroutines to a task and expects the CPU-bound work to run faster with no check on `GOMAXPROCS` or core count.
- A design that treats concurrency as the goal, instead of a structure that parallelism can use when the runtime allows it.

**Why this is a mistake:**
Concurrency is a way to structure a program as independent parts. Parallelism is the execution of separate parts at the same instant, on separate cores. A concurrent structure does not by itself run any faster; it only opens the door for parallel execution when the runtime and hardware allow it.

**Fix:**
State the goal first. Structure code concurrently when the task splits into independent parts. Rely on the Go scheduler and available cores for parallel execution, and do not assume one property gives you the other.

**Before:**
```go
// "I added goroutines, so this is parallel now"
func process(items []int) {
    for _, item := range items {
        go compute(item)
        // no wait, no result collection, and on one core
        // this never runs two computations at the same instant
    }
}
```

**After:**
```go
// concurrent structure; parallel execution depends on GOMAXPROCS
func process(items []int) {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func(it int) {
            defer wg.Done()
            compute(it)
        }(item)
    }
    wg.Wait()
}
```

**Related:** [[mistake-53-thinking-concurrency-is-always-faster]]

---

### #53 — Thinking concurrency is always faster [verify]

**Pattern to look for:**
- A sequential function rewritten with goroutines and channels with no benchmark to back up the change.
- Concurrent code applied to a small input size or a task with heavy coordination cost between goroutines.
- No comparison between the concurrent version and the plain sequential version.

**Why this is a mistake:**
Goroutines, channels, and synchronization all carry a cost: scheduling, context switches, and memory. On a small input, or where coordination between goroutines is high, this cost can outweigh any gain, and the concurrent version runs slower than the sequential one.

**Fix:**
Benchmark the concurrent version against the sequential version with realistic input sizes before you commit to the change. Use `testing.B` and the `-race` and `-bench` flags together.

**Before:**
```go
func sumConcurrent(nums []int) int {
    // fixed cost of goroutines and a channel, applied to 4 numbers
    ch := make(chan int)
    for _, n := range nums {
        go func(v int) { ch <- v * v }(n)
    }
    total := 0
    for range nums {
        total += <-ch
    }
    return total
}
```

**After:**
```go
func sum(nums []int) int {
    total := 0
    for _, n := range nums {
        total += n * n
    }
    return total
}
// use sumConcurrent only past a size where a benchmark shows a gain
```

**Related:** [[mistake-52-mixing-up-concurrency-and-parallelism]]

---

### #54 — Being puzzled about when to use channels vs mutexes [verify]

**Pattern to look for:**
- A `sync.Mutex` guarding a value that one goroutine hands off to another goroutine, with no further shared state.
- A channel used only to protect one shared counter or map that many goroutines read and write.
- No stated reason in the code or comments for the choice between a channel and a mutex.

**Why this is a mistake:**
A channel fits ownership transfer, a signal, or coordination between goroutines. A mutex fits protection of shared state that many goroutines read and write in place. Using the wrong tool adds needless complexity or blocks a pattern the right tool would make simple.

**Fix:**
Use a channel to pass a value's ownership from one goroutine to another, or to signal an event. Use a mutex to guard shared state that stays in place and that several goroutines access at once.

**Before:**
```go
// a channel used only to serialize access to one counter
ch := make(chan struct{}, 1)
func increment() {
    ch <- struct{}{}
    counter++
    <-ch
}
```

**After:**
```go
var mu sync.Mutex
func increment() {
    mu.Lock()
    defer mu.Unlock()
    counter++
}
```

**Related:** [[mistake-59-not-using-notification-channels-correctly]]

---

### #55 — Not understanding the Go memory model and happens-before [verify]

**Pattern to look for:**
- A value written by one goroutine and read by another, with no channel, mutex, or other synchronization between the write and the read.
- Reliance on `time.Sleep` to "make sure" a goroutine has finished writing a value.
- A comment that claims a variable is "set before" another goroutine reads it, with no memory barrier to back up the claim.

**Why this is a mistake:**
The Go memory model states that a read observes a write only when a happens-before relation links them. Without a channel operation, a mutex, `sync/atomic`, or `sync.Once` between a write and a read across goroutines, the read can observe a stale or partial value, even on hardware where the bug never shows up in a quick test.

**Fix:**
Use a channel send/receive, a mutex lock/unlock, `sync/atomic`, or `sync.Once` to build an explicit happens-before edge between a write and a read that cross goroutines. Do not rely on timing or `time.Sleep`.

**Before:**
```go
var ready bool
var data int
go func() {
    data = 42
    ready = true
    // no synchronization; the other goroutine may see ready
    // as true before it sees the write to data
}()
for !ready {
}
fmt.Println(data)
```

**After:**
```go
var data int
done := make(chan struct{})
go func() {
    data = 42
    close(done)
}()
<-done
fmt.Println(data)
```

**Related:** [[mistake-57-not-being-careful-with-goroutines-and-loop-variables]]

---

### #56 — Creating goroutines without understanding when to stop them [verify]

**Pattern to look for:**
- A `go func() { ... }()` call with a loop that has no exit condition tied to the caller's lifetime.
- A goroutine that reads from a channel the caller may never close or send to again.
- No `context.Context`, done channel, or other signal passed to a long-running goroutine.

**Why this is a mistake:**
A goroutine that never receives a stop signal keeps running, and the memory and resources it holds stay allocated for the life of the program. This is a goroutine leak, and it grows worse each time the leaking code path runs.

**Fix:**
Pass a `context.Context` or a done channel to every goroutine whose lifetime extends past its creation. Check it inside the goroutine's loop and return when it fires.

**Before:**
```go
func start() {
    go func() {
        for {
            // no exit path; this goroutine runs forever
            doWork()
        }
    }()
}
```

**After:**
```go
func start(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            default:
                doWork()
            }
        }
    }()
}
```

**Related:** [[mistake-60-not-using-nil-channels-intentionally]]

---

### #57 — Not being careful with goroutines and loop variables [verify]

**Pattern to look for:**
- A `go func() { ... }()` closure inside a `for` loop that reads the loop variable, on a Go version before 1.22.
- A loop variable captured by reference in a closure passed to `go` with no per-iteration copy or parameter.
- Code that assumes each goroutine sees the loop variable's value at the time `go` ran.

**Why this is a mistake:**
Before Go 1.22, a `for` loop reuses one variable across iterations. A goroutine launched inside the loop that reads this variable through a closure can see the value from a later iteration, not the value at the time the goroutine started, because the goroutine may run after the loop advances.

**Fix:**
Pass the loop variable as a parameter to the goroutine's function literal, or assign it to a new local variable inside the loop body before the `go` statement. Go 1.22 and later create a fresh variable per iteration, but an explicit copy stays clear and portable.

**Before:**
```go
for _, v := range values {
    go func() {
        // pre-1.22: v may hold the last iteration's value here
        process(v)
    }()
}
```

**After:**
```go
for _, v := range values {
    v := v
    go func() {
        process(v)
    }()
}
```

**Related:** [[mistake-55-not-understanding-the-go-memory-model-and-happens-before]]

---

### #58 — Expecting deterministic behavior in select with multiple ready channels [verify]

**Pattern to look for:**
- A `select` statement with two or more `case` branches, where more than one channel can be ready at the same time.
- Code or a comment that assumes the first `case` in source order wins when several channels are ready.
- A test that checks for one specific branch of a `select` with no control over which channel becomes ready first.

**Why this is a mistake:**
When more than one `case` in a `select` statement is ready at the same time, Go picks one of them at random. Code that assumes a fixed order, such as the first listed `case`, runs correctly only by chance and can pick a different branch on a later run.

**Fix:**
Do not depend on `select` case order when several channels can be ready together. Give a `case` explicit priority with a nested `select` or a dedicated priority channel, if a fixed order matters.

**Before:**
```go
select {
case v := <-highPriority:
    // assumed to always win over lowPriority when both are ready
    handle(v)
case v := <-lowPriority:
    handle(v)
}
```

**After:**
```go
select {
case v := <-highPriority:
    handle(v)
default:
    select {
    case v := <-highPriority:
        handle(v)
    case v := <-lowPriority:
        handle(v)
    }
}
```

**Related:** [[mistake-60-not-using-nil-channels-intentionally]]

---

### #59 — Not using notification channels correctly [verify]

**Pattern to look for:**
- A channel used only as a signal, with a value sent on it that no receiver reads.
- A `close(ch)` call on a channel that other code also sends values on later.
- Confusion in a code review between "send a value" and "close the channel" as two different ways to notify a receiver.

**Why this is a mistake:**
A send delivers one notification to one receiver that calls `<-ch` at that moment. A close delivers a notification to every receiver, present and future, and lets a receive proceed with the channel's zero value forever after. Using the wrong form misses receivers or sends more values than the API states.

**Fix:**
Send a value on a channel of type `chan struct{}` to notify exactly one receiver of one event. Close a channel to notify every current and future receiver that no more values will come.

**Before:**
```go
done := make(chan struct{})
go func() {
    work()
    done <- struct{}{}
    // only one receiver ever unblocks; a second receiver waits forever
}()
```

**After:**
```go
done := make(chan struct{})
go func() {
    work()
    close(done)
    // every receiver on done unblocks, now and later
}()
```

**Related:** [[mistake-54-being-puzzled-about-when-to-use-channels-vs-mutexes]]

---

### #60 — Not using nil channels intentionally [verify]

**Pattern to look for:**
- A `select` statement with a `case` that must turn off under some condition, handled with an `if` around the whole `select` instead of a nil channel.
- A channel variable set to `nil` by accident, with no comment on the effect inside a nearby `select`.
- Code that merges two channels into one output and needs to drop a source once it closes.

**Why this is a mistake:**
A receive or a send on a `nil` channel blocks forever. Inside a `select` statement, this is a controlled way to disable one `case` without deleting it from the code, since `select` never picks a blocked case. Missing this pattern leads to extra branching and flags to reach the same effect.

**Fix:**
Set a channel variable to `nil` to turn its `select` case off, instead of an `if` guard or a flag. Use this to drop a closed source channel from a fan-in loop or to disable a timeout case once it has fired.

**Before:**
```go
for ch1 != nil || ch2 != nil {
    if ch1 != nil {
        select {
        case v, ok := <-ch1:
            // manual guard duplicated for every channel
            if !ok {
                ch1 = nil
            } else {
                handle(v)
            }
        }
    }
    // ... repeated for ch2, hard to extend
}
```

**After:**
```go
for ch1 != nil || ch2 != nil {
    select {
    case v, ok := <-ch1:
        if !ok {
            ch1 = nil
            continue
        }
        handle(v)
    case v, ok := <-ch2:
        if !ok {
            ch2 = nil
            continue
        }
        handle(v)
    }
}
```

**Related:** [[mistake-58-expecting-deterministic-behavior-in-select-with-multiple-ready-channels]], [[mistake-56-creating-goroutines-without-understanding-when-to-stop-them]]

---
