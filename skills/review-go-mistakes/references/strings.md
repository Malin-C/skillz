# Strings

Entries in this file follow the same shape:

- Pattern to look for: what code triggers the mistake.
- Why this is a mistake: consequence, in one or two sentences.
- Fix: the standard remedy.
- Before → After: a compact code example (5–10 lines each).
- Related: links to related mistakes in `[[mistake-N-slug]]` form.

Every entry starts as `[verify]`. Drop the tag after cross-check against the book.

### #30 — Not understanding the concept of a rune [verify]

**Pattern to look for:**
- Code that treats `s[i]` as one character of a string.
- A call to `len(s)` used as a stand-in for the character count of a string.
- A `string` value converted to `[]byte` and indexed with no comment on encoding.

**Why this is a mistake:**
A Go string holds a read-only sequence of bytes, not a sequence of characters. A UTF-8 character, a rune, can span from one to four bytes, so `s[i]` returns one byte, not one character, and `len(s)` returns the byte count.

**Fix:**
Convert a string to `[]rune` to work with characters, or range over the string to decode runes in order. Use `utf8.RuneCountInString` for the character count.

**Before:**
```go
s := "héllo"
fmt.Println(len(s))
// prints 6, not 5, since é takes two bytes in UTF-8
fmt.Println(string(s[1]))
// prints a garbled byte, not é
```

**After:**
```go
s := "héllo"
fmt.Println(utf8.RuneCountInString(s))
// prints 5, the number of runes
r := []rune(s)
fmt.Println(string(r[1]))
// prints é
```

**Related:** [[mistake-31-inaccurate-string-iteration]]

---

### #31 — Inaccurate string iteration [verify]

**Pattern to look for:**
- A `for i := 0; i < len(s); i++` loop that reads `s[i]` on each step.
- A loop over a string with a manual index increment of exactly one, applied to non-ASCII input.
- Code that assumes a `for range` loop over a string advances the index by one on each step.

**Why this is a mistake:**
A `for range` loop over a string decodes one rune per step and advances the index by the byte width of that rune, not by one. A manual index loop that increments by one splits multi-byte runes into separate, invalid pieces.

**Fix:**
Use `for i, r := range s` to decode runes correctly, and remember that `i` skips ahead by more than one after a multi-byte rune.

**Before:**
```go
s := "héllo"
for i := 0; i < len(s); i++ {
    fmt.Printf("%c", s[i])
}
// prints garbled output, since s[i] reads raw bytes
```

**After:**
```go
s := "héllo"
for _, r := range s {
    fmt.Printf("%c", r)
}
// prints héllo, one rune decoded per step
```

**Related:** [[mistake-30-not-understanding-the-concept-of-a-rune]]

---

### #32 — Misusing trim functions [verify]

**Pattern to look for:**
- A call to `strings.TrimLeft` or `strings.TrimRight` where the intent is to remove a fixed prefix or suffix string.
- A cutset argument passed to `TrimLeft`, `TrimRight`, or `Trim` that reads like a literal string, not a set of characters.
- Code that expects `TrimLeft(s, "hello")` to remove the substring `"hello"` from the start of `s`.

**Why this is a mistake:**
`TrimLeft` and `TrimRight` remove leading or trailing characters found in a cutset, treated one character at a time, not a literal substring. A call written as if the argument is a prefix or suffix removes more or fewer characters than expected.

**Fix:**
Use `strings.TrimPrefix` and `strings.TrimSuffix` to remove a fixed, literal substring. Reserve `TrimLeft`, `TrimRight`, and `Trim` for cutsets of individual characters.

**Before:**
```go
s := "1234hello"
r := strings.TrimLeft(s, "1234")
// r is "hello", correct here only because none of "hello"'s
// letters appear in the cutset "1234"
```

**After:**
```go
s := "hellohello world"
r := strings.TrimPrefix(s, "hello")
// r is "hello world", the literal prefix is removed once
```

**Related:** [[mistake-33-under-optimized-string-concatenation]]

---

### #33 — Under-optimized string concatenation [verify]

**Pattern to look for:**
- A loop that builds a string with the `+=` operator on each iteration.
- Repeated string concatenation with no size estimate for the final result.
- Benchmark or profile output that shows many allocations from a string-building loop.

**Why this is a mistake:**
A Go string is immutable, so each `+=` concatenation allocates a new string and copies the old content into it. A loop with many iterations pays for an allocation and a copy at every step.

**Fix:**
Use `strings.Builder` to append parts without repeated allocation, and call `Grow` with an estimated final size when known.

**Before:**
```go
var s string
for _, w := range words {
    s += w
}
// each += allocates a new string and copies prior content
```

**After:**
```go
var sb strings.Builder
sb.Grow(estimatedLen)
for _, w := range words {
    sb.WriteString(w)
}
s := sb.String()
```

**Related:** [[mistake-34-useless-string-conversions]]

---

### #34 — Useless string conversions [verify]

**Pattern to look for:**
- A call to a `strings` package function on a value first converted from `[]byte` to `string`.
- Code that converts `[]byte` to `string` only to pass the result to a function with a `[]byte` equivalent, such as `bytes.Contains`.
- Repeated conversion between `string` and `[]byte` inside a hot loop.

**Why this is a mistake:**
A conversion between `string` and `[]byte` copies the full backing data. A conversion made only to call a function with a direct `[]byte` equivalent in the `bytes` package pays for a copy with no benefit.

**Fix:**
Call the `bytes` package function directly on a `[]byte` value instead of converting to `string` first. Keep the value in one form through a full processing path when possible.

**Before:**
```go
b := []byte("hello world")
if strings.Contains(string(b), "world") {
    // string(b) copies the full byte slice, no benefit here
    fmt.Println("found")
}
```

**After:**
```go
b := []byte("hello world")
if bytes.Contains(b, []byte("world")) {
    fmt.Println("found")
}
```

**Related:** [[mistake-33-under-optimized-string-concatenation]]

---

### #35 — Substring and memory leaks [verify]

**Pattern to look for:**
- A substring built with `s[low:high]` from a much larger source string, kept for a long time.
- Code that extracts a short token from a large input string and stores the extracted substring, not a copy.
- A long-lived cache or index that holds substrings sliced from short-lived, large source strings.

**Why this is a mistake:**
A substring in Go shares the backing byte array of its source string. The garbage collector cannot free the full source array while any substring of it stays reachable, so memory use grows over time.

**Fix:**
Copy the needed bytes into a new string, such as with `strings.Clone`, then let the source string go out of scope.

**Before:**
```go
func firstWord(s string) string {
    return s[:5]
}
// return value still references the full backing array of s
```

**After:**
```go
func firstWord(s string) string {
    return strings.Clone(s[:5])
}
// strings.Clone copies the bytes into a fresh, right-sized array
```

**Related:** [[mistake-21-slices-and-memory-leaks]], [[mistake-36-passing-a-byte-slice-to-a-function-that-keeps-a-reference]]

---

### #36 — Passing a byte slice to a function that keeps a reference [verify][low-confidence]

**Pattern to look for:**
- A `[]byte` argument passed to a function that stores the slice in a struct field or a package-level variable.
- A caller that reuses or overwrites the same byte buffer after a call that stored a reference to it.
- No copy made at the boundary where a byte slice moves from a short-lived buffer into a long-lived structure.

**Why this is a mistake:**
A `[]byte` argument is a reference to shared backing data, not a copy. A function that stores the slice without a copy exposes the caller's later writes to that buffer, or blocks the buffer's backing array from garbage collection.

**Fix:**
Copy the byte slice with `bytes.Clone` at the point where a function stores the data for later use.

**Before:**
```go
type Cache struct {
    data []byte
}

func (c *Cache) Store(b []byte) {
    c.data = b
    // stores a reference; a caller that reuses b corrupts c.data
}
```

**After:**
```go
type Cache struct {
    data []byte
}

func (c *Cache) Store(b []byte) {
    c.data = bytes.Clone(b)
    // a fresh copy protects the cache from the caller's buffer reuse
}
```

**Related:** [[mistake-35-substring-and-memory-leaks]]
