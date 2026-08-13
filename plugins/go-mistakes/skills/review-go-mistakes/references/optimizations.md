# Optimizations

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #88 — Not understanding CPU caches [verify]

**Pattern to look for:**
- A loop over a multi-dimensional slice, such as `[][]float64`, that walks columns before rows.
- A hot numeric loop with no comment on memory access order, next to a benchmark that shows a large gap between two equivalent versions.
- A slice of pointers to structs used in a tight loop, instead of a slice of the structs themselves.

**Why this is a mistake:**
The CPU pulls memory into cache in fixed-size blocks, called cache lines, that hold about 64 bytes. Code that reads memory in a jumping order forces the CPU to fetch a new cache line on almost every access. The loop then waits on main memory instead of running at cache speed.

**Fix:**
Walk data in the same order it sits in memory: row by row for a row-major slice. Prefer contiguous data, such as a slice of structs. Avoid data spread across separate allocations, such as a slice of pointers.

**Before:**
```go
matrix := make([][]float64, n)
// ... fill matrix, n rows of m columns each
var sum float64
for col := 0; col < m; col++ {
    for row := 0; row < n; row++ {
        sum += matrix[row][col]
        // jumps to a new row on every step, new cache line each time
    }
}
```

**After:**
```go
matrix := make([][]float64, n)
// ... fill matrix, n rows of m columns each
var sum float64
for row := 0; row < n; row++ {
    for col := 0; col < m; col++ {
        sum += matrix[row][col]
        // walks each row in memory order
    }
}
```

**Related:** [[mistake-89-writing-concurrent-code-that-leads-to-false-sharing]], [[mistake-90-not-being-aware-of-data-alignment]]

---

### #89 — Writing concurrent code that leads to false sharing [verify]

**Pattern to look for:**
- A struct with fields that different goroutines update, where the fields sit next to each other with no padding.
- An array of per-goroutine counters, indexed by goroutine ID, stored as one contiguous array of small values.
- A benchmark that shows a multi-goroutine version slower than expected, with no lock contention in the profile.

**Why this is a mistake:**
Two variables on the same cache line count as one unit to the cache-coherency system, even when different goroutines never touch the same variable. A write from one core marks the whole line invalid on other cores. Unrelated updates on separate cores then fight over the same cache line and slow each other down.

**Fix:**
Separate per-goroutine data onto different cache lines. Add padding fields, or space out array elements, so each goroutine writes to its own line, typically 64 bytes apart.

**Before:**
```go
type counters struct {
    a int64 // goroutine 1 writes this field
    b int64 // goroutine 2 writes this field
}
// a and b sit on the same cache line, writes to one invalidate the other
```

**After:**
```go
type counters struct {
    a int64
    _ [56]byte // padding fills out the rest of the cache line
    b int64
    _ [56]byte
}
// a and b now sit on separate cache lines
```

**Related:** [[mistake-88-not-understanding-cpu-caches]], [[mistake-64-using-mutexes-inaccurately-with-slices-and-maps]]

---

### #90 — Not being aware of data alignment [verify]

**Pattern to look for:**
- A struct with fields in an arbitrary order, mixing `bool`, `int32`, and `int64` or pointer fields.
- A call to `unsafe.Sizeof` on a struct that returns a value larger than the sum of its field sizes.
- A large slice of a struct type, where the struct's memory footprint matters for cache use and total memory.

**Why this is a mistake:**
Go pads a struct so each field starts at an address that matches its own alignment requirement. Field order that mixes small and large fields inserts padding between them. This grows the struct's size with no matching gain, and wastes memory across a large slice of that struct.

**Fix:**
Order struct fields from largest alignment requirement to smallest: pointers and `int64` first, then `int32`, then `bool` and `byte`. This groups padding at the end instead of scattering it between fields.

**Before:**
```go
type record struct {
    a bool  // 1 byte, then 7 bytes of padding
    b int64 // 8 bytes
    c bool  // 1 byte, then 3 bytes of padding
    d int32 // 4 bytes
}
// unsafe.Sizeof(record{}) == 24
```

**After:**
```go
type record struct {
    b int64 // 8 bytes
    d int32 // 4 bytes
    a bool  // 1 byte
    c bool  // 1 byte, 2 bytes of padding to close the struct
}
// unsafe.Sizeof(record{}) == 16
```

**Related:** [[mistake-88-not-understanding-cpu-caches]]

---

### #91 — Not understanding stack vs heap [verify]

**Pattern to look for:**
- A function that returns a pointer to a local variable, with no comment on why the value must outlive the call.
- A local value passed to a parameter of interface type, such as `fmt.Println` or `interface{}`, on a hot path.
- No use of `go build -gcflags="-m"` to check escape analysis on code under performance review.

**Why this is a mistake:**
The Go compiler decides at build time whether a variable stays on the function's stack, or escapes to the heap. A stack variable frees automatically when the function returns. A heap variable needs the garbage collector to track and later free it. A variable that escapes when it did not need to adds an allocation and extra GC work on every call.

**Fix:**
Run escape analysis with `go build -gcflags="-m"` to see which variables escape and why. On a hot path, avoid patterns that force an unneeded escape. One example is returning a pointer to a local value the caller only reads once.

**Before:**
```go
func newPoint(x, y int) *Point {
    p := Point{x, y}
    return &p
    // p escapes to the heap because its address leaves the function
}
```

**After:**
```go
func newPoint(x, y int) Point {
    return Point{x, y}
    // returned by value, stays on the caller's stack when possible
}
```

**Related:** [[mistake-92-not-knowing-how-to-reduce-allocations]]

---

### #92 — Not knowing how to reduce allocations [verify]

**Pattern to look for:**
- A per-request or per-iteration call to `make` or a struct literal for a short-lived buffer, on a hot path.
- A `pprof` heap profile that shows one function as the source of most allocations, with no fix applied.
- A loop that grows a slice with repeated `append` calls, and no `make` call sized to the known or estimated length.

**Why this is a mistake:**
Each allocation on a hot path adds work for the allocator and adds pressure that brings the garbage collector back sooner. A function called often that allocates a short-lived object every time spends CPU time on setup and cleanup instead of on its actual task.

**Fix:**
Reuse short-lived, expensive-to-allocate objects with a `sync.Pool`. Pre-allocate slices and maps at the expected size with `make` before a loop. Do not grow them one `append` or insert at a time.

**Before:**
```go
func handle(data []byte) []byte {
    buf := make([]byte, 0, 512)
    // fresh allocation on every call
    buf = append(buf, data...)
    return process(buf)
}
```

**After:**
```go
var bufPool = sync.Pool{
    New: func() any { return make([]byte, 0, 512) },
}

func handle(data []byte) []byte {
    buf := bufPool.Get().([]byte)[:0]
    defer bufPool.Put(buf)
    buf = append(buf, data...)
    return process(buf)
}
```

**Related:** [[mistake-91-not-understanding-stack-vs-heap]], [[mistake-16-inefficient-slice-initialization]], [[mistake-94-not-understanding-how-the-garbage-collector-works]]

---

### #93 — Not using Go diagnostic tools [verify]

**Pattern to look for:**
- A performance fix applied to code that "looks slow," with no profile or benchmark run before or after the change.
- A service with no `pprof` endpoint enabled, and no benchmark file (`*_test.go` with `Benchmark` functions) for the code under review.
- A report of latency spikes or high CPU with no `go tool trace` or CPU profile attached to the investigation.

**Why this is a mistake:**
Without profiling data, an optimization can target a function that is not the real bottleneck, while the actual hot path stays untouched. Guesswork wastes engineering time and can make code harder to read for no measured gain.

**Fix:**
Use `pprof` CPU, heap, block, and mutex profiles to find the actual hot paths before a change. Use `go tool trace` to inspect scheduler, GC, and goroutine behavior over time. Confirm a gain with a benchmark, run before and after the change.

**Before:**
```go
// "this JSON encoding step feels slow, let's rewrite it"
// no profile, no benchmark, no data on where time goes
```

**After:**
```go
import _ "net/http/pprof"
// go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
// confirms the JSON step, or points at a different function instead
```

**Related:** [[mistake-92-not-knowing-how-to-reduce-allocations]], [[mistake-86-writing-inaccurate-benchmarks]]

---

### #94 — Not understanding how the garbage collector works [verify]

**Pattern to look for:**
- Complaints about latency spikes in a service with a high allocation rate, and no discussion of `GOGC` or `GOMEMLIMIT` in the investigation.
- Code changes that chase allocation counts down with no check on whether GC pause time was the actual problem.
- A long-running service with default GC settings and no use of `GODEBUG=gctrace=1` to observe GC behavior.

**Why this is a mistake:**
Go's garbage collector runs concurrently with the program. It paces its own work against the rate of heap growth, controlled by `GOGC` (a target heap growth percentage, 100 by default). A team that does not know this can chase allocation reduction where it does not help. It can also miss that `GOGC` or `GOMEMLIMIT` tuning would fix a latency problem directly.

**Fix:**
Learn the GC's concurrent mark-and-sweep design and its `GOGC` pacing target. Tune `GOGC` for services that trade memory for less GC work. On Go 1.19 and later, set a hard cap with `GOMEMLIMIT` for services that must stay under a memory budget. Check `GODEBUG=gctrace=1` output to observe actual GC frequency and pause time.

**Before:**
```go
// default GOGC=100, no GOMEMLIMIT set
// latency spikes blamed on "the GC" with no data on GC frequency
```

**After:**
```go
// GODEBUG=gctrace=1 ./service   # observe real GC frequency and pauses
debug.SetMemoryLimit(2 << 30) // 2 GiB soft cap, or set GOMEMLIMIT=2GiB
```

**Related:** [[mistake-92-not-knowing-how-to-reduce-allocations]], [[mistake-95-not-understanding-the-impact-of-running-go-inside-docker-and-kubernetes]]

---

### #95 — Not understanding the impact of running Go inside Docker and Kubernetes [verify]

**Pattern to look for:**
- A container with a CPU limit set, such as `resources.limits.cpu: 2` in a Kubernetes manifest, on a Go runtime older than 1.25.
- No `GOMAXPROCS` set and no `automaxprocs`-style library in use on that older runtime.
- A container killed by the kernel's out-of-memory handler, with a memory limit set on the container but no `GOMEMLIMIT` set on the Go process.
- No mention of CPU or memory limits in a deployment review for a Go service that runs in a container.

**Why this is a mistake:**
Before Go 1.25, the runtime set `GOMAXPROCS` to the host's full logical CPU count, not the container's CPU quota. A container capped at 2 CPUs could still run as many OS threads as the host has cores, adding scheduling overhead and throttling. Go 1.25 reads the cgroup CPU quota and sets `GOMAXPROCS` to match it by default, but only when `GOMAXPROCS` is not set some other way. Separately, with no `GOMEMLIMIT` set, the GC has no view of the container's memory cap. It can let the heap grow until the kernel OOM-kills the process.

**Fix:**
On Go 1.25 and later, leave `GOMAXPROCS` unset so the runtime reads the container's CPU quota automatically. On earlier versions, set `GOMAXPROCS` to the container's CPU limit directly. As an alternative, use a library that reads the cgroup quota at startup. Set `GOMEMLIMIT` to a value under the container's memory limit, so the GC keeps the heap under a safe cap.

**Before:**
```go
// Go < 1.25, container capped at 2 CPUs, 512 MiB memory
// GOMAXPROCS unset, defaults to the host's core count, e.g. 32
// GOMEMLIMIT unset, GC has no cap tied to the container
```

**After:**
```go
// Go 1.25+: GOMAXPROCS tracks the cgroup CPU quota automatically
// GOMEMLIMIT set to keep a safety margin under the container cap
debug.SetMemoryLimit(450 << 20) // 450 MiB, under a 512 MiB limit
```

**Related:** [[mistake-94-not-understanding-how-the-garbage-collector-works]]

---
