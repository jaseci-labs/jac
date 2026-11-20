---
description: The native itertools module, as CPython's itertools, its lazy iterator functions and what is left out.
keywords: itertools, itertools.count, itertools.cycle, itertools.repeat, itertools.accumulate, itertools.chain, itertools.compress, itertools.dropwhile, itertools.takewhile, itertools.filterfalse, itertools.groupby, itertools.islice, itertools.pairwise, itertools.starmap, itertools.tee, itertools.zip_longest, itertools.product, itertools.permutations, itertools.combinations, itertools.combinations_with_replacement, itertools.batched, chain.from_iterable
---
# itertools

`itertools` has the iterator functions of CPython's `itertools`, each lazy, taking any iterable
(a list, tuple, str, bytes, range, set, generator, or an `obj` whose `__iter__` is a generator),
with CPython's results, exceptions and messages. It is native (see [The library](index.md),
`jac docs library`).

```jac
import from itertools {
    chain,
    islice,
    count,
    groupby,
    product,
    combinations,
    accumulate,
    batched,
    pairwise,
    zip_longest,
}

with entry {
    print(list(chain([1, 2], (3, 4), "ab")), list(islice(count(10, 5), 3)));
    for (key, grp) in groupby("aaabcc") {
        print(key, len(list(grp)), end=" ");
    }
    print();
    print(list(product("ab", repeat=2)), list(combinations([1, 2, 3], 2)));
    print(list(accumulate([1, 2, 3, 4])), list(batched(range(7), 3)), list(pairwise("abc")));
    print(list(zip_longest([1, 2, 3], ["a"], fillvalue="-")));
    try {
        list(batched("abcd", 3, strict=True));
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
[1, 2, 3, 4, 'a', 'b'] [10, 15, 20]
a 3 b 1 c 2 
[('a', 'a'), ('a', 'b'), ('b', 'a'), ('b', 'b')] [(1, 2), (1, 3), (2, 3)]
[1, 3, 6, 10] [(0, 1, 2), (3, 4, 5), (6,)] [('a', 'b'), ('b', 'c')]
[(1, 'a'), (2, '-'), (3, '-')]
ValueError: batched(): incomplete batch
```

## What is there

| Kind | Functions |
|---|---|
| Infinite | `count(start=0, step=1)`, `cycle(iterable)`, `repeat(object, times=None)` |
| Ending at the shortest input | `accumulate(iterable, func=None, *, initial=None)`, `batched(iterable, n, *, strict=False)`, `chain(*iterables)`, `compress(data, selectors)`, `dropwhile`, `takewhile`, `filterfalse`, `groupby(iterable, key=None)`, `islice`, `pairwise`, `starmap`, `tee(iterable, n=2)`, `zip_longest(*iterables, fillvalue=None)` |
| Combinatoric | `product(*iterables, repeat=1)`, `permutations(iterable, r=None)`, `combinations(iterable, r)`, `combinations_with_replacement(iterable, r)` |

As in CPython: `islice` reads no further than it must; a `groupby` group that is not consumed is
skipped when the next one is asked for; a negative `r`, `repeat` or `n` raises the `ValueError`
CPython words; a value that is not iterable raises `TypeError: 'int' object is not iterable`.

A function argument (`accumulate`'s `func`, `starmap`'s, the predicates) is a Jac function or a
lambda: `accumulate(xs, lambda (a: int, b: int) -> int { return a * b; })`.

## Differences from CPython

- **`repeat(x, None)` repeats forever**, as `repeat(x)` does. In CPython an explicit `None`
  raises `TypeError`.
- **The functions are functions, not classes.** A call returns an iterator, but `chain`,
  `islice` and the rest are not types: `isinstance(x, itertools.chain)` is refused (E5090,
  E1179), and none can be inherited from.
- **What they yield is typed by what they take.** `chain` of lists of `int` yields `int`s;
  `count` yields `any`, and so does what is made from it, which an annotated name narrows
  (`n: int = next(islice(count(), 3));`).

## What is not there

`chain.from_iterable` is left out on purpose: a Jac function has no attributes. Write
`chain(*iterables)`. Naming it is E5142:

```jac
# expect: E5142
import itertools;

with entry {
    print(list(itertools.chain.from_iterable([[1], [2]])));
}
```
