---
description: The native random module, CPython's Mersenne Twister giving CPython's numbers for a seed, with every function and distribution of CPython's, and where 64-bit ints make it differ.
keywords: random, random.seed, random.random, random.randint, random.randrange, random.uniform, random.choice, random.choices, random.shuffle, random.sample, random.getrandbits, random.randbytes, random.gauss, random.normalvariate, random.expovariate, random.binomialvariate, random.triangular, random.getstate, random.setstate, random.Random, random.SystemRandom
---
# random

`random` is CPython's Mersenne Twister generator, seeded the way CPython seeds it: after
`random.seed(n)`, the same calls give the same numbers as CPython's `random`. It is native (see
[The library](index.md), `jac docs library`). It has every function of CPython's module, the
distributions included.

```jac
import random;

with entry {
    random.seed(42);
    print(random.random(), random.randint(1, 6), random.randrange(0, 100, 5));
    print(random.uniform(1.0, 2.0), random.getrandbits(16));
    xs = [1, 2, 3, 4, 5];
    random.shuffle(xs);
    print(xs, random.choice(["a", "b", "c"]), random.sample([10, 20, 30, 40], 2));
    r = random.Random(7);
    print(r.random(), r.randint(1, 100));
    r.seed(5);
    print(r.random() == random.Random(5).random());
    try {
        random.randint(5, 1);
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
0.6394267984578837 1 40
1.2448918538034763 9144
[4, 2, 3, 5, 1] a [10, 40]
0.32383276483316237 20
True
ValueError: empty range in randint(5, 1)
```

CPython prints the same lines for the same statements.

## What is there

| Name | What it does |
|---|---|
| `seed(a=None, version=2)` | Seeds the module's generator from an `int` or a `str`, as CPython seeds it, or from the system's randomness when `a` is `None` |
| `random()`, `uniform(a, b)`, `triangular(low, high, mode)` | Floats |
| `randint(a, b)`, `randrange(start, stop=None, step=1)`, `getrandbits(k)` | Ints |
| `choice(seq)`, `choices(population, weights=None, *, cum_weights=None, k=1)`, `shuffle(x)`, `sample(population, k, *, counts=None)` | Choosing from a sequence: a list, a tuple, a str, a range |
| `randbytes(n)` | `n` random bytes |
| `gauss`, `normalvariate`, `lognormvariate`, `expovariate`, `vonmisesvariate`, `gammavariate`, `betavariate`, `paretovariate`, `weibullvariate`, `binomialvariate` | The distributions, CPython's algorithms |
| `getstate()`, `setstate(state)` | The generator's state, to save and restore |
| `Random(x=None)` | A generator of its own, with all of the above as methods |
| `SystemRandom` | The same methods over the operating system's randomness (`os.urandom`) |

```jac
import random;

with entry {
    random.seed(42);
    print(random.random(), random.randint(1, 6), random.choice(["a", "b", "c"]));
    print(random.choices(["x", "y"], weights=[3, 1], k=4), random.sample(range(10), 3));
    print(round(random.gauss(0.0, 1.0), 6), round(random.expovariate(2.0), 6), random.randbytes(4));
    r = random.Random(7);
    state = r.getstate();
    first = r.random();
    r.setstate(state);
    print(first == r.random(), random.binomialvariate(10, 0.5) <= 10);
    print(type(random.SystemRandom().random()).__name__);
}
```

```output
0.6394267984578837 1 c
['x', 'x', 'x', 'x'] [8, 1, 6]
0.43476 0.132413 b'D\xe6\x1d\x9a'
True True
float
```

For secrets (tokens, keys), use [`secrets`](stdlib.md), which reads the operating system's
randomness.

## Differences from CPython

- **`getrandbits(k)` takes at most 63 bits**, as an `int` is 64-bit: `random.getrandbits(64)`
  raises `OverflowError: getrandbits() takes at most 63 bits`. `randbytes` gives any number of
  random bytes.
