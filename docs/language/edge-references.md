---
description: Edge references (`[a -->]`, `[<--]`, `[a ->:E:->]`, chains and `[edge ...]`): what they evaluate to and in what order, their types, and filters `[?:T, field == v]` on references and on lists.
keywords: -->, <--, <-->, ->:, :->, <-:, :<-, edge reference, filter expression, [?
grammar: edge_ref_chain, edge_chain_tail, edge_op, edge_filter, filter_body
---
# Edge references

An edge reference is a bracketed expression that follows edges from a node and
returns what it finds as a new list: `[a -->]` is the list of nodes `a` has
edges to. A filter, `xs[?:T, field == v]`, keeps the items of a list that are
of a type and whose fields meet conditions.

They are how a program reads a graph. A walker uses them to say where to go
(`visit [-->]`, see [visit](visit.md)); any other code uses them as queries.

## Syntax

A `[` starts an edge reference when what follows is an edge operator, or a node
expression and then an edge operator:

```ebnf
bracket_expr ::= "[" (filter_body | edge_ref_chain | list_or_compr)

edge_ref_chain ::= "async"? ("edge" | "node")? atomic_chain? edge_chain_tail

edge_chain_tail ::= (edge_op ("[" filter_body | "(" expression ")" | atomic_chain)?)* "]"

edge_op ::= "->:" edge_filter ":->" | "<-:" edge_filter ":<-" | "<-->" | "-->" | "<--"

edge_filter ::= NAME? (":" (compare ("," compare)*)?)?

filter_body ::= "?" (":" expression ","?)? (compare ("," compare)*)? "]"
```

## One hop

A reference with one edge operator has three parts:
`[` *source* *operator* `]`.

**The source** is an expression whose value is a node. It may be left out
inside an ability, where it is `here` ([Abilities](abilities.md)): `[-->]` is
`[here -->]`.

**The operator** chooses the edges:

| Operator | Edges followed | Node taken from each edge |
|---|---|---|
| `-->` | the source's outgoing edges, of any type | its destination |
| `<--` | the source's incoming edges, of any type | its source |
| `<-->` | outgoing, then incoming | the other end |
| `->:E:->` | outgoing edges of type `E` or a subtype of `E` | its destination |
| `<-:E:<-` | incoming edges of type `E` or a subtype | its source |
| `->:E:w > 2:->` | outgoing `E` edges whose field `w` is over 2 | its destination |

**The value** is a new list, made each time the reference is evaluated.
Changing the list does not change the graph.

- **Order.** A node keeps its outgoing edges, and separately its incoming
  edges, in the order they were connected. The reference returns nodes in that
  order. `<-->` gives the nodes reached by outgoing edges first, then those
  reached by incoming edges.
- **Each node once.** With `-->`, `<--`, `<-->`, `->:E:->` and `<-:E:<-`, a
  node reached by several edges is listed once, at the position of the first.
  A reference with a condition on the edge's fields (`->:E:w > 2:->`) lists a
  node once for each edge that passes.
- **Nothing found** is an empty list, never an error.

```jac
node Stop {
    has name: str;
}

edge Line: Stop --> Stop {
    has minutes: int = 0;
}

def names(stops: list[Stop]) -> list[str] {
    return [s.name for s in stops];
}

with entry {
    a = Stop(name="a");
    b = Stop(name="b");
    c = Stop(name="c");
    d = Stop(name="d");
    a ++> c;
    a +>:Line(minutes=3):+> b;
    a +>:Line(minutes=8):+> d;
    a ++> b;
    d ++> a;
    print(names([a -->]), names([a <--]), names([a <-->]));
    print(names([a ->:Line:->]), names([b <-:Line:<-]), names([c <-:Line:<-]));
    print(names([a ->:Line:minutes > 5:->]), names([a ->:Line:minutes > 1, minutes < 5:->]));
    print(len([a -->]), len([edge a -->]));
}
```

```output
['c', 'b', 'd'] ['d'] ['c', 'b', 'd']
['b', 'd'] ['a'] []
['d'] ['b']
3 4
```

## Edges instead of nodes

`[edge ...]` returns the edges themselves instead of the nodes they lead to, in
the same order, one item for each edge followed: two edges to the same node are
two items. Use it to read or write an edge's fields, to count edges, or to give
a walker edges to visit.

- `[edge a ->:E:->]` is a `list[E]`.
- `[edge a -->]`, `[edge a <--]` and `[edge a <-->]` list edges of every type.
  To read fields, name the edge type.
- `[edge a <-->]` lists each edge once: an edge from `a` to itself is one edge,
  as `a` is one node in `[a <-->]`.

## The type of a reference

| Reference | Type |
|---|---|
| `[a -->]`, `[a <--]`, `[a <-->]` | `list[Node]` |
| `[a ->:E:->]` | a list of `E`'s destination type |
| `[a <-:E:<-]` | a list of `E`'s source type |
| either, when that endpoint of `E` is a union | `list[Node]` |
| `[edge a ->:E:->]`, `[edge a <-:E:<-]` | `list[E]` |
| `[...][?:T]` and `[a --> [?:T]]` | `list[T]` |

`Node` has no fields, so `[a -->][0].name` is E1030. There are three ways to
get nodes as their own type:

1. **Name the edge type.** `[a ->:Line:->]` is a `list[Stop]` because `Line`
   leads to `Stop`.
2. **Filter by node type.** `[a -->][?:Stop]` keeps the `Stop`s and is a
   `list[Stop]`.
3. **Say what list is wanted.** Where a `list[T]` of a node type is expected
   (an annotated variable, a parameter, a field, a `return`), an untyped
   reference is taken as one. Every node is checked as the reference is
   evaluated, and one that is not a `T` raises
   `TypeError: expected T, found U`.

```jac
node Stop {
    has name: str;
}

node Depot {
    has bays: int = 0;
}

def names(stops: list[Stop]) -> list[str] {
    return [s.name for s in stops];
}

with entry {
    a = Stop(name="a");
    a ++> Stop(name="b");
    a ++> Depot(bays=4);
    print(type([a -->][1]).__name__);
    print(names([a -->][?:Stop]), [d.bays for d in [a -->][?:Depot]]);
    try {
        print(names([a -->]));
    } except TypeError as e {
        print("TypeError:", e);
    }
}
```

```output
Depot
['b'] [4]
TypeError: expected Stop, found Depot
```

## Chains

A reference may hold several hops, and each hop may be followed by a
destination or a node filter:

| Reference | Value |
|---|---|
| `[a --> -->]` | the nodes two hops from `a` |
| `[a ->:E:-> ->:F:->]` | by an `E` edge, then by an `F` edge |
| `[a --> [?:T, x > 1]]` | the nodes one hop away that are `T`s with `x` over 1 |
| `[a --> [?:T] -->]` | the nodes reached from the `T`s one hop away |
| `[a --> b]` | `[b]` when `a` has an edge to `b`, else `[]` |
| `[a --> (expr)]` | the same, with the destination given by an expression |
| `[edge a --> b]` | the edges from `a` to `b` |
| `[edge a ->:E:-> b]` | the `E` edges from `a` to `b` |

The source and each destination are evaluated once, left to right, before any
edge is followed. A chain then runs like nested loops: for each node the first
hop gives, in order, the second hop is taken from it, and so on. The result is
what the last hop reaches.

A chain does not remove duplicates across paths: a node that two paths reach
appears twice. An edges-only chain gives the edges of its last hop.

The type of a chain is the type of its last hop.

```jac
node Person {
    has name: str,
        age: int = 0;
}

edge Knows: Person --> Person {
    has since: int = 0;
}

def names(people: list[Person]) -> list[str] {
    return [p.name for p in people];
}

with entry {
    ann = Person(name="ann", age=30);
    bob = Person(name="bob", age=20);
    cat = Person(name="cat", age=40);
    dan = Person(name="dan", age=50);
    ann +>:Knows(since=2001):+> bob;
    ann +>:Knows(since=2010):+> cat;
    bob +>:Knows(since=2015):+> dan;
    cat +>:Knows(since=2016):+> dan;
    print(names([ann ->:Knows:-> ->:Knows:->]));
    print(names([ann ->:Knows:-> [?age > 25]]), names([ann --> [?:Person, age > 25] -->]));
    print(names([ann --> cat]), names([ann --> dan]));
    print([e.since for e in [edge ann ->:Knows:-> cat]], [e.since for e in [edge dan <-:Knows:<-]]);
}
```

```output
['dan', 'dan']
['cat'] ['dan']
['cat'] []
[2010] [2015, 2016]
```

## From an edge

When the source is an edge, the reference gives the edge's own ends: `[e -->]`
is a list holding its destination, `[e <--]` its source, and `[e <-->]` both,
destination first. Inside an ability that runs at an edge, `[-->]` therefore
means "the node this edge leads to". See [Edges](edges.md).

## Filters

`xs[?...]` filters a list. It works on any list, not only on what an edge
reference returns.

| Filter | Keeps the items that |
|---|---|
| `xs[?:T]` | are instances of `T` (or a subtype) |
| `xs[?:T, f == v]` | are `T`s whose field `f` equals `v` |
| `xs[?:T, f > 1, g != ""]` | are `T`s meeting every condition |
| `xs[?f > 1]` | have a field `f` over 1 |

- The result is a new list with the kept items in their original order. With
  a type it is a `list[T]`; without one it has the type of `xs`.
- Each condition is a comparison whose left side is a field name of the item.
  The right side is an ordinary expression, evaluated in the scope around the
  filter. Any comparison operator may be used: `==`, `!=`, `<`, `>`, `<=`,
  `>=`, `in`, `not in`, `is`, `is not`.
- The type, when given, is followed by a comma before the conditions.
- Without a type, the field is looked up on each item as the program runs. An
  item that has no such field raises `AttributeError`. Give the type whenever
  the list can hold more than one kind of item.
- The same rules hold for the conditions in an edge operator
  (`->:E:w > 2:->`): the left side is a field of the edge. Without an edge type
  (`->::w > 2:->`) the field is looked up on every outgoing edge as the program
  runs, and an edge without it raises `AttributeError`.

A filter may be written after a reference (`[a -->][?:T]`) or inside it after a
hop (`[a --> [?:T]]`). The two mean the same.

```jac
node Task {
    has title: str,
        owner: str = "",
        hours: int = 0;
}

node Note {
    has text: str;
}

obj Bill {
    has amount: int = 0,
        paid: bool = False;
}

with entry {
    root ++> Task(title="draft", owner="ann", hours=3);
    root ++> Note(text="call bob");
    root ++> Task(title="review", owner="bob", hours=1);
    root ++> Task(title="ship", owner="ann", hours=8);
    who = "ann";
    print([t.title for t in [root -->][?:Task, owner == who]]);
    print([t.title for t in [root --> [?:Task, owner == who, hours > 5]]]);
    print([n.text for n in [root -->][?:Note]], len([root -->][?:Task]));
    bills = [Bill(amount=5), Bill(amount=20, paid=True), Bill(amount=30)];
    print([b.amount for b in bills[?paid == False]], [b.amount for b in bills[?amount in [5, 20]]]);
}
```

```output
['draft', 'ship']
['ship']
['call bob'] 3
[5, 30] [5, 20]
```

## What is rejected

An untyped reference gives `Node`s, which have no fields:

```jac
# expect: E1030
node Stop {
    has name: str;
}

with entry {
    a = Stop(name="a");
    a ++> Stop(name="b");
    print([a -->][0].name);
}
```

A reference with no source needs `here`, which exists only in an ability:

```jac
# expect: E2111
node Stop {}

def neighbours -> int {
    return len([-->]);
}

with entry {
    print(neighbours());
}
```

The source is a node (E1178), a typed operator names an edge type (E1098), and a
destination is a node (E1181):

```jac
# expect: E1178, E1098, E1181
node Stop {}

obj Label {}

with entry {
    a = Stop();
    print([Label() -->]);
    print([a ->:Label:->]);
    print([a --> Label()]);
}
```

A filter needs a list to filter, a comma after its type, and conditions that
compare a field (E5094, E0002):

```jac
# expect: E5094
node Stop {
    has n: int = 0;
}

with entry {
    print([?:Stop]);
}
```

```jac
# expect: E0002
node Stop {
    has n: int = 0;
}

with entry {
    print(len([Stop()][?:Stop n == 0]));
}
```

In a condition the name on the left is the item's field and a name on the right
is a variable. The same name on both sides is W3040; rename the variable:

```jac
# expect: W3040
node Task {
    has owner: str = "";
}

def mine(tasks: list[Task], owner: str) -> int {
    return len(tasks[?:Task, owner == owner]);
}

with entry {
    print(mine([Task(owner="a")], "a"));
}
```

The `node` and `async` prefixes of the grammar, and the older parenthesized
filter, are refused: `[node a -->]` and `[async a -->]` are E5090 (write
`[a -->]`), and `xs(?:T)` is E0048 (write `xs[?:T]`).

```jac
# expect: E5090
node Stop {}

with entry {
    print([node root -->]);
}
```

## Differences from Python and from the reference design

- In Python `[a]` is always a list display. Here `[a -->]` is an edge
  reference, recognized by the arrow after the first expression.
- In the reference design the items of `[a -->]` are untyped and any field may be read from
  them. Here the reference is a `list[Node]`, and reading a field needs one of
  the three typed forms above.
- In the reference design `[node a -->]` is another spelling of `[a -->]`. Here it is refused.
