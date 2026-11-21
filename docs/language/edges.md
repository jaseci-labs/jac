---
description: Edge archetypes: declaring an edge type with its endpoints and fields, the default edge, reaching an edge's ends, and edge abilities.
keywords: edge, GenericEdge, endpoints, edge ability
---
# Edges

An edge is a directed link from one node (its source) to another (its
destination). Every edge is an object of an edge type. `edge` declares one,
with the node types it joins and any fields it carries. Edges made without
naming a type are of the built-in type `GenericEdge`.

Edges are made by the connect operators ([Connecting nodes](connecting.md)) and
read with edge references ([Edge references](edge-references.md)).

## Syntax

An edge is an `archetype` whose keyword is `edge`, with its endpoints after the
name:

```ebnf
archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")
```

In `edge Name: A --> B { ... }`:

- `A` is the type of node the edge leads from and `B` the type it leads to.
  Each is a node type or a union of node types (`City | Town`).
- The endpoints are required. An edge type without them is E2086. An edge
  type that extends another states its endpoints again:
  `edge Highway(Road): City --> City {}`.
- The body holds `has` fields, `def` methods and `can` abilities, as a node's
  does.

## What the endpoints do

The endpoints give a typed edge reference its type. With
`edge Wrote: Author --> Book {}`:

- `[a ->:Wrote:->]` is a `list[Book]`: the destinations.
- `[b <-:Wrote:<-]` is a `list[Author]`: the sources.

When an endpoint is a union, the reference in that direction is a `list[Node]`.

An edge connects only nodes of the types its endpoints name, the way it points:
`book +>:Wrote:+> ann` is E1136, for each side. A node whose class is known
only as the program runs (one typed as a base node type, or as a union) is
checked when it is connected, where the endpoint is one class, and one of
another class raises `TypeError: expected Author, found Shelf`.

```jac
node Author {
    has name: str;
}

node Book {
    has title: str;
}

edge Wrote: Author --> Book {
    has year: int = 0;

    def recent -> bool {
        return self.year >= 2000;
    }
}

with entry {
    ann = Author(name="Ann");
    ann +>:Wrote(year=1999):+> Book(title="First");
    ann +>:Wrote(year=2004):+> Book(title="Second");
    print([b.title for b in [ann ->:Wrote:->]]);
    edges = [edge ann ->:Wrote:->];
    print(edges[0], [e.year for e in edges], [e.recent() for e in edges]);
    second = [ann ->:Wrote:->][1];
    print([a.name for a in [second <-:Wrote:<-]]);
}
```

```output
['First', 'Second']
Wrote(year=1999) [1999, 2004] [False, True]
['Ann']
```

## Fields on edges

An edge's fields are set when it is made, in the connect operator:
`a +>:Wrote(year=2004):+> b` or `a +>:Wrote:year=2004:+> b`. They are read and
written through the edge object, which an edges-only reference
(`[edge a ->:Wrote:->]`) returns.

An edge is an object like any other: it prints as its type and fields, has
methods, has an id (`jid(e)`, see [Nodes](nodes.md)), and compares by identity.

## The default edge

`a ++> b` makes an edge of type `GenericEdge`. It is declared by the runtime as
`edge GenericEdge: Node --> Node {}`: it joins any two nodes and has no fields.

- `[a -->]` follows edges of every type, `GenericEdge` included.
- `[a ->:GenericEdge:->]` follows only default edges.
- An edge type you declare is not a subtype of `GenericEdge`.

## An edge's ends

An edge reference whose source is an edge gives the edge's own ends:

| Reference | Value |
|---|---|
| `[e -->]` | A list holding the destination |
| `[e <--]` | A list holding the source |
| `[e <-->]` | A list holding the destination, then the source |

Each end has the type of the corresponding endpoint, or `Node` when that
endpoint is a union. An edge has its ends while it is connected: one made and
not yet connected, or disconnected since, has none, and each of these lists is
empty.

```jac
node Stop {
    has name: str;
}

edge Line: Stop --> Stop {
    has minutes: int = 0;
}

with entry {
    a = Stop(name="Ash");
    a +>:Line(minutes=4):+> Stop(name="Birch");
    e = [edge a ->:Line:->][0];
    print([e <--][0].name, "to", [e -->][0].name, "in", e.minutes);
    e.minutes += 1;
    print([edge a ->:Line:->][0].minutes);
    spare = Line(minutes=9);
    print(len([spare -->]), len([spare <-->]));
}
```

```output
Ash to Birch in 4
5
0 0
```

## Edge abilities

A walker can visit an edge as well as a node (`visit [edge -->]`, see
[visit](visit.md)). When it does, abilities fire exactly as at a node:

- The walker's abilities whose trigger is the edge's type run: `can cross with
  Line entry`. In them `here` is the edge.
- The edge's own abilities whose trigger is the walker's type run: inside them
  `self` (and `here`) is the edge and `visitor` is the walker.

A walker that visits only nodes never triggers an edge's abilities. A walker at
an edge does not move on by itself: `visit [-->]` at an edge queues the edge's
destination.

```jac
node City {
    has name: str;
}

edge Road: City --> City {
    has km: int = 0;

    can toll with Trip entry {
        visitor.paid += self.km;
    }
}

walker Trip {
    has paid: int = 0;

    can at_city with City entry {
        print("at", here.name);
        visit [edge ->:Road:->];
    }

    can on_road with Road entry {
        print("  on a road of", here.km, "km");
        visit [-->];
    }
}

with entry {
    p = City(name="Pella");
    q = p +>:Road(km=5):+> City(name="Quincy");
    q +>:Road(km=7):+> City(name="Rolla");
    t = p spawn Trip();
    print("paid", t.paid);
}
```

```output
at Pella
  on a road of 5 km
at Quincy
  on a road of 7 km
at Rolla
paid 12
```

## What is rejected

An edge type names its endpoints:

```jac
# expect: E2086
node Stop {}

edge Link {}

with entry {
    Stop() +>:Link:+> Stop();
}
```

An endpoint is a node type or a union of node types:

```jac
# expect: E2102
node Stop {}

edge Link: list[Stop] --> Stop {}

with entry {
    print(Stop());
}
```

An endpoint names a type that exists:

```jac
# expect: E2018
node Stop {}

edge Link: Stop --> Station {}

with entry {
    print(Stop());
}
```

An edges-only reference starts at a node, not at an edge:

```jac
# expect: E1177
node Stop {}

edge Link: Stop --> Stop {}

with entry {
    a = Stop();
    a +>:Link:+> Stop();
    e = [edge a ->:Link:->][0];
    print([edge e -->]);
}
```

## Differences from Python and from the reference design

- Python has no edges. A link between two objects there is a field on one of
  them; here it is a third object that both nodes know about.
- In the reference design `a <++> b` and `a <+:E:+> b` make one edge. Here they make two
  edges, one in each direction ([Connecting nodes](connecting.md)).
