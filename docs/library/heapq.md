---
description: The native heapq and bisect modules, as CPython 3.15's, heaps kept in lists and binary search in sorted lists, and how a class's objects are ordered for them.
keywords: heapq, bisect, heapq.heappush, heapq.heappop, heapq.heapify, heapq.heapreplace, heapq.heappushpop, heapq.heapify_max, heapq.heappush_max, heapq.heappop_max, heapq.heapreplace_max, heapq.heappushpop_max, heapq.nlargest, heapq.nsmallest, heapq.merge, bisect.bisect_left, bisect.bisect_right, bisect.insort, bisect.insort_left, bisect.insort_right, priority queue
---
# heapq and bisect

`heapq` keeps a binary heap in a list, so that `h[0]` is always its least item; `bisect` finds
positions in a sorted list and inserts in order. Both are native and have every name of
CPython 3.15's modules, with its results, tie order, exceptions and messages (see
[The library](index.md), `jac docs library`).

```jac
import heapq;
import bisect;

obj Task(Ordered) {
    has cost: int,
        name: str;

    def __lt__(o: Task) -> bool {
        return self.cost < o.cost;
    }
}

with entry {
    h: list[int] = [];
    for n in [5, 1, 4, 2, 3] {
        heapq.heappush(h, n);
    }
    print(heapq.heappop(h), heapq.heappushpop(h, 0), heapq.heapreplace(h, 9), h[0]);
    m = [3, 1, 2];
    heapq.heapify_max(m);
    print(
        heapq.heappop_max(m), heapq.nlargest(2, [5, 1, 9]), heapq.nsmallest(1, ["bb", "a"], key=len)
    );
    print(list(heapq.merge([1, 4], [2, 3], [0])));
    tasks: list[Task] = [];
    heapq.heappush(tasks, Task(cost=2, name="write"));
    heapq.heappush(tasks, Task(cost=1, name="plan"));
    print(heapq.heappop(tasks).name);
    xs = [1, 3, 3, 7];
    print(bisect.bisect_left(xs, 3), bisect.bisect_right(xs, 3), bisect.bisect(xs, 3, lo=0, hi=2));
    bisect.insort(xs, 5);
    print(xs, bisect.bisect_left(["a", "bb", "ccc"], 2, key=len));
    try {
        bisect.bisect_left(xs, 1, lo=-1);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
1 0 2 3
3 [9, 5] ['a']
[0, 1, 2, 3, 4]
plan
1 3 2
[1, 3, 3, 5, 7] 1
ValueError: lo cannot be negative
```

## What is there

| Module | Names |
|---|---|
| `heapq` | `heappush`, `heappop`, `heapify`, `heapreplace`, `heappushpop`; Python 3.14's max-heap forms `heappush_max`, `heappop_max`, `heapify_max`, `heapreplace_max`, `heappushpop_max`; `nlargest(n, iterable, key=None)`, `nsmallest(...)`, `merge(*iterables, key=None, reverse=False)` |
| `bisect` | `bisect_left`, `bisect_right` (and `bisect`), `insort_left`, `insort_right` (and `insort`), each with `lo`, `hi` and `key=` |

As in CPython:

- Items are compared with `<` only, in CPython's order of comparisons, so ties come out as
  CPython's do, and `merge` keeps equal items in the order of its inputs.
- Popping an empty heap raises `IndexError: index out of range`. Items with no order between
  them raise `TypeError: '<' not supported between instances of 'float' and 'str'`. A `__lt__`
  that changes the heap's size while it is used raises
  `RuntimeError: list changed size during iteration`.
- `lo` below 0 raises `ValueError: lo cannot be negative`, and a `hi` past the end
  `IndexError: list index out of range`.

## A heap of objects

Every function is compiled for the type of the items it is given, and that type must be ordered:
a number, a str, bytes, a tuple or a list, or a class that lists the interface `Ordered` and
defines `__lt__` taking its own type, as `Task` above does. A class that defines `__lt__` without
listing `Ordered` is refused (E1283):

```jac
# expect: E1283
import heapq;

obj Job {
    has n: int = 0;

    def __lt__(o: Job) -> bool {
        return self.n < o.n;
    }
}

with entry {
    jobs: list[Job] = [];
    heapq.heappush(jobs, Job(n=1));
}
```

A list of `(priority, item)` tuples is the other common form: tuples compare item by item. The
interfaces are described with [Interfaces](../language/interfaces.md)
(`jac docs interfaces`).

## Differences from CPython

Because each function is compiled for its item type, the functions are not values:
`push = heapq.heappush;` is refused (E5090). Call them, or wrap the call in a lambda.

## Where to go next

- `list.sort`, `sorted`, `min` and `max`: [list methods](list-methods.md),
  [Builtin functions](builtins.md).
- A double-ended queue: `deque` in [collections](collections.md).
