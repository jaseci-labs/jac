---
description: The visit statement: the walker's queue, the order nodes are visited in, inserting at a position, `visit ... else`, `visit ... by` (a chooser picks the way), visiting edges, visiting a node twice, cycles, and what ends a walk.
keywords: visit, walker queue, traversal order, breadth-first, depth-first, visit by
grammar: visit_stmt
---
# visit

`visit` tells a walker where to go next. It adds nodes (or edges) to the
walker's queue; the walker arrives at them later, one at a time, in queue
order. A walker never moves anywhere a `visit` did not send it.

`visit` is written inside an ability ([Abilities](abilities.md)). For how a walk
starts, see [Walkers](walkers.md).

## Syntax

```ebnf
visit_stmt ::= "visit" (":" expression ":")? expression (else_stmt | ";")
```

| Form | Meaning |
|---|---|
| `visit x;` | Queue `x` at the end |
| `visit :n: x;` | Queue `x` at position `n` of what is left to visit |
| `visit x else { ... }` | Queue `x`; run the block if nothing was queued |
| `visit x by c;` | Queue those of the nodes `x` that the chooser `c` picks, in the order it picks them ([below](#visit--by)) |

`by` there is the `by` operator of the target's expression
([By and sem](by-and-sem.md)), which a `visit` statement gives this meaning. A position and an
`else` go with it as with any `visit`: `visit :0: x by c else { ... }`.

## What visit does

1. The target expression is evaluated. It is a node, an edge, or a list of
   nodes or edges. Most often it is an edge reference such as `[-->]`
   ([Edge references](edge-references.md)).
2. Its items are added to the queue of the walker the ability is running for:
   `self` in a walker's ability, `visitor` in a node's or an edge's ability. A
   list's items are added in list order. A single node or edge is added as one
   item. An optional node that is `None` adds nothing.
3. The ability carries on with its next statement. `visit` does not move the
   walker and does not end the ability.

The walker moves when every ability for the place it is at has finished. It
then takes the item at the front of the queue and arrives there.

The queue starts holding the node the walker was spawned on, before the
walker's `with entry` abilities run. A `visit x;` there queues `x` after that
node, and `visit :0: x;` queues it before, so `x` is the first place the walker
arrives.

The target can be any node, not only a neighbour of `here`. `visit root;`, a
node kept in a field, or a node made on the spot are all valid; edges matter
only because edge references are the usual way to find nodes.

## The order of a walk

The queue is first in, first out. Because `visit x;` adds at the end, a walker
whose abilities all do `visit [-->];` goes breadth-first: it reaches everything
one hop from the start, then everything two hops away, and so on. Within one
`visit`, nodes are queued in the order the edge reference returns them, which
is the order the edges were connected.

`visit :0: x;` adds at the front instead. A walker whose abilities do
`visit :0: [-->];` goes depth-first: the first child of the current node is
visited next, before the siblings that were queued earlier.

```jac
node Dir {
    has name: str;
}

walker Wide {
    has order: list[str] = [];

    can at_dir with Dir entry {
        self.order.append(here.name);
        visit [-->];
    }
}

walker Deep {
    has order: list[str] = [];

    can at_dir with Dir entry {
        self.order.append(here.name);
        visit :0: [-->];
    }
}

with entry {
    a = Dir(name="a");
    b = a ++> Dir(name="b");
    c = a ++> Dir(name="c");
    b ++> Dir(name="b1");
    b ++> Dir(name="b2");
    c ++> Dir(name="c1");
    print((a spawn Wide()).order);
    print((a spawn Deep()).order);
}
```

```output
['a', 'b', 'c', 'b1', 'b2', 'c1']
['a', 'b', 'b1', 'b2', 'c', 'c1']
```

## Inserting at a position

In `visit :n: x;`, `n` is an `int`: the position, among the items still waiting
in the queue, where the first item of `x` goes. The other items of `x` follow
it in order.

| `n` | Where the items go |
|---|---|
| `0` | At the front: visited next |
| `1` | After the first waiting item |
| `-1` | At the end. `visit :-1: x;` is the same as `visit x;` |
| `-2` | Before the last waiting item |
| past the end | At the end |
| before the front (`-99`) | At the front |

A negative `n` counts from the end, with `-1` meaning after the last item.

```jac
node Step {
    has name: str;
}

walker Plan {
    has order: list[str] = [];

    can at_step with Step entry {
        self.order.append(here.name);
        if here.name == "start" {
            visit [-->];
            visit :0: Step(name="first");
            visit :1: Step(name="second");
            visit :-2: Step(name="before last");
            visit Step(name="last");
        }
    }
}

with entry {
    s = Step(name="start");
    s ++> Step(name="x");
    s ++> Step(name="y");
    print((s spawn Plan()).order);
}
```

```output
['start', 'first', 'second', 'x', 'before last', 'y', 'last']
```

## visit ... else

The `else` block runs when the `visit` queued nothing: its target was an empty
list or `None`. It is the way to act at a leaf.

```jac
node Dir {
    has name: str;
}

walker Leaves {
    has found: list[str] = [];

    can at_dir with Dir entry {
        visit [-->] else {
            self.found.append(here.name);
        }
    }
}

with entry {
    a = Dir(name="a");
    b = a ++> Dir(name="b");
    a ++> Dir(name="c");
    b ++> Dir(name="b1");
    print((a spawn Leaves()).found);
}
```

```output
['c', 'b1']
```

## Choosing what to visit

Any expression that gives nodes can be the target, so the choice of where to go
is ordinary code:

- `visit [->:Road:->];` follows only `Road` edges.
- `visit [-->][?:City];` goes only to `City` nodes.
- `visit [->:Road:km < 50:->];` follows only short roads.
- `visit [n for n in [-->] if jid(n) not in self.seen];` skips nodes already
  seen.
- `visit [<--];` goes backward.

## visit ... by

`visit <nodes> by <chooser>;` has a chooser pick where the walker goes: of the nodes, it queues
the ones the chooser picks, in the order it picks them. The chooser is a value of a class
conforming to `ByChooser`, an [interface](interfaces.md) imported from `stdjac`:

| Name | What it is |
|---|---|
| `ByChooser` | The interface: `def choose(choice: ByChoice) -> list[int] abst;` |
| `ByChoice` | What is to be chosen: `name: str`, `asker: dict[str, any]`, `at: dict[str, any]`, `options: list[dict[str, any]]` |

What the statement does:

1. The nodes are evaluated, once. They are a list of one node type: an edge reference
   (`[-->]`, a list of `Node`), a filtered one (`[-->][?:City]`), or any `list[N]`.
2. With no node in the list the chooser is not asked. Otherwise its `choose` is called with a
   `ByChoice` that describes the walker, the node it is at, and each node of the list as an
   **option** with a number, from 0 in list order.
3. `choose` returns the numbers of the options to take, in the order to take them. Those nodes
   are queued, in that order. A number that is no option's, and a number given again, is dropped.
4. The `else` block runs when nothing was queued: the list was empty, or the chooser took none.

This chooser asks no model: it takes the two options whose roads are shortest, and prints what
it was given.

```jac
import from stdjac { ByChoice, ByChooser }

node City {
    has name: str;
}

edge Road: City --> City {
    has km: int = 0;
}

sem City = "A city on the map.";
sem Road = "A road from one city to the next.";
sem Road.km = "Its length in kilometres.";

"""The length of the road that leads to an option."""
def km_of(option: dict[str, any]) -> int {
    return option["edges"][0]["fields"]["km"];
}

"""A chooser that asks no model: the two options whose roads are shortest."""
obj Nearest(ByChooser) {
    def choose(choice: ByChoice) -> list[int] {
        print(choice.name);
        print("asker:", choice.asker);
        print("at:", choice.at);
        for option in choice.options {
            print(option);
        }
        near = sorted(choice.options, key=km_of);
        return [o["option"] for o in near[:2]];
    }
}

walker Tour {
    has seen: list[str] = [];

    can arrive with City entry {
        self.seen.append(here.name);
        visit [->:Road:->] by Nearest() else {
            print("no road leaves", here.name);
        }
    }
}

sem Tour = "Sees the cities nearest to where it is.";
sem Tour.seen = "The cities seen so far.";

with entry {
    a = City(name="a");
    a +>:Road(km=30):+> City(name="b");
    a +>:Road(km=10):+> City(name="c");
    a +>:Road(km=20):+> City(name="d");
    print((a spawn Tour()).seen);
}
```

```output
Tour at City
asker: {'type': 'Tour', 'fields': {'seen': ['a']}, 'means': 'Sees the cities nearest to where it is.', 'field_docs': {'seen': 'The cities seen so far.'}}
at: {'type': 'City', 'fields': {'name': 'a'}, 'means': 'A city on the map.'}
{'option': 0, 'node': {'type': 'City', 'fields': {'name': 'b'}, 'means': 'A city on the map.'}, 'edges': [{'type': 'Road', 'fields': {'km': 30}, 'means': 'A road from one city to the next.', 'field_docs': {'km': 'Its length in kilometres.'}}]}
{'option': 1, 'node': {'type': 'City', 'fields': {'name': 'c'}, 'means': 'A city on the map.'}, 'edges': [{'type': 'Road', 'fields': {'km': 10}, 'means': 'A road from one city to the next.', 'field_docs': {'km': 'Its length in kilometres.'}}]}
{'option': 2, 'node': {'type': 'City', 'fields': {'name': 'd'}, 'means': 'A city on the map.'}, 'edges': [{'type': 'Road', 'fields': {'km': 20}, 'means': 'A road from one city to the next.', 'field_docs': {'km': 'Its length in kilometres.'}}]}
no road leaves c
no road leaves d
['a', 'c', 'd']
```

The chooser took options 1 and 2, so the walker went to `c`, then `d`, and never to `b`. At `c`
and at `d` there was nothing to choose from, so the chooser was not asked and the `else` ran.

What a `ByChoice` holds:

| Field | Holds |
|---|---|
| `name` | The walker's class and the class of the node it is at: `Tour at City` |
| `asker` | The walker, described |
| `at` | The node the walker is at, described |
| `options` | For each node of the list, `{"option": <its number>, "node": <the node, described>, "edges": [<each edge from where the walker is to it, described>]}` |

A walker, a node or an edge is **described** as a dict of JSON's values:

| Key | Holds |
|---|---|
| `type` | Its class's name |
| `fields` | Its fields that are sendable, each as JSON by its type ([what crosses](../apps/crossings.md#what-crosses-and-in-what-form)). A field of another type is left out |
| `means` | Its class's [`sem`](by-and-sem.md): `sem City = "A city on the map.";`. Absent when the class has none |
| `field_docs` | The `sem`s of its fields, by field. Absent when no field has one |

An option's `edges` are the edges that lead to it from the node the walker is at, of the edge
types whose declared endpoints can join the two (`edge Road: City --> City`). An edge of no such
type, the generic one a plain `++>` makes for one, is not shown: an option reached only by `++>`
has `"edges": []`.

### Choosing with a model

`llm(...)`, which is built in, is a chooser: it shows the model the choice and asks for the
options' numbers ([By and sem](by-and-sem.md#asking-a-model-llm)).

<!-- example: not checked: it asks a model, which needs a key and the network -->
```jac
node City {
    has name: str;
}

walker Tour {
    can arrive with City entry {
        visit [-->][?:City] by llm(select=(1, 3), intent="See the oldest towns first.") else {
            print("the tour ends at", here.name);
        }
    }
}
```

| Argument | Default | Meaning |
|---|---|---|
| `select` | 1 | How many options to choose: a number, or a `(least, most)` pair. Both are held to the number of options. The model is asked for at least `least`; no more than `most` are taken |
| `intent` | `""` | What the choice is for, said to the model with the choice |

The model is told what the walker, the node and the options are through their `sem`s, so the
`sem`s of the classes and their fields are what it chooses by. Its other arguments (`max_tokens`,
`timeout`, `system_prompt`, ...) apply as in a `by` function, and a choice the model cannot make
raises `ByError`.

`visit ... by` is refused in an ability with no node for the walker to be at (one triggered by an
edge, or a walker's own `with entry`), and in a browser, hermes or node space (both E5090).

## Visiting a node twice, and cycles

A walker does not remember where it has been. The queue may hold the same node
more than once, and each time the walker arrives its abilities run again. A
node reached by two paths is visited twice unless the walker prevents it, and
on a graph with a cycle, a walker that always does `visit [-->];` never stops.

Keep a record in the walker and check it. A node's `jid` ([Nodes](nodes.md)) is
a convenient key; a `set` of the nodes themselves also works.

```jac
node Page {
    has title: str;
}

walker Crawl {
    has seen: set[str] = set(),
        order: list[str] = [];

    can at_page with Page entry {
        if jid(here) in self.seen {
            return;
        }
        self.seen.add(jid(here));
        self.order.append(here.title);
        visit [-->];
    }
}

with entry {
    home = Page(title="home");
    docs = home ++> Page(title="docs");
    blog = home ++> Page(title="blog");
    docs ++> home;
    blog ++> docs;
    print((home spawn Crawl()).order);
}
```

```output
['home', 'docs', 'blog']
```

## Visiting edges

The target may hold edges: `visit [edge -->];` queues the outgoing edges of
`here`. The walker then arrives at each edge as it would at a node. `here` is
the edge, and the abilities for the edge's type run ([Edges](edges.md)).

A walker at an edge does not continue to the edge's destination by itself. An
ability for the edge sends it on, usually with `visit [-->];`, which at an edge
means the edge's destination. A walker with no ability for an edge's type does
nothing at that edge and goes no further along it.

Nodes and edges can share the queue; the walker takes them in queue order.

## What ends a walk

A walk ends when one of these happens:

- **The queue is empty** after the abilities for the current place finish.
  Exit abilities then run ([Abilities](abilities.md)). If an exit ability at a
  node or an edge calls `visit`, the walker arrives at what it queued, those
  new arrivals unwind, and then the exits that were still waiting run. The
  walker's own `with exit` abilities run last, when nothing more can be
  visited (a `visit` in one is E2196).
- **`disengage`** runs: the walk stops at once ([Walker control](walker-control.md)).
- **An exception** leaves an ability: it propagates out of `spawn`.

A node that is deleted, or disconnected, after it was queued stays in the
queue. The walker still arrives at it and its abilities still run
([Connecting nodes](connecting.md)).

## What is rejected

`visit` belongs in an ability. In a function, a method or module code it is
E2083. In a walker's own `with exit` ability the walk is over, and nothing
queued there would be visited: E2196.

```jac
# expect: E2083, E2196
node Dir {}

walker Wide {
    def go_on {
        visit [root -->];
    }

    can finish with exit {
        visit [-->];
    }
}

with entry {
    root spawn Wide();
}
```

The target is a node, an edge or a list of them (E1094), and the position is an
`int` (E1001):

```jac
# expect: E1094, E1001
node Dir {}

walker Wide {
    can at_dir with Dir entry {
        visit "next";
        visit :"front": [-->];
    }
}

with entry {
    Dir() spawn Wide();
}
```

In an ability with no trigger type, `here` is an `any`, so `visit here;` is
E1094 there; `visit [-->];` is accepted.

`visit ... by` chooses among the nodes of a list (E1574 for one node, or a list of edges), with a
chooser that conforms to `ByChooser` (E1053), in an ability triggered by a node (E5090):

```jac
# expect: E1574 x2, E1053, E5090
import from stdjac { ByChoice, ByChooser }

node Stop {}

edge Road: Stop --> Stop {}

obj First(ByChooser) {
    def choose(choice: ByChoice) -> list[int] {
        return [0];
    }
}

obj Guess {}

walker Tour {
    can at_stop with Stop entry {
        visit here by First();
        visit [edge -->] by First();
        visit [-->] by Guess();
    }

    can on_road with Road entry {
        visit [-->] by First();
    }
}
```

## Differences from Python and from the reference design

- Python has nothing like `visit`. It is not a call and not a jump: it queues
  work for later and the current code carries on.
- The reference design's `visit [-->] by llm();` hands the choice to byllm. Here the chooser is any
  class conforming to `ByChooser`, `llm` among them; the nodes are a list of one node type; and
  what is shown of each is its sendable fields and the `sem`s of its class and fields.
- A position of `-1` means the end of the queue, after the last item. Python's
  `list.insert(-1, x)` would put `x` before the last item.
