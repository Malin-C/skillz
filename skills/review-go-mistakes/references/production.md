# Production

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #96 — Not exposing metrics [verify]

**Pattern to look for:**
- A service with no `/metrics` HTTP endpoint and no metrics library import, such as `prometheus/client_golang` or an OpenTelemetry metrics SDK.
- Request counts, error counts, or latency values logged as text only, with no counter or histogram recorded for them.
- An incident review with no metric to show request rate, error rate, or latency at the time of the incident.

**Why this is a mistake:**
Logs show single events. Metrics show trends and rates over time, at low storage cost per data point. A service with no metrics gives an operator no fast way to see whether error rate or latency changed, so the operator must dig through logs during an incident instead of reading a dashboard.

**Fix:**
Add a metrics library, such as `prometheus/client_golang` or an OpenTelemetry metrics exporter. Record a counter for requests and errors, and a histogram for request duration, on each handler.

**Before:**
```go
func handler(w http.ResponseWriter, r *http.Request) {
    if err := process(r); err != nil {
        log.Printf("request failed: %v", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    w.WriteHeader(http.StatusOK)
}
// no counter, no histogram, no way to graph error rate
```

**After:**
```go
var (
    requests = prometheus.NewCounterVec(
        prometheus.CounterOpts{Name: "http_requests_total"},
        []string{"status"},
    )
)

func handler(w http.ResponseWriter, r *http.Request) {
    if err := process(r); err != nil {
        requests.WithLabelValues("error").Inc()
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    requests.WithLabelValues("ok").Inc()
    w.WriteHeader(http.StatusOK)
}
```

**Related:** [[mistake-98-not-using-structured-logging]]

---

### #97 — Not enabling profiling endpoints in production [verify]

**Pattern to look for:**
- No import of `net/http/pprof` in a service's main package.
- A high-CPU or high-memory incident with no profile taken during the incident, only after a restart.
- A profiling endpoint imported, but exposed on the same port and route tree as public traffic, with no access control.

**Why this is a mistake:**
The `pprof` package adds a small, near-zero cost when idle, but it lets an operator capture a live CPU or memory profile from a running process. A service built with no `pprof` endpoint gives the operator no way to profile the exact process and state that caused an incident, so the cause can go unconfirmed after a restart clears the state.

**Fix:**
Import `net/http/pprof` for its registration side effect, and serve it on a separate internal port, not the public listener. Restrict access to the profiling port with a firewall rule or an internal network boundary.

**Before:**
```go
func main() {
    http.HandleFunc("/", publicHandler)
    log.Fatal(http.ListenAndServe(":8080", nil))
}
// no pprof endpoint; a live CPU spike leaves no profile to capture
```

**After:**
```go
import _ "net/http/pprof"

func main() {
    go func() {
        // internal-only listener, not reachable from public traffic
        log.Println(http.ListenAndServe("127.0.0.1:6060", nil))
    }()
    http.HandleFunc("/", publicHandler)
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

**Related:** [[mistake-96-not-exposing-metrics]]

---

### #98 — Not using structured logging [verify]

**Pattern to look for:**
- Log lines built with `fmt.Sprintf` or string concatenation, such as `log.Printf("user %s failed with %v", userID, err)`.
- A log aggregation system in use, with parsing rules that split free-text log lines on fixed positions or regular expressions.
- No consistent field names for common values, such as request ID or user ID, across log lines from different parts of the service.

**Why this is a mistake:**
A free-text log line packs data and message into one string with no fixed shape. A log search or alert rule built on top of free text breaks whenever the message wording changes, and it cannot filter or aggregate on a field, such as user ID, without a fragile regular expression.

**Fix:**
Use a structured logging package, such as `log/slog` in the standard library, that logs each field as a distinct key-value pair. Keep field names consistent across the service so log queries and alerts stay stable across message wording changes.

**Before:**
```go
log.Printf("user %s failed with %v", userID, err)
// free text; a query for userID needs a fragile regex
```

**After:**
```go
logger.Error("user request failed",
    slog.String("user_id", userID),
    slog.Any("error", err),
)
// structured fields; a query can filter on user_id directly
```

**Related:** [[mistake-96-not-exposing-metrics]]

---

### #99 — Not handling graceful shutdown [verify]

**Pattern to look for:**
- A server started with `http.ListenAndServe`, with no call to `Shutdown` and no signal handler registered.
- A `main` function that exits as soon as the process gets `SIGTERM`, with in-flight requests or background goroutines left unfinished.
- A deployment with rolling updates or autoscaling, where a Go service shows dropped connections during each rollout.

**Why this is a mistake:**
An orchestrator, such as Kubernetes, sends `SIGTERM` before it kills a container, then waits a grace period before it sends `SIGKILL`. A service that ignores `SIGTERM` gets killed mid-request on the next deploy or scale-down event, which drops in-flight requests and can leave shared state, such as a database write, half done.

**Fix:**
Listen for `SIGTERM` and `SIGINT` with `signal.NotifyContext` or a similar mechanism. On signal, call the server's `Shutdown` method with a bounded context, so in-flight requests get a chance to finish before the process exits.

**Before:**
```go
func main() {
    srv := &http.Server{Addr: ":8080", Handler: mux}
    log.Fatal(srv.ListenAndServe())
}
// SIGTERM kills the process immediately, in-flight requests are dropped
```

**After:**
```go
func main() {
    srv := &http.Server{Addr: ":8080", Handler: mux}
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
    defer stop()
    <-ctx.Done()

    shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()
    srv.Shutdown(shutdownCtx)
}
```

**Related:** [[mistake-96-not-exposing-metrics]]

---

### #100 — Not being aware of runtime configuration [verify]

**Pattern to look for:**
- A service that runs with default `GOGC`, `GOMAXPROCS`, and `GOMEMLIMIT` settings, with no review against its actual CPU and memory usage.
- A GC-bound workload, shown by a CPU profile with a large share of time in garbage collection, and no tuning of `GOGC` or `GOMEMLIMIT` attempted.
- A latency-sensitive service with no monitoring of GC pause time or heap size, so memory pressure builds with no alert before an out-of-memory event.

**Why this is a mistake:**
`GOGC`, `GOMAXPROCS`, and `GOMEMLIMIT` control how the Go runtime trades CPU time against memory use and pause time. The default values fit a general workload, not a specific one. A team that leaves these settings untouched, and does not monitor heap size or GC pause time in production, tunes the service by guesswork after an incident instead of by data gathered ahead of time.

**Fix:**
Watch runtime metrics, such as heap size, GC pause time, and CPU time spent in GC, through `runtime/metrics` or a metrics exporter. Raise `GOGC` to trade memory for less frequent GC on a CPU-bound service, or set `GOMEMLIMIT` to cap heap growth on a memory-constrained one. Set `GOMAXPROCS` to match the workload's real parallelism needs, not just the available core count. Re-check these settings as the workload changes over time.

**Before:**
```go
func main() {
    // GOGC, GOMAXPROCS, GOMEMLIMIT all left at their defaults
    // no runtime metric watched, tuning happens only after an incident
    run()
}
```

**After:**
```go
func main() {
    // GOMEMLIMIT set with a safety margin under the known memory budget
    debug.SetMemoryLimit(1800 << 20) // 1800 MiB
    // GOGC raised since profiling showed heavy GC overhead on this workload
    debug.SetGCPercent(200)
    go reportRuntimeMetrics() // exports heap size and GC pause time
    run()
}
```

**Related:** [[mistake-94-not-understanding-how-the-garbage-collector-works]], [[mistake-95-not-understanding-the-impact-of-running-go-inside-docker-and-kubernetes]]

---
