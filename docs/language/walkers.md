---
description: Walker archetypes: their fields as the walk's state, the spawn expression in both operand orders, what spawn returns, where a walker can start, spawning one again, and walker inheritance.
keywords: walker, spawn
grammar: spawn_expr
---
# Walkers

A walker is an object that moves over a graph. `walker` declares a walker type:
its fields are the state it carries, and its abilities are the code it runs at
the nodes and edges it arrives at. `spawn` starts a walker at a node and runs
its walk to the end.

A walker moves only where its abilities send it with [visit](visit.md). What
runs at each step is described in [Abilities](abilities.md), and stopping early
in [Walker control](walker-control.md).

## Syntax

A walker is an `archetype` whose keyword is `walker`
([Archetypes](archetypes.md)). Its body holds `has` fields, `def` methods and
`can` abilities.

```ebnf
spawn_expr ::= "spawn" unpack | unpack ("spawn" unpack)*
```

## Declaring and creating a walker

Calling the walker type makes a walker, with fields given by name or position
like any object's. A new walker does nothing until it is spawned. Two walkers
are equal only when they are the same walker, as with nodes.

A walker's fields are its state for the whole walk: counters, results,
parameters of the search. Every ability reads and writes them through `self`.
A node's ability reaches them through `visitor`.

## spawn

`n spawn w` starts walker `w` at node `n`. The two operands may be in either
order: `w spawn n` means the same.

1. The left operand is evaluated, then the right.
2. One must be a node and the other a walker. Which is which is decided by
   their types, not by their position.
3. The walk runs, completely, before `spawn` returns. It is an ordinary
   synchronous call: nothing else in the program runs in between.
4. The value of the expression is the walker: the same object that was
   spawned, with its walker type. Its fields hold whatever the walk left in
   them, and `w.reports` holds what it reported.

The walk itself goes like this (each step has its own page):

1. The walker's queue starts holding the one node it was spawned on.
2. The walker's abilities written `with entry` (no type) run, once.
3. The walker takes the next item off the front of its queue, arrives there,
   and runs the entry abilities that match. Abilities call `visit` to add to
   the queue. This repeats until the queue is empty.
4. Exit abilities run for the nodes visited, latest first.
5. The walker's abilities written `with exit` (no type) run, once.

```jac
node Folder {
    has name: str,
        size: int = 0;
}

walker Measure {
    has min_size: int = 0,
        total: int = 0,
        big: list[str] = [];

    can at_folder with Folder entry {
        self.total += here.size;
        if here.size >= self.min_size {
            self.big.append(here.name);
        }
        visit [-->];
    }

    def summary -> str {
        return f"{self.total} in all, big: {self.big}";
    }
}

with entry {
    home = Folder(name="home", size=1);
    docs = home ++> Folder(name="docs", size=40);
    home ++> Folder(name="tmp", size=5);
    docs ++> Folder(name="taxes", size=90);
    w = home spawn Measure(min_size=40);
    print(w.total, w.big);
    print((Measure() spawn docs).summary());
    m = Measure(min_size=90);
    print((home spawn m) is m, m.big);
}
```

```output
136 ['docs', 'taxes']
130 in all, big: ['docs', 'taxes']
True ['taxes']
```

`spawn` binds tighter than a connect operator and looser than a call or an
attribute. To read a field of the result, parenthesize the spawn:
`(root spawn W()).found`. Without the parentheses, `root spawn W().found`
spawns the value of `W().found`.

## Where a walker can start

| Start | Written | Notes |
|---|---|---|
| The root | `root spawn W()` | The walker's `with Root entry` ability runs first; see [root](root.md) |
| Any node | `n spawn W()` | The graph need not hang off `root` |
| Each node of a list | `for n in nodes { n spawn W(); }` | `spawn` takes one node; a list is E1115 |
| An edge | not allowed | E1115. A walker reaches an edge by `visit` ([visit](visit.md)) |

A walk has no boundary. A walker spawned in the middle of a graph can follow
edges in any direction its abilities ask for, including backward toward the
nodes that lead to its start.

## Spawning a walker again

A walker object can be spawned more than once. Each spawn is a new walk with a
new queue, starting where it is told. The walker's fields are not reset between
walks, and neither are its reports: a second walk adds to both.

```jac
node Bin {
    has items: int = 0;
}

walker Count {
    has total: int = 0;

    can at_bin with Bin entry {
        self.total += here.items;
        report here.items;
    }
}

with entry {
    w = Count();
    Bin(items=3) spawn w;
    Bin(items=4) spawn w;
    print(w.total, w.reports);
}
```

```output
7 [3, 4]
```

An ability may itself spawn another walker. That inner walk runs to its end,
as any spawn does, before the ability continues; the two walkers have separate
queues and separate state.

An exception raised in an ability ends the walk and propagates out of the
`spawn` expression like an exception from a call.

## Walker inheritance

A walker type may extend another walker type. It inherits the base's fields,
methods and abilities ([Inheritance](inheritance.md)).

- At each node, the abilities the walker inherits run before its own, in the
  order they are declared. An ability in the subtype does not replace a base's
  ability, even with the same name: both run.
- A node's ability written for a base walker type (`can x with Base entry`)
  also runs for walkers of its subtypes.

```jac
node Room {
    has name: str;

    can welcome with Guide entry {
        print("  the room greets a", type(visitor).__name__);
    }
}

walker Guide {
    has rooms: int = 0;

    can enter with Room entry {
        self.rooms += 1;
        visit [-->];
    }
}

walker Critic(Guide) {
    has notes: list[str] = [];

    can judge with Room entry {
        self.notes.append(here.name + " seen");
    }
}

with entry {
    hall = Room(name="hall");
    hall ++> Room(name="study");
    c = hall spawn Critic();
    print(c.rooms, c.notes);
}
```

```output
  the room greets a Critic
  the room greets a Critic
2 ['hall seen', 'study seen']
```

## Walkers in an app

In an app, a walker tagged `:pub` or `:protect` in a served space is an
endpoint: a client spawns it by name, sending its fields, and receives its
fields and reports back. See [Apps](../apps/index.md) (`jac docs apps`) and
[root](root.md) for the root such a walker starts at.

## What is rejected

One operand of `spawn` is a walker (E1114) and the other is a node (E1115):

```jac
# expect: E1114, E1115 x2
node Bin {}

obj Plain {}

walker Count {}

with entry {
    Bin() spawn Plain();
    [Bin(), Bin()] spawn Count();
    Plain() spawn Count();
}
```

A field of the result needs parentheses around the spawn. Here `Count().total`
is an `int`, which is not a walker:

```jac
# expect: E1114
node Bin {}

walker Count {
    has total: int = 0;
}

with entry {
    print(Bin() spawn Count().total);
}
```

The grammar's unary form, `spawn W()` with no node, is refused. Name the node:

```jac
# expect: E5090
walker Count {}

with entry {
    spawn Count();
}
```

An `async walker` and an `async can` ability are refused (E5090). A walk is
synchronous; see [Async](async.md) for what `async` does apply to.

```jac
# expect: E5090 x2
node Bin {}

async walker Slow {
    async can at_bin with Bin entry {
        print("here");
    }
}

with entry {
    Bin() spawn Slow();
}
```

## Differences from Python and from the reference design

- Python has no walkers. The closest pattern is a visitor object passed to a
  recursive function; a walker replaces the recursion with a queue it fills
  itself.
- In the reference design a walker's reports start empty on every spawn. Here a walker spawned
  again keeps the reports of its earlier walks and adds to them.
- In the reference design the unary `spawn W()` compiles and then fails when it runs. Here it
  is refused when compiled.
