---
description: The methods and operators of list, with their signatures and where they differ from Python's.
keywords: list methods, list.append, list.extend, list.insert, list.pop, list.remove, list.clear, list.copy, list.count, list.index, list.reverse, list.sort
---
# list methods

A `list[T]` is a mutable sequence of items of one type `T`. It has all eleven methods of
Python's `list`, with Python's results and error messages.

## Operators

| Expression | Result |
|---|---|
| `xs + ys`, `xs * n` | A new list: concatenation, repetition |
| `xs[i]`, `xs[a:b:c]` | An item (`IndexError` out of range), a new list |
| `xs[i] = v`, `xs[a:b] = ys` | Replaces an item, or a slice by the items of a list |
| `del xs[i]`, `del xs[a:b:c]` | Removes an item or a slice |
| `xs += ys`, `xs *= n` | Extends or repeats in place |
| `v in xs` | Whether an item equals `v` |
| `xs == ys`, `xs < ys` | Comparison item by item |
| `[f(x) for x in it if cond]` | A list comprehension |

An index past either end raises `IndexError: list index out of range` when read and
`IndexError: list assignment index out of range` when stored to, and a failed store leaves the
list as it was. A list held in an `any` is indexed by the same rules, with the same messages.

## Methods

| Method | Result |
|---|---|
| `xs.append(v)` | Adds `v` at the end |
| `xs.extend(ys)` | Adds the items of the list `ys` at the end |
| `xs.insert(i, v)` | Inserts `v` before position `i`; a position past either end is clamped |
| `xs.pop(i=-1)` | Removes and returns the item at `i`; `IndexError` when the list is empty or `i` is out of range |
| `xs.remove(v)` | Removes the first item equal to `v`; `ValueError` when there is none |
| `xs.clear()` | Removes every item |
| `xs.copy()` | A new list with the same items (a shallow copy) |
| `xs.count(v)` | How many items equal `v` |
| `xs.index(v, start=0, stop=len)` | The position of the first item equal to `v`; `ValueError` when there is none |
| `xs.reverse()` | Reverses the list in place |
| `xs.sort(key=None, reverse=False)` | Sorts the list in place. The sort is stable |

```jac
with entry {
    xs = [3, 1, 2];
    xs.append(5);
    xs.extend([4, 1]);
    xs.insert(0, 9);
    print(xs, xs.index(2), xs.count(1), len(xs));
    last = xs.pop();
    first = xs.pop(0);
    print(last, first, xs);
    xs.sort();
    print(xs, xs[::-1], xs[1:3], 4 in xs, xs + [0], xs * 2 == xs + xs);
    xs.sort(key=lambda (x: int) -> int { return abs(x - 3); }, reverse=True);
    xs.remove(5);
    print(xs);
    xs[1:3] = [7];
    del xs[0];
    xs.reverse();
    print(xs, xs.copy() == xs, [x * x for x in xs if x > 3]);
    words = ["bb", "a", "ccc"];
    words.sort(key=len);
    print(words, sorted(words, reverse=True), [1, 2] < [1, 3]);
    try {
        xs.remove(100);
    } except ValueError as e {
        print(e);
    }
    try {
        print(xs[10]);
    } except IndexError as e {
        print(e);
    }
}
```

```output
[9, 3, 1, 2, 5, 4, 1] 3 2 7
1 9 [3, 1, 2, 5, 4]
[1, 2, 3, 4, 5] [5, 4, 3, 2, 1] [2, 3] True [1, 2, 3, 4, 5, 0] True
[1, 2, 4, 3]
[3, 7] True [49]
['a', 'bb', 'ccc'] ['ccc', 'bb', 'a'] True
list.remove(x): x not in list
list index out of range
```

## Where it differs from Python

- **A list has one item type.** `[1, "a"]` is a `list[int | str]`; a list that holds anything
  is a `list[any]`. An empty `[]` takes its item type from an annotation (`xs: list[int] = [];`) or
  from what the code then puts in it.
- **`extend` and `+=` take a list**, not any iterable. A tuple, a set, a range, a str or a
  generator is a compile error (E1001, E1110): convert it first.

  ```jac
  # expect: E1001, E1110
  with entry {
      xs = [1];
      xs.extend((2, 3));
      rows = [{"n": 2}, {"n": 1}];
      rows.sort();
  }
  ```

  Write `xs.extend(list(other))`, which takes any iterable.
- **A starred target is not supported**: `(first, *rest) = xs` is refused (E0130). Write
  `first = xs[0]; rest = xs[1:];`.
- **Sorting items whose type has no order is a compile error** (E1110), where Python raises
  `TypeError` as the line runs: `xs.sort()` of objects of a class with neither `__lt__` nor
  `__gt__`, of dicts or of `None`s. A `key=` gives them one. Where the type does not say
  (an int and a str in a `list[any]`), the sort raises `TypeError` as the program runs. A
  list of sets, or of an enum's int members, is not sorted yet (E5090).

## Where to go next

- `len`, `sorted`, `reversed`, `enumerate`, `zip`, `sum`, `min`, `max`:
  [Builtin functions](builtins.md).
- Other containers: [tuple, range and slice](tuple-methods.md), [dict](dict-methods.md),
  [set](set-methods.md). Queues and heaps: [collections](collections.md) and
  [heapq and bisect](heapq.md). Copies: [copy](copy.md).
