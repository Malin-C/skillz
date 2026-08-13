# Control structures

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #24 — Ignoring that elements are copied in range loops [verify]

**Pattern to look for:**
- A `for _, v := range items` loop over a slice of structs, where the loop body writes to `v` and expects `items` to change.
- Code that takes the address of the loop value to build a slice of pointers to the source elements.
- A large struct type used as the range value, with no note on the cost of the per-iteration copy.

**Why this is a mistake:**
Each pass of a `range` loop copies the element into the loop variable. A write to that copy does not reach the original element in the source slice or array.

**Fix:**
Index into the original slice with `items[i]` to change the source element. Take the address of `items[i]`, not of the loop variable, when the goal is a pointer to the source element.

**Before:**
```go
type Item struct{ Price int }

items := []Item{{Price: 10}, {Price: 20}}
for _, item := range items {
    item.Price *= 2
}
// items still holds the original prices; item was a copy
fmt.Println(items)
```

**After:**
```go
type Item struct{ Price int }

items := []Item{{Price: 10}, {Price: 20}}
for i := range items {
    items[i].Price *= 2
}
fmt.Println(items)
```

**Related:** [[mistake-25-ignoring-how-arguments-are-evaluated-in-range-loops]], [[mistake-26-ignoring-the-impact-of-using-pointer-elements-in-range-loops]]

---

### #25 — Ignoring how arguments are evaluated in range loops [verify]

**Pattern to look for:**
- A `range` clause that calls a function, such as `range genItems()`, inside a loop that also appends to the same source.
- A loop that appends to the slice under iteration and expects the loop to cover the new elements.
- A channel-producing or slice-producing call in a `range` clause, with no note that the call runs only once.

**Why this is a mistake:**
Go evaluates the `range` expression once, before the loop starts, and copies the resulting slice header, array, or channel value. Elements appended to the source after the loop starts do not extend the loop.

**Fix:**
Read the length or store the range expression's result in a variable before the loop, when later growth of the source matters. State in a comment that the `range` expression runs only once.

**Before:**
```go
s := []int{1, 2, 3}
for i, v := range s {
    if i == 0 {
        s = append(s, 4)
    }
    fmt.Println(v)
}
// the loop still runs 3 times; range captured the original length
```

**After:**
```go
s := []int{1, 2, 3}
n := len(s)
for i := 0; i < n; i++ {
    if i == 0 {
        s = append(s, 4)
    }
    fmt.Println(s[i])
}
// the explicit bound states the intent; no hidden capture rule
```

**Related:** [[mistake-24-ignoring-that-elements-are-copied-in-range-loops]]

---

### #26 — Ignoring the impact of using pointer elements in range loops [verify]

**Pattern to look for:**
- A slice of pointers, such as `[]*Item`, iterated with `range`, where the pointer variable gets stored for later use.
- A loop that appends `&item` to a result slice, where `item` is the `range` value.
- A Go version below 1.22 in `go.mod`, where the loop variable is reused across iterations.

**Why this is a mistake:**
Before Go 1.22, `range` reuses the same loop variable on every iteration. Code that stores the loop variable's address for later use ends up with every stored pointer pointing at the same, final value.

**Fix:**
Assign the loop value to a new local variable inside the loop body before storing its address. Take the address of the slice element by index as an alternative. Go 1.22 gives each iteration its own variable, so this fix matters mainly for older Go versions.

**Before:**
```go
type Item struct{ Name string }

items := []Item{{Name: "a"}, {Name: "b"}}
var out []*Item
for _, item := range items {
    out = append(out, &item)
}
// pre-Go 1.22: every pointer in out refers to the same variable
```

**After:**
```go
type Item struct{ Name string }

items := []Item{{Name: "a"}, {Name: "b"}}
var out []*Item
for i := range items {
    out = append(out, &items[i])
}
```

**Related:** [[mistake-24-ignoring-that-elements-are-copied-in-range-loops]]

---

### #27 — Making wrong assumptions during map iterations [verify]

**Pattern to look for:**
- Code that reads map entries with `range` and treats the first or last key printed as a stable order.
- A map iterated with `range` while entries also get inserted or deleted inside the same loop body.
- A test that compares two map iteration outputs for order, with no explicit sort step.

**Why this is a mistake:**
Go does not guarantee an order for `range` over a map, and the order can change between runs of the same program. An insert or delete during iteration can also change whether that entry appears in the current pass.

**Fix:**
Sort the map's keys before iteration when a stable order matters. Avoid an insert or delete on the map under iteration. Collect changes in a separate slice or map and apply them after the loop.

**Before:**
```go
m := map[string]int{"b": 2, "a": 1, "c": 3}
for k, v := range m {
    fmt.Println(k, v)
}
// print order is not guaranteed and can change between runs
```

**After:**
```go
m := map[string]int{"b": 2, "a": 1, "c": 3}
keys := make([]string, 0, len(m))
for k := range m {
    keys = append(keys, k)
}
sort.Strings(keys)
for _, k := range keys {
    fmt.Println(k, m[k])
}
```

**Related:** [[mistake-23-maps-and-memory-leaks]]

---

### #28 — Ignoring how break works with switch and select [verify]

**Pattern to look for:**
- A `break` statement inside a `switch` or `select` that sits inside a `for` loop, meant to stop the loop.
- A comment near a `break` inside a `switch` case that states an intent to stop the outer loop.
- No labeled statement on the loop that holds the `switch` or `select`.

**Why this is a mistake:**
A plain `break` inside a `switch` or `select` exits only that statement, not an enclosing `for` loop. The loop continues to the next iteration instead of stopping, which the author did not expect.

**Fix:**
Label the `for` loop and use `break label` to exit the loop directly from inside the `switch` or `select`. Read the label at the loop and at the `break` line to confirm the target matches the intent.

**Before:**
```go
for i := 0; i < 5; i++ {
    switch {
    case i == 2:
        break
        // this exits the switch only; the loop keeps running
    default:
        fmt.Println(i)
    }
}
```

**After:**
```go
loop:
for i := 0; i < 5; i++ {
    switch {
    case i == 2:
        break loop
    default:
        fmt.Println(i)
    }
}
```

**Related:** [[mistake-29-using-defer-inside-a-loop]]

---

### #29 — Using defer inside a loop [verify]

**Pattern to look for:**
- A `defer` call inside the body of a `for` loop that can run many iterations.
- A loop that opens a file, a lock, or another resource and defers its release call inside the loop body.
- A long-running loop with no visible resource release until the enclosing function returns.

**Why this is a mistake:**
A deferred call does not run until its enclosing function returns, not at the end of the current loop iteration. A loop with many iterations builds a growing stack of pending calls and holds every resource open until the function exits.

**Fix:**
Move the loop body that needs the deferred call into its own function. Each call to that function runs and releases its `defer` on return. Call the release function directly at the end of the loop body when a helper function is not practical.

**Before:**
```go
func processAll(paths []string) error {
    for _, p := range paths {
        f, err := os.Open(p)
        if err != nil {
            return err
        }
        defer f.Close()
        // f stays open until processAll returns, not after each file
        if err := process(f); err != nil {
            return err
        }
    }
    return nil
}
```

**After:**
```go
func processAll(paths []string) error {
    for _, p := range paths {
        if err := processOne(p); err != nil {
            return err
        }
    }
    return nil
}

func processOne(p string) error {
    f, err := os.Open(p)
    if err != nil {
        return err
    }
    defer f.Close()
    return process(f)
}
```

**Related:** [[mistake-28-ignoring-how-break-works-with-switch-and-select]]

---
