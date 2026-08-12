# Data types

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #12 — Creating confusion with octal literals [verify]

**Pattern to look for:**
- An integer literal with a leading zero, such as `0650`.
- A literal that looks like a decimal number but starts with `0`.
- A file-mode or permission constant written without a comment on its base.

**Why this is a mistake:**
A leading zero marks an octal literal in Go. A reader who does not notice the leading zero reads the value as decimal and gets the wrong number.

**Fix:**
Write the explicit `0o` prefix for octal literals. Use `0x` for hexadecimal and `0b` for binary in the same style.

**Before:**
```go
sum := 0650 + 5
// looks decimal, but 0650 is octal (424 decimal)
fmt.Println(sum)
```

**After:**
```go
sum := 0o650 + 5
// the 0o prefix marks the octal base for any reader
fmt.Println(sum)
```

**Related:** [[mistake-13-neglecting-integer-overflows]]

---

### #13 — Neglecting integer overflows [verify]

**Pattern to look for:**
- Arithmetic on `int32` or `int64` values near the type's maximum, with no bound check.
- A loop counter or accumulator with no check against the max value of its type.
- Conversion from a wider integer type to a narrower one with no range check.

**Why this is a mistake:**
An integer overflow wraps around to a negative or unexpected value in Go and raises no error or panic. The bug stays silent and produces wrong results downstream.

**Fix:**
Check bounds before an operation that can overflow, or use a wider type. Use `math.MaxInt32` and similar constants to guard conversions.

**Before:**
```go
var count int32 = math.MaxInt32
count++
// count wraps to a negative number, no error raised
fmt.Println(count)
```

**After:**
```go
var count int32 = math.MaxInt32
if count == math.MaxInt32 {
    return errors.New("counter at max value")
}
count++
```

**Related:** [[mistake-12-creating-confusion-with-octal-literals]], [[mistake-14-not-understanding-floating-points]]

---

### #14 — Not understanding floating points [verify]

**Pattern to look for:**
- A direct `==` comparison between two `float32` or `float64` values.
- Money or count values held in a `float64` field, with sums or subtractions applied over time.
- A loop that adds a fractional step to a float on each iteration.

**Why this is a mistake:**
A float value cannot hold every decimal fraction with exact precision. Repeated addition or a direct equality check can produce a result that differs from the expected value by a small margin.

**Fix:**
Compare floats with a tolerance range instead of `==`. Use an integer type, such as cents, for exact decimal values like money.

**Before:**
```go
var total float64
for i := 0; i < 10; i++ {
    total += 0.1
}
if total == 1.0 {
    fmt.Println("exact")
}
// total is not exactly 1.0, this branch does not run
```

**After:**
```go
var total float64
for i := 0; i < 10; i++ {
    total += 0.1
}
const epsilon = 1e-9
if math.Abs(total-1.0) < epsilon {
    fmt.Println("close enough")
}
```

**Related:** [[mistake-13-neglecting-integer-overflows]]

---

### #15 — Not understanding slice length and capacity [verify]

**Pattern to look for:**
- A slice created with `make([]T, length, capacity)` where the two numbers get confused.
- Code that reads `cap(s)` where it means `len(s)`, or the reverse.
- A slice re-sliced with a three-index form and no comment on why.

**Why this is a mistake:**
Length is the number of elements a slice holds now. Capacity is the number of elements the underlying array can hold before Go must allocate a new array. Mixing the two leads to wrong bounds checks and surprise allocations.

**Fix:**
Read `len(s)` for the current element count and `cap(s)` for the underlying array's total room. Set both values with intent when a slice is created with `make`.

**Before:**
```go
s := make([]int, 0, 10)
for i := 0; i < cap(s); i++ {
    // wrong: cap(s) reports 10 even before append runs
    s = append(s, i)
}
fmt.Println(len(s))
```

**After:**
```go
s := make([]int, 0, 10)
for i := 0; i < 10; i++ {
    s = append(s, i)
}
fmt.Println(len(s), cap(s))
```

**Related:** [[mistake-16-inefficient-slice-initialization]], [[mistake-20-unexpected-side-effects-using-slice-append]]

---

### #16 — Inefficient slice initialization [verify]

**Pattern to look for:**
- A slice declared with `var s []T` or `s := []T{}`, then grown only with repeated `append` calls in a loop with a known final size.
- A loop that appends a known number of elements with no initial capacity set.
- Benchmark or profile output that shows many small allocations from one slice-building loop.

**Why this is a mistake:**
Each `append` call past the current capacity forces Go to allocate a new, larger backing array and copy the old elements into it. A loop with a known length that skips this step pays for several allocations and copies instead of one.

**Fix:**
Call `make([]T, 0, n)` with the known or estimated length before the loop, or use `make([]T, n)` and set elements by index.

**Before:**
```go
var s []int
for i := 0; i < n; i++ {
    s = append(s, i)
}
// grows and copies the backing array several times
```

**After:**
```go
s := make([]int, 0, n)
for i := 0; i < n; i++ {
    s = append(s, i)
}
// one allocation for the full capacity
```

**Related:** [[mistake-15-not-understanding-slice-length-and-capacity]]

---

### #17 — Being confused about nil vs. empty slices [verify]

**Pattern to look for:**
- A function that returns `[]T{}` in one branch and `nil` in another, with no clear rule.
- A caller that checks `s == nil` to test whether a slice holds elements.
- JSON marshaling code where a `nil` slice and an empty slice must render the same way, but do not.

**Why this is a mistake:**
A `nil` slice and an empty, non-nil slice both report `len(s) == 0`, but they differ under `== nil` and under some marshaling paths, such as JSON, where a `nil` slice renders as `null`. Mixed use without a stated rule confuses callers and breaks equality checks.

**Fix:**
Prefer returning `nil` for an empty result unless the API states an empty slice is required. Check for emptiness with `len(s) == 0`, not `s == nil`.

**Before:**
```go
func getItems(ok bool) []string {
    if !ok {
        return []string{}
    }
    return nil
}
// two different empty-ish values, no clear rule for callers
```

**After:**
```go
func getItems(ok bool) []string {
    if !ok {
        return nil
    }
    return fetchItems()
}
// nil is the norm for "no items"; callers use len(s) == 0
```

**Related:** [[mistake-18-not-properly-checking-if-a-slice-is-empty]]

---

### #18 — Not properly checking if a slice is empty [verify]

**Pattern to look for:**
- A check of the form `s == nil` used to decide whether a slice holds elements.
- Code that skips a nil slice with one check, then still runs `range` or `append` calls that would have worked on `nil` anyway.
- Duplicate branches for the `nil` case and the empty-but-not-nil case that do the same thing.

**Why this is a mistake:**
A `nil` slice and an empty, non-nil slice both report `len(s) == 0`, but a `s == nil` check passes only one of the two cases. Code that checks `s == nil` alone can process an empty, non-nil slice as if it holds data, or the reverse.

**Fix:**
Use `len(s) == 0` to test whether a slice holds no elements. This check covers both the `nil` case and the empty, non-nil case.

**Before:**
```go
func process(s []int) {
    if s == nil {
        return
    }
    // an empty, non-nil slice still reaches here unfiltered
    doWork(s)
}
```

**After:**
```go
func process(s []int) {
    if len(s) == 0 {
        return
    }
    doWork(s)
}
```

**Related:** [[mistake-17-being-confused-about-nil-vs-empty-slices]]

---

### #19 — Not making slice copies correctly [verify]

**Pattern to look for:**
- A call to `copy(dst, src)` where `dst` has zero length or a length shorter than `src`.
- Code that assumes `copy` grows the destination slice to fit the source.
- A slice copy meant to fully duplicate data, checked with no verification of the returned count.

**Why this is a mistake:**
The built-in `copy` function copies only up to the length of the shorter of the two slices, and it never grows `dst`. A destination slice with too little length silently drops the remaining source elements, with no error or panic.

**Fix:**
Allocate the destination slice with `make` at the correct length before the call to `copy`. Check the count `copy` returns when partial copies matter.

**Before:**
```go
src := []int{1, 2, 3, 4, 5}
var dst []int
n := copy(dst, src)
// dst has zero length, so n is 0; no elements copied
fmt.Println(dst)
```

**After:**
```go
src := []int{1, 2, 3, 4, 5}
dst := make([]int, len(src))
n := copy(dst, src)
fmt.Println(dst, n)
```

**Related:** [[mistake-15-not-understanding-slice-length-and-capacity]]

---

### #20 — Unexpected side effects using slice append [verify]

**Pattern to look for:**
- Two slices created from the same backing array through a re-slice operation, such as `s2 := s1[:2]`.
- An `append` call on a re-sliced value where the original slice still holds a reference.
- A function parameter of slice type that the function appends to and the caller still reads afterward.

**Why this is a mistake:**
When a slice has spare capacity, `append` writes new elements into the same backing array instead of allocating a new one. Two slices that share that array then observe each other's writes, which produces data one slice did not expect.

**Fix:**
Re-slice with the three-index form to cap the shared capacity, or copy the slice into a new backing array before an independent append.

**Before:**
```go
s1 := []int{1, 2, 3, 4, 5}
s2 := s1[:2]
s2 = append(s2, 99)
// s1[2] changes too, since s2 shared s1's backing array
fmt.Println(s1)
```

**After:**
```go
s1 := []int{1, 2, 3, 4, 5}
s2 := s1[:2:2]
s2 = append(s2, 99)
// the third index caps s2's capacity, so append allocates fresh
fmt.Println(s1)
```

**Related:** [[mistake-15-not-understanding-slice-length-and-capacity]], [[mistake-21-slices-and-memory-leaks]]

---

### #21 — Slices and memory leaks [verify]

**Pattern to look for:**
- A small slice built with `s[low:high]` from a much larger source slice, kept for a long time.
- Code that reads a few fields from a large struct slice and stores a re-slice of it, not a copy.
- A long-lived cache or buffer that holds re-sliced results from short-lived, large inputs.

**Why this is a mistake:**
A re-sliced value keeps a reference to the full backing array of its source, even when it exposes only a small window of it. The garbage collector cannot free the large array while any re-sliced piece stays reachable, so memory use grows over time.

**Fix:**
Copy the needed elements into a new, right-sized slice with `copy` or `append` on a `nil` slice, then let the source slice go out of scope.

**Before:**
```go
func firstTwo(s []int) []int {
    return s[:2]
}
// return value still references the full backing array of s
```

**After:**
```go
func firstTwo(s []int) []int {
    out := make([]int, 2)
    copy(out, s[:2])
    return out
}
```

**Related:** [[mistake-20-unexpected-side-effects-using-slice-append]], [[mistake-23-maps-and-memory-leaks]]

---

### #22 — Inefficient map initialization [verify]

**Pattern to look for:**
- A map declared with `make(map[K]V)` and no size hint, then filled with a known or estimated number of entries in a loop.
- A loop that inserts many entries into a map built with a literal empty `map[K]V{}`.
- Benchmark or profile output that shows repeated map growth during a fill loop.

**Why this is a mistake:**
A map with no size hint starts small and grows through a series of internal rehash and reallocate steps as entries get added. A loop that inserts a known number of entries pays for this repeated growth instead of one allocation sized to fit.

**Fix:**
Call `make(map[K]V, n)` with the expected number of entries before the fill loop, so Go can size the map's internal storage up front.

**Before:**
```go
m := make(map[string]int)
for _, k := range keys {
    m[k] = 0
}
// the map grows and rehashes several times as keys is long
```

**After:**
```go
m := make(map[string]int, len(keys))
for _, k := range keys {
    m[k] = 0
}
// sized once, no growth during the fill loop
```

**Related:** [[mistake-16-inefficient-slice-initialization]]

---

### #23 — Maps and memory leaks [verify]

**Pattern to look for:**
- A long-lived map that grows over time, with entries deleted through `delete` but never through a rebuild.
- A map that once held a large number of entries, now mostly empty after many `delete` calls.
- No periodic map replacement in a service that runs for a long time with a growing-then-shrinking map.

**Why this is a mistake:**
A `delete` call on a map removes the entry but does not shrink the map's underlying buckets. A map that once grew large keeps its large internal storage even after most entries are gone, so memory use stays high.

**Fix:**
Rebuild the map into a fresh one sized to the current entry count when the map has shrunk by a large margin, or periodically for long-lived maps with high churn.

**Before:**
```go
for _, id := range expiredIDs {
    delete(cache, id)
}
// cache's bucket storage stays at its peak size
```

**After:**
```go
fresh := make(map[string]Item, len(cache)-len(expiredIDs))
for k, v := range cache {
    if !expired(k) {
        fresh[k] = v
    }
}
cache = fresh
```

**Related:** [[mistake-21-slices-and-memory-leaks]], [[mistake-22-inefficient-map-initialization]]

---
