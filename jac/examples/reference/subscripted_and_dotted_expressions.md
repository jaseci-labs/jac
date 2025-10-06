**Subscripted and Dotted Expressions**

Subscripted and dotted expressions provide syntax for accessing collection elements and object attributes, forming the foundation of data access in Jac.

**Object Definition**

Lines 3-7 define a `Sample` object with three attributes:
- `items`: a list initialized to `[10, 20, 30, 40, 50]`
- `data`: a dictionary initialized to `{"name": "Alice", "age": 30}`
- `value`: an integer initialized to `42`

Line 10 creates an instance of this object for demonstration.

**Dotted Expressions (Attribute Access)**

Line 13 demonstrates dot notation: `val = s.value;`

The dot operator `.` accesses an attribute on an object:
- `s` - The object instance
- `.value` - The attribute name
- Result: 42

This is the standard way to access object attributes in Jac.

**Subscripted Expressions (Index/Key Access)**

Lines 16-18 demonstrate subscript notation with square brackets `[...]`:

| Line | Expression | Type | Result |
|------|------------|------|--------|
| 16 | `s.items[0]` | List index | 10 (first element) |
| 17 | `s.items[-1]` | Negative index | 50 (last element) |
| 18 | `s.data["name"]` | Dictionary key | "Alice" |

For lists, subscripts use zero-based integer indexing. Negative indices count from the end (-1 is the last element).

For dictionaries, subscripts use keys to access associated values.

**Slicing Syntax**

Lines 21-23 demonstrate slice operations on lists:

| Line | Slice | Start | End | Result |
|------|-------|-------|-----|--------|
| 21 | `s.items[1:4]` | 1 | 4 | `[20, 30, 40]` (indices 1, 2, 3) |
| 22 | `s.items[:3]` | 0 | 3 | `[10, 20, 30]` (beginning to index 3) |
| 23 | `s.items[2:]` | 2 | end | `[30, 40, 50]` (index 2 to end) |

Slice syntax is `[start:end]` where:
- `start` is inclusive (included in result)
- `end` is exclusive (not included in result)
- Omitting `start` defaults to beginning (0)
- Omitting `end` defaults to end of list

**Chained Access**

Line 26 shows chaining operations: `first_char = s.data["name"][0];`

Execution left-to-right:
1. `s.data` - Access data attribute (returns dictionary)
2. `["name"]` - Get value for key "name" (returns "Alice")
3. `[0]` - Get first character (returns "A")

Chaining allows you to access nested data structures in a single expression.

**Null-Safe Access**

Line 29 demonstrates null-safe access: `safe_val = s?.value;`

The `?.` operator:
- Accesses the attribute if the object is not None
- Returns None if the object is None (instead of raising an error)
- Useful for optional attributes or nullable objects

This prevents `AttributeError` when the object might be None.

**Subscript Type Behaviors**

Different types handle subscripts differently:

| Type | Subscript | Example | Result |
|------|-----------|---------|--------|
| List | Integer index | `[10, 20, 30][1]` | `20` |
| Tuple | Integer index | `(10, 20, 30)[1]` | `20` |
| String | Integer index | `"hello"[1]` | `"e"` |
| Dictionary | Key | `{"a": 1}["a"]` | `1` |

Negative indices work for ordered sequences (lists, tuples, strings) but not dictionaries.

**Complete Example Flow**

Line 31 prints all the values extracted in lines 13-29:
- `val` = 42
- `item1` = 10
- `item2` = 50
- `name` = "Alice"
- `slice1` = [20, 30, 40]
- `slice2` = [10, 20, 30]
- `slice3` = [30, 40, 50]
- `first_char` = "A"
- `safe_val` = 42

**Common Patterns**

Combining dot and subscript notation enables powerful data access:

These expressions form the basis for navigating complex data structures in Jac programs.
