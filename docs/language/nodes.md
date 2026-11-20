---
description: Node archetypes: declaring them, their fields and methods, creating nodes, node abilities, inheritance among nodes, and a node's id.
keywords: node, Node, jid, node ability
---
# Nodes

A node is an object that edges can join to other nodes. `node` declares a node
type the way `obj` declares an object type: with fields, methods and bases. On
top of that a node can hold abilities, which run when a walker arrives at it or
leaves it.

Nodes are one of the archetype kinds; [Archetypes](archetypes.md) describes what
all kinds share (`jac docs archetype`). For the model nodes belong to, see
[Object-spatial programming](object-spatial.md).

## Syntax

A node is an `archetype` whose keyword is `node`:

```ebnf
archetype ::= decorators "async"? ("struct" | "class" | "walker" | "edge" | "obj" | "node") access_tag NAME ("[" type_params "]")? ("(" inherit_list ")")? (":" pipe "-->" pipe)? where_clause? ("{" archetype_member* "}" | ";")
```

The `: A --> B` part is for edges only. A node's body holds `has` fields
([Fields](fields.md)), `def` methods ([Methods](methods.md)) and `can`
abilities ([Abilities](abilities.md)).

## Creating a node

Calling the node type makes a node. Fields are given by name or in declaration
order, and a field with a default may be left out. A new node has no edges and
is not part of any graph until it is connected ([Connecting nodes](connecting.md)).

```jac
node City {
    has name: str,
        pop: int = 0;

    def describe -> str {
        return f"{self.name} ({self.pop})";
    }
}

with entry {
    a = City(name="Ames", pop=66000);
    b = City("Boone");
    print(a, b);
    print(a.describe());
    same = City(name="Ames", pop=66000);
    print(a == same, a == a, a is same);
    print(isinstance(a, Node), type(a).__name__);
    print(len([a -->]));
}
```

```output
City(name='Ames', pop=66000) City(name='Boone', pop=0)
Ames (66000)
False True False
True City
0
```

- A node prints as its type and fields.
- Two nodes are equal only when they are the same node. `==` on nodes compares
  identity, whatever their fields hold.
- Every node type is a subtype of the built-in `Node`. `Node` has no fields. It
  is the element type of an untyped edge reference (`[a -->]` is a
  `list[Node]`) and can be written in annotations.
- A node is a reference: assigning it, passing it or putting it in a list
  shares the one node.

## Node abilities

An ability in a node runs when a walker of the named type enters (`entry`) or
leaves (`exit`) that node.

```ebnf
event_sig ::= "with" expression? ("entry" | "exit")
```

Inside a node's ability:

| Name | Is |
|---|---|
| `self` | The node |
| `visitor` | The walker that is at the node, typed as the ability's trigger |
| `here` | The node too (`here is self`) |

The trigger after `with` is a walker type, a union of walker types
(`with A | B entry`), or nothing. With no trigger the ability runs for every
walker, and `visitor` is an `any`: test what it is with `isinstance` before reading
its fields, since a field of an `any` is looked up as the program runs, not checked
([The `any` type](types-any.md)).

```jac
node Shelf {
    has label: str,
        books: int = 0;

    can count with Inventory entry {
        visitor.total += self.books;
    }

    can note with entry {
        print("  a", type(visitor).__name__, "is at shelf", self.label);
    }

    can done with Inventory exit {
        print("  inventory leaves shelf", self.label);
    }
}

walker Inventory {
    has total: int = 0;

    can walk with Shelf entry {
        visit [-->];
    }
}

walker Stroll {
    can walk with Shelf entry {
        visit [-->];
    }
}

with entry {
    a = Shelf(label="A", books=12);
    a ++> Shelf(label="B", books=30);
    inv = a spawn Inventory();
    print(inv.total);
    a spawn Stroll();
}
```

```output
  a Inventory is at shelf A
  a Inventory is at shelf B
  inventory leaves shelf B
  inventory leaves shelf A
42
  a Stroll is at shelf A
  a Stroll is at shelf B
```

A node's ability can do what a walker's can: `visit` queues nodes for
`visitor`, `report` adds to its reports, and `skip` and `disengage` control its
walk ([Walker control](walker-control.md)). In a node's ability an edge
reference with no source, such as `[-->]`, starts from the node.

A node's entry abilities run after the walker's own entry abilities for that
node, and its exit abilities run before the walker's. [Abilities](abilities.md)
gives the full order.

An ability is not a method. It has no parameters, returns nothing and cannot be
called: `shelf.count()` is E1030. A node's methods are `def`s, and a method
reaches the node's neighbours with `[self -->]`, because `here` exists only in
abilities.

## Inheritance among nodes

A node type may extend another node type. It inherits the base's fields,
methods and abilities ([Inheritance](inheritance.md)).

- A walker's ability for a base type also runs on nodes of its subtypes.
- A node runs the abilities it inherits and its own, the base's first. An
  ability in a subtype does not replace a base's ability, even when it has the
  same name: both run.
- A node type extends only node types. Extending an `obj`, or an `obj`
  extending a node, is E2106.

```jac
node Place {
    has name: str;

    can greet with Tour entry {
        print("  Place.greet", self.name);
    }
}

node Museum(Place) {
    has rooms: int = 1;

    can greet with Tour entry {
        print("  Museum.greet", self.rooms, "rooms");
    }
}

walker Tour {
    can at_place with Place entry {
        print("at a place:", here.name);
        visit [-->];
    }

    can at_museum with Museum entry {
        print("at a museum:", here.name);
    }
}

with entry {
    park = Place(name="park");
    park ++> Museum(name="gallery", rooms=9);
    park spawn Tour();
}
```

```output
at a place: park
  Place.greet park
at a place: gallery
at a museum: gallery
  Place.greet gallery
  Museum.greet 9 rooms
```

## A node's id

`jid(x)` gives the id of a node or an edge: a `str` of 32 hexadecimal digits,
unique among everything the program has made and, in an app that keeps its
graph, the same after a restart. Only nodes and edges have one.

- **The first 16 digits are the process's generation**, shared by every node
  and edge one run of the program makes.
- **The last 16 are a count** that increases in the order nodes and edges
  are made, the two counted together.
- **An id is given once, when the node or edge is made.** A copy made by
  `copy.copy` or `copy.deepcopy` is a new node with an id of its own.

```jac
node Stop {}

with entry {
    a = Stop();
    b = Stop();
    print(len(jid(a)), jid(a) == jid(a), jid(a) == jid(b));
}
```

```output
32 True False
```

## How long a node lives

A node lives as long as something refers to it. An edge refers to both of its
ends, so a node stays alive while it is connected to a node that is alive, in
either direction, and a graph hanging off `root` lives for the whole run. See
[Memory](memory.md).

## What is rejected

A node and its base must be the same kind of archetype:

```jac
# expect: E2106
obj Record {
    has id: int = 0;
}

node Stored(Record) {}

with entry {
    print(Stored());
}
```

`jid` takes a node or an edge. An `obj` or a walker has no id, and is
refused where its type is known (E1053); held in an `any`, it raises
`TypeError: jid() takes a node or an edge, not 'Visit'` as the program runs:

```jac
# expect: E1053
walker Visit {}

with entry {
    print(jid(Visit()));
}
```

An ability cannot be called as a method:

```jac
# expect: E1030
node Lamp {
    can light with Toggle entry {
        print("on");
    }
}

walker Toggle {}

with entry {
    Lamp().light();
}
```

## Differences from Python and from the reference design

- In Python a class instance compares by `__eq__`, which a dataclass derives
  from its fields. Here a node compares by identity.
- In the reference design an ability in a subclass replaces a base's ability of the same name.
  Here both run, the base's first.
- In the reference design the items of `[a -->]` are untyped, and any field can be read from
  them. Here they are `Node`s; see [Edge references](edge-references.md) for
  how to get them as their own type.
