---
description: The native functools module, as CPython's functools, how its caches are applied without decorators, and the names left out.
keywords: functools, functools.reduce, functools.partial, functools.lru_cache, functools.cache, functools.cmp_to_key, functools.Placeholder, functools.wraps, functools.update_wrapper, functools.total_ordering, functools.cached_property, functools.partialmethod, functools.singledispatch, functools.singledispatchmethod, functools.WRAPPER_ASSIGNMENTS, functools.WRAPPER_UPDATES, cache_info, cache_clear
---
# functools

`functools` has `reduce`, `partial`, `lru_cache`, `cache`, `cmp_to_key` and `Placeholder` of
CPython's `functools`, with CPython's results, exceptions and messages. It is native (see
[The library](index.md), `jac docs library`). Its decorators that change a function or a class
as the program runs are left out, and the caches are applied by a call rather than with `@`.

```jac
import from functools { reduce, partial, lru_cache, cmp_to_key, Placeholder }

def fib_of(n: int) -> int {
    return n if n < 2 else fib(n - 1) + fib(n - 2);
}

glob fib = lru_cache(maxsize=32)(fib_of);

def power(base: int, exp: int) -> int {
    return base ** exp;
}

def by_len(a: str, b: str) -> int {
    return len(a) - len(b);
}

with entry {
    print(reduce(lambda (a: int, b: int) -> int { return a + b; }, [1, 2, 3, 4], 10));
    cube = partial(power, exp=3);
    print(cube(2), cube.keywords, partial(power, 2)(10), partial(power, Placeholder, 2)(5));
    print(fib(30), fib.cache_info());
    print(sorted(["ccc", "a", "bb"], key=cmp_to_key(by_len)));
}
```

```output
20
8 {'exp': 3} 1024 25
832040 CacheInfo(hits=28, misses=31, maxsize=32, currsize=31)
['a', 'bb', 'ccc']
```

## What is there

| Name | What it is |
|---|---|
| `reduce(function, iterable, initial)` | Folds an iterable; `initial` positional or by keyword. An empty iterable with no initial raises `TypeError: reduce() of empty iterable with no initial value` |
| `partial(func, *args, **keywords)` | A callable with some arguments fixed: `func`, `args`, `keywords`; a partial of a partial is flattened |
| `Placeholder` | Python 3.14's marker for a positional argument a `partial` leaves open |
| `lru_cache(maxsize=128, typed=False)` | Returns a wrapper maker: `lru_cache(maxsize=32)(f)`. The wrapper has `cache_info()`, `cache_clear()`, `cache_parameters()` and `__wrapped__` |
| `cache(f)` | `lru_cache(maxsize=None)(f)` |
| `cmp_to_key(mycmp)` | A key function from a comparison function |
| `WRAPPER_ASSIGNMENTS`, `WRAPPER_UPDATES` | CPython's constants |

The caches behave as CPython's: `typed=True` keeps `1` and `1.0` apart, `maxsize=0` caches
nothing and so does a negative `maxsize`, and an unhashable argument raises
`TypeError: unhashable type: 'list'`. Without `typed`, the keys are CPython's too: a lone `int`
or `str` argument is its own key, so `f(3)` and then `f(3.0)` are two entries, while `f(True)`
and then `f(1.0)` are one. `cache_info()` is also a 4-tuple: `(hits, misses, maxsize,
currsize)`.

`Placeholder` cannot end a partial's positional arguments
(`TypeError: trailing Placeholders are not allowed`) or be passed by keyword, and calling a
partial with a `Placeholder` left unfilled raises `TypeError`.

## Caching a function

A Jac decorator runs as the program compiles (see [Decorators](../language/decorators.md),
`jac docs decorator`), so a run-time
wrapper such as `lru_cache` is applied by calling it. To cache a recursive function, write its
body under one name and bind the cached wrapper to the name the body calls, as a `glob`, as
`fib` above. Writing `@lru_cache` is E1490:

```jac
# expect: E1490
import functools;

@functools.lru_cache(maxsize=None)
def f(n: int) -> int {
    return n;
}

with entry {
    print(f(1));
}
```

## What is left out

These names cannot have their meaning natively and are refused with E5142, whose message says
what to write instead:

| Name | Why | Instead |
|---|---|---|
| `wraps`, `update_wrapper` | A Jac function value has no attributes to copy | Write the wrapper as a function that calls the one it wraps |
| `total_ordering` | It adds methods to a class as the program runs; a Jac class is complete when compiled | Declare `__lt__`, `__le__`, `__gt__` and `__ge__` |
| `cached_property` | Jac has no descriptor protocol | A method that keeps the value in a field the first time |
| `partialmethod` | Jac has no descriptor protocol | A method that calls the other with the arguments it fixes |
| `singledispatch`, `singledispatchmethod` | A Jac type value does not carry a method resolution order | Branch on `isinstance()`, or give each class a method |

```jac
# expect: E5142
import from functools { total_ordering }

with entry {
    print(total_ordering);
}
```
