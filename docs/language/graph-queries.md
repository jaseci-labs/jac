---
description: Idioms for finding, filtering and collecting over a graph: queries with edge references and filters, and walkers that collect, stop early, prune, and compute bottom-up.
keywords: graph-queries, graph query, find-or-create, post-order
---
# Graph queries

This page collects the patterns for getting answers out of a graph. They use
nothing beyond what the other object-spatial pages define; each pattern names
the page with the rule it relies on.

There are two tools:

| Use | When |
|---|---|
| An edge reference with a filter ([Edge references](edge-references.md)) | The answer is a fixed number of hops away and needs no state |
| A walker ([Walkers](walkers.md)) | The depth is unknown, the search can stop early, or the work differs by node type |

## Queries with references and filters

**Find by a field.** A reference with a node filter returns a list; test it
for emptiness, then take the item.

**Find or create.** Look under a known node, and connect a new one when
nothing is found. A connect expression is its right operand, so the new node
comes back from the same statement.

**Exists, count.** An empty list is false, and `len` counts.

**Reverse lookup.** `<--` and `<-:E:<-` follow edges backward, from a node to
whatever points at it.

**Edge data.** `[edge a ->:E:-> b]` returns the edges themselves, with their
fields.

```jac
node User {
    has name: str;
}

node Post {
    has text: str,
        likes: int = 0;
}

edge Wrote: User --> Post {
    has year: int = 0;
}

edge Follows: User --> User {}

def user(who: str) -> User {
    found = [root --> [?:User, name == who]];
    if found {
        return found[0];
    }
    return root ++> User(name=who);
}

def author(p: Post) -> User {
    return [p <-:Wrote:<-][0];
}

with entry {
    ann = user("ann");
    bob = user("bob");
    print(user("ann") is ann, len([root -->][?:User]));
    hello = ann +>:Wrote(year=2024):+> Post(text="hello", likes=3);
    ann +>:Wrote(year=2025):+> Post(text="again", likes=9);
    bob +>:Follows:+> ann;
    print(author(hello).name);
    print([p.text for p in [ann ->:Wrote:->][?likes > 5]]);
    print([p.text for p in [ann ->:Wrote:year > 2024:->]]);
    print([p.text for p in [bob ->:Follows:-> ->:Wrote:->]]);
    print([u.name for u in [ann <-:Follows:<-]], bool([bob <-:Follows:<-]));
    print([e.year for e in [edge ann ->:Wrote:-> hello]]);
}
```

```output
True 2
ann
['again']
['again']
['hello', 'again']
['bob'] False
[2024]
```

In a filter the name on the left of a condition is the item's field and a name
on the right is a variable. The parameter is `who`, not `name`, because a
condition with the same name on both sides (`name == name`) reads as comparing
the field with itself and is refused (W3040, see
[Edge references](edge-references.md)).

## Queries with walkers

The examples below work on one small tree of expressions. Its shape follows
how the jac compiler holds its own syntax trees: every kind of node extends
one base node type, children hang off a parent by one edge type, and each pass
over the tree is a walker with an ability per kind of node.

- **Model kinds as node types, not as a field.** A walker then dispatches on
  the type: an ability for the base type handles what all kinds share, and an
  ability for one kind handles what is special about it. No `if kind == ...`.
- **Put the descent in one ability on the base type.** `can descend with Expr
  entry { visit [->:Kid:->]; }` walks the whole tree; the other abilities only
  say what to do at each kind.
- **Results go in the walker's fields.** Wrap the spawn in a function that
  returns the field.

### Collect

A base-type ability walks; a kind-specific ability gathers.

### Stop early

`disengage` ends the walk the moment the answer is known
([Walker control](walker-control.md)). The result is already in a field.

### Prune

To leave a subtree out, do not `visit` below its root. An ability for the base
type that returns before its `visit` prunes everything under that node.

### Compute bottom-up

Exit abilities run in the reverse of the order the walker arrived
([Abilities](abilities.md)). In a tree a child always arrives after its parent,
so every child's exit ability runs before its parent's. That makes exit
abilities the place for work that needs the children's results first. Keep the
per-node results in a `dict` on the walker, keyed by `jid`.

```jac
node Expr {}

node Num(Expr) {
    has value: int;
}

node Add(Expr) {}

node Neg(Expr) {}

node Quote(Expr) {}

edge Kid: Expr --> Expr {}

walker Numbers {
    has found: list[int] = [];

    can descend with Expr entry {
        visit [->:Kid:->];
    }

    can num with Num entry {
        self.found.append(here.value);
    }
}

walker HasNeg {
    has found: bool = False,
        looked_at: int = 0;

    can descend with Expr entry {
        self.looked_at += 1;
        visit [->:Kid:->];
    }

    can neg with Neg entry {
        self.found = True;
        disengage;
    }
}

walker Unquoted {
    has found: list[int] = [];

    can descend with Expr entry {
        if isinstance(here, Quote) {
            return;
        }
        visit [->:Kid:->];
    }

    can num with Num entry {
        self.found.append(here.value);
    }
}

walker Eval {
    has values: dict[str, int] = {};

    can descend with Expr entry {
        visit [->:Kid:->];
    }

    can num with Num exit {
        self.values[jid(here)] = here.value;
    }

    can add with Add exit {
        self.values[jid(here)] = sum([self.values[jid(k)] for k in [->:Kid:->]]);
    }

    can neg with Neg exit {
        self.values[jid(here)] = -self.values[jid([->:Kid:->][0])];
    }

    can quote with Quote exit {
        self.values[jid(here)] = 0;
    }
}

def evaluate(e: Expr) -> int {
    return (e spawn Eval()).values[jid(e)];
}

with entry {
    # 1 + -(2 + 3) + quote(40)
    top = Add();
    top +>:Kid:+> Num(value=1);
    inner = top +>:Kid:+> Neg() +>:Kid:+> Add();
    inner +>:Kid:+> Num(value=2);
    inner +>:Kid:+> Num(value=3);
    top +>:Kid:+> Quote() +>:Kid:+> Num(value=40);
    print((top spawn Numbers()).found);
    w = top spawn HasNeg();
    print(w.found, w.looked_at);
    print((top spawn Unquoted()).found);
    print(evaluate(inner), evaluate(top));
}
```

```output
[1, 40, 2, 3]
True 3
[1, 2, 3]
5 -4
```

Notes on the example:

- `Numbers` reports the numbers in breadth-first order, the order of a walk
  whose `visit` adds at the end of the queue ([visit](visit.md)). Use
  `visit :0: [->:Kid:->];` for depth-first order.
- `HasNeg` stopped after looking at three nodes of eight. At the `Neg` its
  `descend` ran first (it is declared first), then `neg` disengaged.
- `Unquoted` prunes: its `descend` returns at a `Quote` before visiting, so the
  40 under it is never reached.
- `Eval` gives every kind an exit ability, and each reads its children's
  values, which are already in `values` because their exits ran first. A
  quoted expression counts as 0.
- A walker can be spawned on any subtree: `evaluate(inner)` walks only what
  hangs below `inner`.

### Graphs that are not trees

On a graph with shared nodes or cycles, a walker must record where it has been
or it will arrive at a node once per path, and never finish on a cycle. See
"Visiting a node twice, and cycles" in [visit](visit.md).

Bottom-up computation with exit abilities relies on children arriving after
parents. That holds for a tree. On a graph where a node can be reached before
one of its parents, order the work explicitly instead.

## Per-node state

A walker has one set of fields for the whole walk, not one per node. For a
value that differs per node, such as a depth or a distance, keep a `dict` keyed
by `jid` and fill in each child's entry as it is queued. This walker prints a
tree as an outline, depth-first:

```jac
node Dir {
    has name: str;
}

walker Outline {
    has depth: dict[str, int] = {};

    can at_dir with Dir entry {
        d = self.depth.get(jid(here), 0);
        print("  " * d + here.name);
        for kid in [-->] {
            self.depth[jid(kid)] = d + 1;
        }
        visit :0: [-->];
    }
}

with entry {
    a = Dir(name="a");
    b = a ++> Dir(name="b");
    a ++> Dir(name="c");
    b ++> Dir(name="d");
    a spawn Outline();
}
```

```output
a
  b
    d
  c
```
