---
description: Memory regions and the in statement that opens one - what a region allocates, when it is freed, partitions, region_of, leaving a region with own() and managed(), and what may not escape.
keywords: region, regions, Region, in r, region_of, partition, managed(), own (), arena
grammar: open_stmt
---
# Memory regions

A region is an arena. `in r { ... }` opens region `r`: every object, list,
string or other heap value the block makes is allocated in `r`, and all of
it is freed together when the region goes, its `__del__` hooks run newest
first. Nothing made in a region may be reached from outside it after that.
The checker refuses the ways of escaping listed under "What may leave a
region" below (E1307).

```jac
obj Res {
    has n: int = 0;

    def __del__ {
        print("  drop", self.n);
    }
}

def main {
    in Region() {
        a = Res(n=1);
        b = Res(n=2);
        print("  in the region", a.n + b.n);
    }
    print("after the region");
}

with entry {
    main();
}
```

```output
  in the region 3
  drop 2
  drop 1
after the region
```

## Syntax

```ebnf
open_stmt ::= "in" expression block
```

The expression is a `Region` (E1197 for anything else). `Region()` makes a
new one. A region may be opened in a function or in module code.

## When a region is freed

- **An anonymous region** (`in Region() { ... }`) is freed as its block
  closes.
- **A named region** (`r: own Region = Region()`) is freed when its handle
  is dropped, at its owner's last use (see [Ownership](ownership.md)): right
  after the `in r` block when that is the last use, later when the handle
  is used again. It may be opened again and again in between.

Freeing a region runs the `__del__` of what it made in reverse order of
making, then gives its memory back to the allocator.

```jac
obj Res {
    has n: int = 0;

    def __del__ {
        print("  drop", self.n);
    }
}

obj Cand {
    has score: int = 0;
}

def seed(r: &Region, s: int) -> Cand {
    in r {
        x = Cand(score=s);
        return x;
    }
}

def named {
    r: own Region = Region();
    in r {
        a = Res(n=3);
        b = Res(n=4);
        print("  in named", a.n + b.n);
    }
    print("  after the open");
    c = seed(&r, 7);
    print("  seeded", c.score, region_of(c) is r);
}

with entry {
    named();
    print("after named");
}
```

```output
  in named 7
  after the open
  seeded 7 True
  drop 4
  drop 3
after named
```

`seed` is lent the region (`r: &Region`). It opens it and returns what it
made there: the value lives in `r`, which its caller still holds, so
nothing escapes.

## What may leave a region

What a region allocates must not be kept anywhere that outlives the open.
The checker refuses (E1307) these stores of it, made inside the open:

- assigning it to a name bound outside the open;
- assigning it to a field of an object from outside (`b.c = Cell()`);
- assigning it to an item or a dict entry of a container from outside
  (`xs[0] = Cell()`, `d["a"] = Cell()`);
- giving it to a method of a list, a dict or a set from outside that keeps
  what it is given (`out.append(x)`, `out.insert(0, x)`, `out.extend(xs)`,
  `d.update(...)`, `d.setdefault(k, x)`, `s.add(x)`), or adding it with
  `out += [x]`;
- returning it from the open.

One route is not refused: a function or a method of the program's own that
keeps what it is passed (`registry.remember(x)`). Keep a region's values
away from those. A value kept that way is still freed when the region goes,
and reading it afterwards is reading freed memory. To keep a value, copy it
out in one of these ways:

| Leaves as | How |
|---|---|
| A scalar (an int, a float, a bool) | Assigned to a name outside: it is copied. |
| An owner outside the region | `own (expr)` copies the value out to an owner. |
| A managed value | `managed(expr)` copies it to the counted heap. |

```jac
obj Res {
    has n: int = 0;

    def __del__ {
        print("  drop", self.n);
    }
}

obj Buffer {
    has n: int = 0;
}

def leaving {
    r: own Region = Region();
    n = 0;
    label = "";
    kept = Buffer();
    in r {
        t = Res(n=20);
        n = t.n;
        label = own ("tag-" + str(t.n));
        kept = managed(Buffer(n=21));
    }
    print(n, label, kept.n, region_of(kept) is None);
}

with entry {
    leaving();
}
```

```output
  drop 20
20 tag-20 21 True
```

A graph grows inside a region as anything does: a walker spawned in an open
makes its nodes there, and they are freed with it. Connecting a node made
outside the region to nodes made in it seals them: they outlive the region,
reachable from that node.

### Regions the compiler opens

A function that makes nodes, connects them only to each other and then
only spawns walkers on them, as statements whose results it does not keep,
gets a region with no `in`: the run of statements from the first node made
to the last spawn is opened in an anonymous region. The nodes are freed
right after the last spawn, the newest first, instead of waiting for the
cycle collector. Anything else done with one of the nodes (a field read, a
call it is passed to, a spawn whose result is kept), a reach for `root` or
`here`, another archetype made in the run, or a `return` out of it leaves
the graph managed.

```jac
node Town {
    has v: int = 0;

    def __del__ {
        print("  drop town", self.v);
    }
}

walker Sum {
    has total: int = 0;

    can add with Town entry {
        self.total += here.v;
        visit [-->];
    }
}

def tour {
    a = Town(v=51);
    b = Town(v=52);
    a ++> b;
    Sum() spawn a;
    print("after spawn");
}

with entry {
    tour();
}
```

```output
  drop town 52
  drop town 51
after spawn
```

## region_of and partitions

- `region_of(x)` is the region `x` was made in, or `None` for the heap. A
  region handle itself is on the heap: `region_of(r)` is `None`.
- `r.partition()` gives a child region; `r.partition(2)` gives a tuple of
  two. The count is a literal (E1314): call `partition()` for each child
  otherwise.
- What is made in a partition is in the partition, not in its parent. A
  partition is reabsorbed by its parent: when the parent goes, the child's
  objects are freed, then the parent's.

```jac
obj Buffer {
    has n: int = 0;
}

def main {
    home: own Region = Region();
    in home {
        m = Buffer(n=1);
        print(region_of(m) is home, region_of(Buffer()) is None);
    }
    print(region_of(Buffer()) is None);
    child: own Region = home.partition();
    (left, right) = home.partition(2);
    in left {
        q = Buffer(n=3);
        print(region_of(q) is left, region_of(q) is home, left is not right);
    }
    print(child is not home, isinstance(child, Region));
}

with entry {
    main();
}
```

```output
True False
True
True False True
True True
```

Inside the open, `Buffer()` is made in `home` too, so its `region_of` is
not `None`; outside, it is.

## Region handles

A handle is an owner like any other (see [Ownership](ownership.md)):

- lent to a function as `&Region`, which may open it;
- moved into a `flow` task (`flow size_of(m)` for `def size_of(r: own
  Region)`), which frees the region and what it holds when the task is
  done;
- frozen with `imm`: a frozen region may be read by a task, and is freed
  when the frozen handle goes.

## What is rejected

```jac
# expect: E1307 x8, E1314, E1197
obj Cell {
    has v: int = 0;
}

obj Box {
    has c: Cell = Cell();
}

def escape_store {
    kept = Cell();
    r: own Region = Region();
    in r {
        kept = Cell(v=1);
    }
    print(kept.v);
}

def escape_return -> Cell {
    r: own Region = Region();
    in r {
        x = Cell();
        return x;
    }
}

def escape_field(b: Box) {
    in Region() {
        b.c = Cell(v=1);
    }
}

def escape_item(xs: list[Cell], d: dict[str, Cell]) {
    in Region() {
        xs[0] = Cell(v=2);
        d["a"] = Cell(v=3);
        xs.append(Cell(v=4));
        d.update({"b": Cell(v=5)});
        xs += [Cell(v=6)];
    }
}

def parts(n: int) {
    r: own Region = Region();
    (a, b) = r.partition(n);
}

def not_region {
    in 5 {
        print(1);
    }
}
```

| Code | Meaning |
|---|---|
| E1307 | A value made in a region is assigned to a name, a field, an item or a dict entry from outside the open, given to a list's, dict's or set's method that keeps it, or returned from the open. |
| E1314 | `partition(n)` with a count that is not a literal. |
| E1197 | `in` opens something that is not a `Region`. |

## On other hosts

The checks run for every host. A `cpython`, `node`, `browser` or `hermes`
space then erases regions: nothing is made in one, so `region_of` gives
`None`, and the host frees what an open made when its last reference goes,
in its own order, not as the open closes.

## Differences from Python and the reference design

Python has no regions: every value is freed by reference counting and its
cycle collector, which is what a `cpython` space does with a region's
values here.
