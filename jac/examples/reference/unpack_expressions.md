**Unpack Expressions**

Unpack expressions use the `*` and `**` operators to expand collections inline, enabling concise collection composition and flexible function calls.

**Function Definition**

Lines 3-5 define a function that takes four integer parameters (`a`, `b`, `c`, `d`) and returns their sum. This function will be used to demonstrate unpacking in function calls.

**List Unpacking with Asterisk**

Lines 9-11 demonstrate list unpacking using `*`. Line 11 shows `[*list1, *list2]`, which unpacks both lists into a new list:
- `*list1` expands to elements: `1, 2, 3`
- `*list2` expands to elements: `4, 5, 6`
- Combined result: `[1, 2, 3, 4, 5, 6]`

This provides a clean way to concatenate lists without using the `+` operator or `extend()` method.

**Dictionary Unpacking with Double Asterisk**

Lines 14-16 demonstrate dictionary unpacking using `**`. Line 16 shows `{**dict1, **dict2}`, which unpacks both dictionaries into a new dictionary:
- `**dict1` expands to key-value pairs: `'a': 1, 'b': 2`
- `**dict2` expands to key-value pairs: `'c': 3, 'd': 4`
- Merged result: `{'a': 1, 'b': 2, 'c': 3, 'd': 4}`

If both dictionaries had the same key, the rightmost dictionary's value would take precedence.

**Unpacking in Function Calls**

Lines 19-20 demonstrate unpacking dictionaries as keyword arguments. Line 19: `result1 = compute(**merged);`
- `merged` is `{'a': 1, 'b': 2, 'c': 3, 'd': 4}`
- `**merged` unpacks to keyword arguments: `a=1, b=2, c=3, d=4`
- Calls: `compute(a=1, b=2, c=3, d=4)`
- Returns: `1 + 2 + 3 + 4 = 10`

Line 20: `result2 = compute(**dict1, **dict2);`
- `**dict1` provides: `a=1, b=2`
- `**dict2` provides: `c=3, d=4`
- Same result: `10`

This allows you to pass collected arguments to functions without explicitly naming each parameter.

**Unpacking Operators**

| Operator | Works With | Use Case | Example |
|----------|-----------|----------|---------|
| `*` | Sequences (lists, tuples) | Expand elements | `[*list1, *list2]` |
| `**` | Mappings (dictionaries) | Expand key-value pairs | `{**dict1, **dict2}` |

**Multiple Unpacking**

You can unpack multiple collections in a single expression:
- Lists: `[*a, *b, *c]` combines three lists
- Dicts: `{**x, **y, **z}` merges three dictionaries
- Function calls: `func(**d1, **d2)` passes arguments from two dicts

**Literal Collection Building**

Unpacking is powerful for building collections with mixed content:

**Common Use Cases**

| Use Case | Example | Benefit |
|----------|---------|---------|
| Concatenate lists | `[*list1, *list2]` | Cleaner than `list1 + list2` |
| Merge configs | `{**defaults, **overrides}` | Override precedence |
| Pass collected args | `func(**kwargs)` | Flexible function calls |
| Copy with modifications | `{**original, 'key': new_val}` | Update while copying |

**Example Execution**

Line 22 prints all results from lines 11, 16, 19, and 20:
- `combined` = [1, 2, 3, 4, 5, 6]
- `merged` = {'a': 1, 'b': 2, 'c': 3, 'd': 4}
- `result1` = 10
- `result2` = 10

**Shallow Copy Semantics**

When unpacking creates a new collection, it performs a shallow copy:
- New outer collection is created
- Elements/values themselves are not copied (references are copied)
- Modifying nested objects affects both collections

**Practical Examples**

Combining configuration:

Building lists with interspersed values:

Passing function arguments:

These unpacking operators make collection manipulation more concise and expressive in Jac.
