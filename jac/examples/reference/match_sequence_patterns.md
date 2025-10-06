Sequence patterns enable pattern matching against ordered collections like lists and tuples, allowing you to check structure, extract elements, and handle variable-length sequences.

**What are Sequence Patterns?**

Sequence patterns match ordered collections by checking both the number of elements and their values. They can destructure sequences, binding individual elements to variables for use in the case body.

**Exact Sequence Match**

Lines 5-11 demonstrate the most basic sequence pattern - matching an exact sequence:

```mermaid
graph TD
    A[data = [1,2,3]] --> B{Is it a sequence?}
    B -->|Yes| C{Length is 3?}
    C -->|Yes| D{[0]=1, [1]=2, [2]=3?}
    D -->|Yes| E[Match! Execute case]
    B -->|No| F[No match]
    C -->|No| F
    D -->|No| F
```

| Pattern (Line 7) | Requirements | Example Match |
|------------------|--------------|---------------|
| `case [1, 2, 3]:` | Sequence with exactly these 3 values | `[1, 2, 3]` |

For a match, ALL of these must be true:
- Value is a sequence (list, tuple, etc.)
- Length is exactly 3
- First element equals 1
- Second element equals 2
- Third element equals 3

**Variable Binding in Sequences**

Lines 14-18 show how to extract sequence elements into variables:

| Pattern (Line 16) | What It Does | Variables Created |
|-------------------|--------------|-------------------|
| `case [a, b, c]:` | Match 3-element sequence | `a=10, b=20, c=30` |

This pattern:
1. Checks the sequence has exactly 3 elements
2. Binds first element to `a`
3. Binds second element to `b`
4. Binds third element to `c`

All three variables are then available in the case body (line 17).

**Star Pattern - Capturing Variable-Length Sequences**

Lines 21-25 introduce the star pattern (`*`) for matching sequences of variable length. Pattern: `case [first, *middle, last]:`

```mermaid
graph LR
    A[List: [1,2,3,4,5]] --> B[first = 1]
    A --> C[middle = [2,3,4]]
    A --> D[last = 5]
```

| Component | Matches | Example (list = [1,2,3,4,5]) |
|-----------|---------|------------------------------|
| `first` | First element | `first = 1` |
| `*middle` | Zero or more middle elements | `middle = [2, 3, 4]` |
| `last` | Last element | `last = 5` |

The star pattern can capture any number of elements, including zero:
- `[1, 2, 3, 4, 5]` → `middle = [2, 3, 4]`
- `[1, 5]` → `middle = []` (empty list)

**Star Pattern at Beginning**

Lines 28-32 show placing the star pattern at the start. Pattern: `case [*start, 4]:`

| Component | What It Captures | Example (nums = [1,2,3,4]) |
|-----------|------------------|----------------------------|
| `*start` | All elements except last | `start = [1, 2, 3]` |
| `4` | Last element must be 4 | Literal match |

This is useful when you know how the sequence ends but not how it begins.

**Star Pattern in Middle**

Lines 35-39 demonstrate using star pattern with specific values on both ends. Pattern: `case [10, *rest, 50]:`

```mermaid
graph TD
    A[values = [10,20,30,40,50]] --> B[Check first = 10]
    A --> C[Check last = 50]
    A --> D[Capture middle in rest]
    B --> E{Both match?}
    C --> E
    E -->|Yes| F[rest = [20,30,40]]
```

| Element | Pattern | Value |
|---------|---------|-------|
| First | `10` | Must be 10 |
| Middle | `*rest` | `[20, 30, 40]` |
| Last | `50` | Must be 50 |

**Mixed Type Sequences**

Lines 42-46 show that sequence patterns work with heterogeneous sequences (different types):

| Position | Pattern | Type | Value |
|----------|---------|------|-------|
| 0 | `1` | int | Literal 1 |
| 1 | `str_val` | any | Variable binding |
| 2 | `float_val` | any | Variable binding |

Pattern `case [1, str_val, float_val]:` matches the sequence `[1, "hello", 3.14]` and creates:
- `str_val = "hello"`
- `float_val = 3.14`

**Sequence Pattern Rules**

| Rule | Explanation |
|------|-------------|
| **Exact length** | Without `*`, sequence must have exact number of elements |
| **Variable length** | With `*`, sequence can have any length ≥ fixed elements |
| **Type flexibility** | Works with lists, tuples, and other sequences |
| **Element types** | Elements can be any type |
| **One star only** | Maximum one `*` pattern per sequence |
| **Order matters** | Elements must match in order |

**Star Pattern Behavior**

The star pattern (`*name`) has special characteristics:

| Scenario | Star Pattern Captures |
|----------|----------------------|
| More elements than needed | Extra elements |
| Exact number of elements | Empty list `[]` |
| Cannot capture | Pattern fails |

Examples with pattern `[first, *middle, last]`:
- `[1, 2, 3, 4]` → `middle = [2, 3]`
- `[1, 2]` → `middle = []`
- `[1]` → No match (need at least 2 elements)

**Sequence vs Tuple**

Both lists and tuples match sequence patterns:

| Input Type | Pattern | Matches? |
|------------|---------|----------|
| `[1, 2, 3]` (list) | `case [1, 2, 3]:` | Yes |
| `(1, 2, 3)` (tuple) | `case [1, 2, 3]:` | Yes |
| `[1, 2, 3]` (list) | `case (1, 2, 3):` | Yes |
| `(1, 2, 3)` (tuple) | `case (1, 2, 3):` | Yes |

The pattern syntax doesn't distinguish between lists and tuples.

**Common Patterns**

| Pattern | Use Case | Example |
|---------|----------|---------|
| `[first, *rest]` | Head and tail | `first=1, rest=[2,3,4]` |
| `[*init, last]` | All but last | `init=[1,2,3], last=4` |
| `[a, b]` | Exactly two | Coordinates, pairs |
| `[*all]` | Capture entire sequence | `all=[1,2,3,4]` |
| `[x, x, x]` | Three identical | (Doesn't work - x can't repeat) |

**Practical Examples**

| Lines | Pattern Type | Use Case |
|-------|--------------|----------|
| 5-11 | Exact match | Validate specific sequence |
| 14-18 | Variable binding | Extract all elements |
| 21-25 | Middle star | Get first, last, and rest |
| 28-32 | Beginning star | Check end, capture start |
| 35-39 | Specific endpoints | Match known start/end |
| 42-46 | Mixed types | Heterogeneous sequences |

**Limitations**

Important things sequence patterns CANNOT do:

| Limitation | Explanation |
|------------|-------------|
| Multiple stars | Only one `*` per pattern |
| Repeated variables | Can't use same variable twice |
| Range matching | Can't specify "3-5 elements" |
| Conditional elements | Each position must have a pattern |

**When to Use Sequence Patterns**

| Scenario | Pattern Example |
|----------|-----------------|
| Fixed structure | `case [x, y, z]:` |
| Extract first/last | `case [first, *_, last]:` |
| Process head/tail | `case [head, *tail]:` |
| Skip elements | `case [_, important, _]:` |
| Variable length | `case [required, *optional]:` |

**Example Summary**

This file demonstrates six key sequence pattern techniques:

1. **Exact matching** (lines 5-11) - Validate specific values
2. **Variable binding** (lines 14-18) - Extract elements
3. **Star in middle** (lines 21-25) - Capture variable middle
4. **Star at start** (lines 28-32) - Capture variable beginning
5. **Star with endpoints** (lines 35-39) - Fixed start and end
6. **Mixed types** (lines 42-46) - Heterogeneous sequences

Each technique serves different pattern matching needs, from simple validation to complex element extraction.
