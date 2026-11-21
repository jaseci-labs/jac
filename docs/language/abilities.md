---
description: Abilities (`can ... with T entry|exit`): what triggers them on a walker, a node and an edge, the exact order they run in at each step of a walk, and the special references `here`, `self`, `visitor` and `root`.
keywords: can, ability, abilities, here, visitor, with exit, trigger, entry, exit
grammar: event_sig, ability
---
# Abilities

An ability is a block of code that the runtime runs when a walker arrives at a
node or an edge (`entry`) or leaves it (`exit`). Abilities are declared with
`can` inside a walker, a node or an edge. They are never called: a walk
triggers them, by type.

This page defines which abilities run and in what order. For starting a walk
see [Walkers](walkers.md); for moving, [visit](visit.md).

## Syntax

```ebnf
ability ::= decorators "comptime"? "override"? "class"? "static"? "async"? ("def" | "can") access_tag (NAME | "init" | "postinit")? ("[" type_params "]")? (event_sig | func_signature) where_clause? (block | ("by" expression | "abst")? ";")

event_sig ::= "with" expression? ("entry" | "exit")
```

A `can` takes an `event_sig`: `can name with Trigger entry { ... }`. A `def`
takes a `func_signature` and is a method or a function
([Methods](methods.md), [Functions](functions.md)).

- The name is optional. It identifies the ability in messages and in an
  `impl`; it is never used to call it.
- The trigger, between `with` and `entry` or `exit`, is an archetype name, a
  union of them (`City | Town`), or absent.
- An ability has no parameters and no return type. `return;` ends it.
- A declaration ending in `;` has its body elsewhere:
  `impl Walker.name with T entry { ... }`.

## What the trigger means

The trigger is always the type of *the other party*.

| Declared in | Trigger names | The ability runs when |
|---|---|---|
| a walker | node or edge types | the walker is at a node or edge of that type |
| a node or an edge | walker types | a walker of that type is at this node or edge |

Abilities belong to walkers, nodes and edges. An `obj`, a `class`, a `struct`
or an `enum` has none: no walker is ever at one.

- A subtype matches. `with City entry` in a walker runs at a `Hub` when `Hub`
  extends `City`, and `with Guide entry` in a node runs for a walker whose type
  extends `Guide`.
- A union runs the ability once at anything matching any member, however many
  of its members the node is.
- The root is matched by its type: `with Root entry` ([root](root.md)).

An ability with **no trigger** means something different on each side:

| Declared in | `can x with entry` | `can x with exit` |
|---|---|---|
| a walker | runs once, when the walk starts, before the abilities of the first node | runs once, when the walk ends |
| a node or an edge | runs for every walker that enters it | runs for every walker that leaves it |

## here, self, visitor and root

These keywords are expressions. What each one is depends on where the ability
is declared.

| In | `self` | `here` | `visitor` |
|---|---|---|---|
| a walker's ability | the walker | the node or edge the walker is at | not available (E2111) |
| a node's or an edge's ability | the node or edge | the same node or edge (`here is self`) | the walker |
| a method (`def`) | the object | not available (E2111) | not available (E2111) |
| a function or module code | not available (E2111) | not available (E2111) | not available (E2111) |

Their types come from the trigger:

| Trigger | Type of `here` (in a walker) or `visitor` (in a node or edge) |
|---|---|
| one type, `with City entry` | `City` |
| a union, `with City \| Town entry` | `City \| Town`: a field every member has is read directly, any other after `isinstance` |
| none, `with entry` | `any`: test it with `isinstance` before reading its fields, which are looked up as the program runs, not checked ([The `any` type](types-any.md)) |

In a walker's `with entry` and `with exit` abilities, `here` is the node the
walker was spawned on.

`root` is the root node and is available everywhere ([root](root.md)). `super`
is described in [Inheritance](inheritance.md).

An edge reference with no source starts at `here`: `[-->]` is `[here -->]`
([Edge references](edge-references.md)).

## The order abilities run in

A walk has three stages.

**1. Start.** The walker's `with entry` abilities run, once.

**2. Each arrival.** The walker takes the next item from its queue and arrives
at it. In this order:

1. The walker's entry abilities that match the item.
2. The item's own entry abilities that match the walker.

Then the walker takes the next item. Abilities `visit` to add items; an
arrival with nothing left in the queue moves to stage 3.

**3. Unwinding.** When the queue is empty, exit abilities run for the items
the walker arrived at, the most recent first. For each item:

1. The item's own exit abilities that match the walker.
2. The walker's exit abilities that match the item.

If an exit ability at a node or an edge queues something with `visit`, the
walker goes back to stage 2 for it; the new arrivals unwind, and then the
items that were still waiting unwind. When nothing is left, the walker's
`with exit` abilities run, once, and `spawn` returns.

So entry is walker first, then node; exit is the mirror image, node first, then
walker. And exits happen at the end, in reverse order of arrival, not as the
walker moves from one node to the next. A node arrived at twice unwinds twice.

Within one of the numbered steps, several abilities can match. They run:

- an inherited ability before the type's own (the base type's first);
- within one type, in the order they are declared in the source, an
  ability with no trigger in its place among the typed ones.

The same order holds for exit abilities: they are not reversed within a step.
Only the order of the items unwinding is reversed.

This program prints every step:

```jac
node City {
    has name: str;

    can node_in with Tour entry {
        print("    City.node_in", self.name);
    }

    can any_walker with entry {
        print("    City.any_walker", self.name);
    }

    can node_out with Tour exit {
        print("    City.node_out", self.name);
    }
}

node Capital(City) {
    can capital_in with Tour entry {
        print("    Capital.capital_in", self.name);
    }
}

walker Tour {
    can begin with entry {
        print("Tour.begin");
    }

    can arrive with City entry {
        print("  Tour.arrive", here.name);
        visit [-->];
    }

    can arrive_capital with Capital entry {
        print("  Tour.arrive_capital", here.name);
    }

    can leave with City exit {
        print("  Tour.leave", here.name);
    }

    can leave_capital with Capital exit {
        print("  Tour.leave_capital", here.name);
    }

    can finish with exit {
        print("Tour.finish");
    }
}

walker GuidedTour(Tour) {
    can guide with City entry {
        print("  GuidedTour.guide", here.name);
    }
}

with entry {
    a = City(name="a");
    b = a ++> Capital(name="b");
    a ++> City(name="c");
    b ++> City(name="d");
    a spawn GuidedTour();
}
```

```output
Tour.begin
  Tour.arrive a
  GuidedTour.guide a
    City.node_in a
    City.any_walker a
  Tour.arrive b
  Tour.arrive_capital b
  GuidedTour.guide b
    City.node_in b
    City.any_walker b
    Capital.capital_in b
  Tour.arrive c
  GuidedTour.guide c
    City.node_in c
    City.any_walker c
  Tour.arrive d
  GuidedTour.guide d
    City.node_in d
    City.any_walker d
    City.node_out d
  Tour.leave d
    City.node_out c
  Tour.leave c
    City.node_out b
  Tour.leave b
  Tour.leave_capital b
    City.node_out a
  Tour.leave a
Tour.finish
```

Reading the output:

- At `b`, a `Capital`, three walker abilities match (`arrive` and
  `arrive_capital` from `Tour`, then `guide` from `GuidedTour`), then three
  node abilities: `City`'s two in the order they are declared (the untyped
  `any_walker` after `node_in`), then `Capital`'s.
- Leaving `b`, the node's exit runs, then the walker's two in declaration
  order: `leave`, then `leave_capital`.
- The walk is breadth-first (`a`, `b`, `c`, `d`), and the exits run only after
  `d`, in the order `d`, `c`, `b`, `a`.

## Abilities are not methods

- An ability cannot be called: `walker.arrive()` is E1030.
- An ability in a subtype does not override a base type's ability. Both run,
  the base's first, even when they have the same name.
- `return;` ends the ability it is in. The other abilities for the same
  arrival still run. To stop those too, use `skip`
  ([Walker control](walker-control.md)).
- Only a walker's, node's or edge's abilities are triggered by a walk.

## A body written separately

An ability may be declared in the archetype and given its body in an `impl`,
which repeats the trigger:

```jac
node Leaf {
    has n: int = 0;
}

walker Sum {
    has total: int = 0;

    can add with Leaf entry;
}

impl Sum.add with Leaf entry {
    self.total += here.n;
    visit [-->];
}

with entry {
    a = Leaf(n=1);
    a ++> Leaf(n=2) ++> Leaf(n=3);
    print((a spawn Sum()).total);
}
```

```output
6
```

## Narrowing here and visitor

```jac
node City {
    has name: str;
}

node Town {
    has name: str,
        mayor: str = "";

    can greet with entry {
        if isinstance(visitor, Census) {
            visitor.towns += 1;
        }
    }
}

walker Census {
    has towns: int = 0;

    can begin with entry {
        if isinstance(here, City) {
            print("starting at the city of", here.name);
        }
    }

    can at_place with City | Town entry {
        print("at", here.name);
        if isinstance(here, Town) {
            print("  mayor:", here.mayor);
        }
        visit [-->];
    }
}

with entry {
    c = City(name="Avon");
    c ++> Town(name="Bree", mayor="Butterbur");
    print((c spawn Census()).towns);
}
```

```output
starting at the city of Avon
at Avon
at Bree
  mayor: Butterbur
1
```

## What is rejected

`can` declares an ability, which needs `with`. A function is a `def` (E0034):

```jac
# expect: E0034
walker Sum {
    can add(n: int) {
        print(n);
    }
}

with entry {
    root spawn Sum();
}
```

A trigger is the name of an archetype, or a union of names. A type that does
not exist is E2018. A trigger names the other party, so one that could never
fire is an error: a walker's ability is triggered by node or edge types
(E1116, as is anything other than a name), a node's or an edge's by walker
types (E1117), and an ability in any other archetype, which no walker is ever
at, never runs (E1573):

```jac
# expect: E2018
walker Sum {
    can add with Leef entry {
        print("leaf");
    }
}

with entry {
    root spawn Sum();
}
```

```jac
# expect: E1116 x2, E1117, E1573
node Leaf {
    has n: int = 0;

    can meet with Leaf entry {
        print("a node's ability triggered by a node");
    }
}

walker Other {}

obj Plain {
    can note with Sum entry {
        print("an obj's ability");
    }
}

walker Sum {
    can pass with Other entry {
        print("a walker's ability triggered by a walker");
    }

    can add with Leaf.n entry {
        print("leaf");
    }
}

with entry {
    root spawn Sum();
}
```

`here` and `visitor` exist only where the table above says (E2111):

```jac
# expect: E2111 x2
node Leaf {}

walker Sum {
    can add with Leaf entry {
        print(visitor);
    }

    def helper {
        print(here);
    }
}

with entry {
    Leaf() spawn Sum();
}
```

An ability has no return type. `can add with Leaf entry -> int` is E0002.

## Differences from Python and from the reference design

- Python has no abilities. The nearest idea is a visitor's `visit_City`
  method, but that is found by name and called; an ability is found by the
  types of the walker and the node, and several can run for one arrival.
- In the reference design an ability in a subclass with the same name as a base's replaces it.
  Here both run, the base's first.
- In the reference design `skip` ends only the ability it is in, and the node's other abilities
  still run. Here `skip` ends the rest of the arrival
  ([Walker control](walker-control.md)).
