---
description: The connect operators (`++>`, `<++`, `<++>`, `+>:E:+>` and the rest), what a connect expression returns, disconnecting with `del`, and what deleting a node does to its edges.
keywords: ++>, <++, <++>, +>:, :+>, <+:, :<+, connect, disconnect, del -->
grammar: connect, connect_assigns, graph_expr
---
# Connecting nodes

A connect operator makes an edge between two nodes. A disconnect (`a del --> b`)
removes edges between two nodes, and `del` of a variable that holds a node or an
edge takes it out of the graph.

For edge types see [Edges](edges.md); for reading the edges back see
[Edge references](edge-references.md).

## Syntax

```ebnf
connect ::= atomic_pipe (("del" edge_op | "+>:" expression (":" connect_assigns)? ":+>" | "<+:" expression (":" connect_assigns)? (":+>" | ":<+") | "<++>" | "++>" | "<++") atomic_pipe)*

connect_assigns ::= (kw_arg ("," kw_arg)* ","?)?

edge_op ::= "->:" edge_filter ":->" | "<-:" edge_filter ":<-" | "<-->" | "-->" | "<--"
```

## The connect operators

In every form, `a` and `b` are expressions whose values are nodes.

| Form | Edges made | Edge type |
|---|---|---|
| `a ++> b` | one, from `a` to `b` | `GenericEdge` |
| `a <++ b` | one, from `b` to `a` | `GenericEdge` |
| `a <++> b` | two: `a` to `b`, and `b` to `a` | `GenericEdge` |
| `a +>:E:+> b` | one, from `a` to `b` | `E` |
| `a <+:E:<+ b` | one, from `b` to `a` | `E` |
| `a <+:E:+> b` | two: `a` to `b`, and `b` to `a` | `E` |

Between the colons of a typed form goes one of:

| Written | Meaning |
|---|---|
| `E` | A new edge of type `E`, its fields at their defaults |
| `E(w=1)` | A new edge constructed with those arguments |
| `E:w=1, tag="x"` | The same, with the fields after a second colon (`connect_assigns`) |
| `e` | A variable holding an edge made earlier and not yet connected: that edge becomes the connection |

## What a connect expression does

1. The left operand is evaluated, then the right operand.
2. The edge is constructed: its arguments are evaluated now. For the two-way
   forms a second edge is constructed the same way, so the arguments are
   evaluated twice and the two edges are separate objects.
3. Each edge is appended to its source's outgoing edges and to its
   destination's incoming edges. A node keeps both lists in the order the
   edges were made, which is the order edge references return.

**The value of a connect expression is its right operand,** with the right
operand's type, in every form (`a <++ b` is `b`, not `a`). That makes two
idioms work:

- `n = root ++> Task(title="x");` makes the node, connects it and keeps it.
- `a ++> b ++> c;` is a chain: the operators group to the left, so it is
  `(a ++> b) ++> c`, which connects `a` to `b` and then `b` to `c`.

Connecting never replaces anything. Connecting the same two nodes again makes
another edge beside the first.

An edge connects one pair of nodes. One given as a value (`c +>:spare:+> a`)
that is already connected is refused with `ValueError`; once it is
disconnected it may connect again.

```jac
node Stop {
    has name: str;
}

edge Line: Stop --> Stop {
    has minutes: int = 0,
        color: str = "";
}

def names(stops: list[Stop]) -> list[str] {
    return [s.name for s in stops];
}

with entry {
    a = Stop(name="a");
    b = a ++> Stop(name="b");
    c = Stop(name="c");
    b ++> c ++> Stop(name="d");
    print(b.name, names([a -->]), names([b -->]), names([c -->]));
    a <++ c;
    print(names([c -->]), names([a <--]));
    a <++> b;
    print(len([edge a --> b]), len([edge b --> a]));
    a +>:Line(minutes=4):+> c;
    a +>:Line:minutes=9, color="red":+> c;
    print([(e.minutes, e.color) for e in [edge a ->:Line:->]], names([a ->:Line:->]));
    spare = Line(minutes=1);
    c +>:spare:+> a;
    print([edge c ->:Line:->][0] is spare);
    try {
        b +>:spare:+> c;
    } except ValueError as e {
        print("ValueError:", e);
    }
}
```

```output
b ['b'] ['c'] ['d']
['d', 'a'] ['c']
2 1
[(4, ''), (9, 'red')] ['c']
True
ValueError: an edge connects one pair of nodes, and this one is already connected
```

The third line of output is `2 1` because `a <++> b` added a second edge from
`a` to `b` beside the one `a ++> Stop(name="b")` had made.

Connect operators bind tighter than arithmetic and comparison and looser than
`spawn`, a call or an attribute. `x = a ++> b is b;` assigns `True`.

## Connecting many nodes

Both operands are single nodes. To connect a node to each node of a list, loop:

```jac
node Item {
    has n: int;
}

with entry {
    hub = Item(n=0);
    for i in range(1, 4) {
        hub ++> Item(n=i);
    }
    print(len([hub -->]));
}
```

```output
3
```

## Disconnecting

`a del OP b` removes edges between `a` and `b`, where `OP` is an edge operator
as in an edge reference. It is a statement: it has no value.

| Form | Removes |
|---|---|
| `a del --> b` | every edge from `a` to `b`, of any type |
| `a del <-- b` | every edge from `b` to `a` |
| `a del <--> b` | every edge between them, both ways |
| `a del ->:E:-> b` | the edges of type `E` (or a subtype) from `a` to `b` |
| `a del <-:E:<- b` | the edges of type `E` from `b` to `a` |
| `a del ->:E:w > 5:-> b` | the `E` edges from `a` to `b` whose field `w` is over 5 |

Removing edges that are not there is not an error. The nodes stay as they are;
only the edges go.

```jac
node Stop {
    has name: str;
}

edge Line: Stop --> Stop {
    has minutes: int = 0;
}

with entry {
    a = Stop(name="a");
    b = Stop(name="b");
    a ++> b;
    a +>:Line(minutes=4):+> b;
    a +>:Line(minutes=9):+> b;
    b ++> a;
    print(len([edge a --> b]), len([edge b --> a]));
    a del ->:Line:minutes > 5:-> b;
    print([e.minutes for e in [edge a ->:Line:->]]);
    a del --> b;
    print(len([edge a --> b]), len([edge b --> a]));
    a del <--> b;
    a del <--> b;
    print(len([edge a <-->]));
}
```

```output
3 1
[4]
0 1
0
```

## Deleting a node or an edge

`del x;`, where `x` is a local variable or a parameter whose type is a node
type or an edge type (`Node`, `Stop`, `Line`, or one of them `| None`), takes
the object it holds out of the graph and unbinds the variable:

- **An edge** is removed from its source's outgoing edges and its
  destination's incoming edges.
- **A node** loses every edge it has, outgoing and incoming. No other node
  reaches it afterwards.

This happens for any local that holds the object, not only the variable it was
first assigned to: the object is what is deleted. Other references to it stay
valid. A deleted node is still an object with its fields, and it can be
connected again.

Only `del` of a name of such a type does this. The rest is Python's `del`, and
leaves the graph alone:

- `del xs[0]` and `del d[k]` remove an item from a list or a dict;
- `del obj.field` removes the field from the object, so reading it raises
  `AttributeError`;
- `del x` where `x` is typed `any` only unbinds `x`, even when it holds a node.

```jac
node Stop {
    has name: str;
}

def names(stops: list[Stop]) -> list[str] {
    return [s.name for s in stops];
}

with entry {
    a = Stop(name="a");
    b = Stop(name="b");
    c = Stop(name="c");
    a ++> b;
    a ++> c;
    b ++> c;
    kept = [b];
    alias = b;
    del alias;
    print(names([a -->]), names([c <--]), kept[0].name, len([b -->]));
    e = [edge a --> c][0];
    del e;
    print(names([a -->]));
    del kept[0];
    a ++> b;
    print(names([a -->]), len(kept));
}
```

```output
['c'] ['a'] b 0
[]
['b'] 0
```

Deleting a node does not take it out of a walker's queue. A walker that has
already queued the node still arrives at it and runs its abilities; from there
`[-->]` is empty. See [visit](visit.md).

In an app that keeps its graph, `remove(n)` from `stdjac` takes a node
out with its edges and also forgets its id ([root](root.md)).

## What is rejected

Both sides of a connect or a disconnect are nodes. A list is E1096 (left) or
E1097 (right), as is any other value:

```jac
# expect: E1096, E1097
node Item {}

with entry {
    a = Item();
    a ++> [Item(), Item()];
    [Item(), Item()] ++> a;
}
```

The type between the colons is an edge type, and it joins the node types its
endpoints name (E1136, for each side that is another):

```jac
# expect: E1098, E1136 x2
node Item {}

node Box {}

obj Label {}

edge Holds: Box --> Item {}

with entry {
    Item() +>:Label:+> Item();
    Item() +>:Holds:+> Box();
}
```

An edge given as a value connects one way and takes no fields; both of these
are E5090:

```jac
# expect: E5090 x2
node Item {}

edge Tie: Item --> Item {
    has w: int = 0;
}

with entry {
    a = Item();
    b = Item();
    e = Tie();
    a <+:e:+> b;
    a +>:e:w=2:+> b;
}
```

A disconnect has no value to assign:

```jac
# expect: W1051
node Item {}

with entry {
    a = Item();
    b = Item();
    gone = a del --> b;
}
```

`del` of something that is neither a local name, a field nor an item is E0083:

```jac
# expect: E0083
node Item {}

with entry {
    a = Item();
    del [edge a --> a];
}
```

## graph expressions

The grammar has a `graph { ... }` expression:

```ebnf
graph_expr ::= "graph" "{" (expression ";")* "}"
```

jac parses it and refuses it (E5090). Build a graph with connect
expressions in ordinary statements.

```jac
# expect: E5090
node Item {}

with entry {
    g = graph {
        Item() ++> Item();
    };
}
```

## Differences from Python and from the reference design

- In Python `del x` only unbinds the name. Here, when `x` is typed as a node
  or an edge, it also takes that object out of the graph. `del` of a list
  item, a dict entry or a field is the same as Python's.
- In the reference design whether `del` takes an object out of the graph depends on the value
  it reaches at run time, so `del d["k"]` of a dict entry holding a node
  deletes the node. Here it depends only on the form and the type: a dict
  entry is only removed from the dict.
- The reference design's typed connects `a +:E:+> b` and `a <+:E:+ b` are written
  `a +>:E:+> b` and `a <+:E:<+ b` here. Each old spelling is refused the
  same way: E0005, `unexpected ':'`.
- In the reference design `a <++> b` and `a <+:E:+> b` make one edge. Here each makes two
  edges, one in each direction, so `[edge a <-->]` then lists two edges
  between the pair and a field written on one is not seen on the other.
- In the reference design an operand may be a list of nodes. Here each operand is one node.
