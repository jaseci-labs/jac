---
description: The methods and operators of dict and its views, with their signatures and where they differ from Python's.
keywords: dict methods, dict.get, dict.items, dict.keys, dict.values, dict.pop, dict.popitem, dict.setdefault, dict.update, dict.clear, dict.copy, dict.fromkeys
---
# dict methods

A `dict[K, V]` maps keys of type `K` to values of type `V` and keeps the order in which keys
were first inserted. It has every method of Python's `dict`.

## Operators

| Expression | Result |
|---|---|
| `d[k]` | The value for `k`; `KeyError` when it has none |
| `d[k] = v`, `del d[k]` | Sets or removes an entry |
| `k in d` | Whether `d` has the key |
| `len(d)`, `for k in d` | The number of entries; the keys in insertion order |
| `d \| e`, `d \|= e` | A new dict with `e`'s entries over `d`'s; the same in place |
| `d == e` | Equal entries, in any order |
| `{k: v for ...}`, `{**d, k: v}` | A dict comprehension; a dict display that spreads another |

## Methods

| Method | Result |
|---|---|
| `d.get(k, default=None)` | The value for `k`, or `default` |
| `d.setdefault(k, default)` | The value for `k`, first storing `default` when it has none |
| `d.pop(k)`, `d.pop(k, default)` | Removes `k` and returns its value; without a default, `KeyError` when it has none |
| `d.popitem()` | Removes and returns the last `(key, value)` inserted; `KeyError` when empty |
| `d.update(other, **kwargs)` | Adds the entries of a dict or of an iterable of pairs, then the keyword arguments |
| `d.keys()`, `d.values()`, `d.items()` | Live views of the keys, the values and the `(key, value)` pairs |
| `d.copy()` | A new dict with the same entries (a shallow copy) |
| `d.clear()` | Removes every entry |
| `dict.fromkeys(keys, value=None)` | A new dict with each key of an iterable mapped to `value` |

A view follows the dict as it changes, supports `len`, `in` and iteration, and prints as
`dict_keys(['a', 'b'])`, `dict_values([1, 2])` or `dict_items([('a', 1), ('b', 2)])`. A keys
view and an items view take the set operators (`d.keys() & {"a"}`,
`d.items() - {("a", 1)}`), giving a set. `d | e` keeps `d`'s key order and adds `e`'s new keys
after it, with `e`'s values for the keys both have. A pair of another length given to `update`
raises `ValueError: dictionary update sequence element #0 has length 3; 2 is required`.

```jac
with entry {
    d = {"a": 1, "b": 2};
    d["c"] = 3;
    print(d, d["a"], d.get("z"), d.get("z", 0), "a" in d, len(d));
    print(list(d.keys()), list(d.values()), list(d.items()), d.keys() & {"a", "z"});
    removed = d.pop("a");
    print(removed, d.pop("zz", -1), d.setdefault("q", 7));
    last = d.popitem();
    print(last, d);
    d.update({"k": 1}, z=2);
    d.update([("p", 9)]);
    print(d, d | {"b": 0}, dict.fromkeys(["x", "y"], 0), d == d.copy());
    for (key, value) in d.items() {
        print(key, value, end="; ");
    }
    print();
    squares = {n: n * n for n in range(4) if n};
    del squares[1];
    print(squares, {**squares, 9: 81}, sorted(d, key=lambda (k: str) -> int { return -d[k]; }));
    try {
        print(d["missing"]);
    } except KeyError as e {
        print("KeyError:", e);
    }
}
```

```output
{'a': 1, 'b': 2, 'c': 3} 1 None 0 True 3
['a', 'b', 'c'] [1, 2, 3] [('a', 1), ('b', 2), ('c', 3)] {'a'}
1 -1 7
('q', 7) {'b': 2, 'c': 3}
{'b': 2, 'c': 3, 'k': 1, 'z': 2, 'p': 9} {'b': 0, 'c': 3, 'k': 1, 'z': 2, 'p': 9} {'x': 0, 'y': 0} True
b 2; c 3; k 1; z 2; p 9; 
{2: 4, 3: 9} {2: 4, 3: 9, 9: 81} ['p', 'c', 'b', 'z', 'k']
KeyError: 'missing'
```

## Where it differs from Python

- **A dict has one key type and one value type.** `{"a": 1, "b": "x"}` is a
  `dict[str, int | str]`; values of any kind need `dict[str, any]`. An empty `{}` needs an
  annotation (`d: dict[str, int] = {};`); without one it is refused (W1051).
- **A key must be hashable.** A list used as a key raises `TypeError: unhashable type: 'list'`
  as the program runs, as in Python.
- **Changing a dict while a loop iterates it** raises `RuntimeError` at the loop's next step,
  as in CPython: `dictionary changed size during iteration` when its size changed. A change
  that keeps the size (one key deleted, another added) raises
  `RuntimeError: dictionary keys changed during iteration` when the deleted key was not the
  last one, where CPython walks on past it; when it was the last, the loop goes on and visits
  the new key, as in CPython. A loop left with `break` right after the change raises nothing.
  Iterate over
  `list(d)` to add or remove keys in the loop.
- **`reversed(d)` is not supported**: write `reversed(list(d))`.
- `collections.defaultdict`, `Counter` and `OrderedDict` are objects of their own, not dicts:
  see [collections](collections.md).

## Where to go next

- `dict(...)`, `len`, `sorted`, `zip`: [Builtin functions](builtins.md).
- [set methods](set-methods.md), [list methods](list-methods.md).
- Reading and writing dicts as text: [json](json.md).
