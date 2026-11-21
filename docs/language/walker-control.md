---
description: The statements that control a walk from inside an ability: report (and a walker's reports), skip, and disengage, with what runs afterwards and what spawn returns.
keywords: report, reports, skip, disengage
grammar: report_stmt, ctrl_stmt
---
# Walker control

Three statements, valid only inside an ability, act on the walk in progress:

| Statement | What it does |
|---|---|
| `report x;` | Adds `x` to the walker's reports. The ability carries on |
| `skip;` | Ends the ability and the rest of the abilities for this arrival. The walk carries on |
| `disengage;` | Ends the ability and the whole walk |

They act on the walker the ability is running for: `self` in a walker's
ability, `visitor` in a node's or an edge's. See [Abilities](abilities.md) for
when abilities run.

## Syntax

```ebnf
report_stmt ::= "report" expression ";"

ctrl_stmt ::= ("break" | "continue" | "skip" | "disengage") ";"
```

`break` and `continue` are the loop statements; they have nothing to do with
walks.

## report

`report x;` evaluates `x` and appends it to the walker's list of reports. It
does not end the ability, does not print anything and does not affect where the
walker goes.

The list is read as `w.reports`:

- It is a `list[any]`, in the order the values were reported, whichever
  ability reported them (the walker's or a node's).
- It is empty before the walker's first walk.
- It belongs to the walker object. Spawning the same walker again adds to it.

```jac
node Shelf {
    has label: str,
        books: int = 0;

    can tell with Audit entry {
        report self.books;
    }
}

walker Audit {
    can at_shelf with Shelf entry {
        report here.label;
        visit [-->];
    }
}

with entry {
    a = Shelf(label="A", books=12);
    a ++> Shelf(label="B", books=30);
    w = a spawn Audit();
    print(w.reports);
    print(Audit().reports);
}
```

```output
['A', 12, 'B', 30]
[]
```

### Typed reports

A walker that declares a field `has reports: list[T] = [];` states the type of
what it reports. That field is then the walker's reports:

- Every `report` in the walker's abilities is checked as a `T` (E1001
  otherwise), and `w.reports` is a `list[T]`, so its items' fields can be read
  without narrowing.
- A node's ability written for that walker type (`with Route entry`) may
  report to it, checked the same way.
- An ability that cannot tell which walker it runs for may not `report` when
  one of the walkers it may run for declares its reports (E1277). That covers
  a node's ability with no trigger, and an ability of a base walker that a
  subtype with declared reports inherits.

```jac
obj Leg {
    has frm: str,
        to: str;
}

node Port {
    has name: str;
}

walker Route {
    has reports: list[Leg] = [];

    can sail with Port entry {
        for p in [here --> [?:Port]] {
            report Leg(frm=here.name, to=p.name);
        }
        visit [-->];
    }
}

with entry {
    x = Port(name="x");
    x ++> Port(name="y") ++> Port(name="z");
    r = x spawn Route();
    print([f"{leg.frm}>{leg.to}" for leg in r.reports], r.reports[0].to.upper());
}
```

```output
['x>y', 'y>z'] Y
```

A walker's ordinary fields are often the better place for a result: they have
whatever types you give them, and one walker can have several
([Walkers](walkers.md)).

## skip

`skip;` ends the ability, as `return;` does, and also cancels the abilities
that were still to run for the same step:

| `skip` in | Also cancelled |
|---|---|
| an entry ability at a node or edge | the remaining entry abilities for this arrival, the walker's and the node's |
| an exit ability at a node or edge | the remaining exit abilities for this item, the node's and the walker's |
| a walker's `with entry` ability | the walker's remaining `with entry` abilities; the first arrival still runs all of its abilities |
| a walker's `with exit` ability | the walker's remaining `with exit` abilities |

Everything else goes on as before:

- The queue is untouched. Whatever was queued before the `skip`, in this
  ability or earlier, is still visited.
- A node skipped during entry still gets its exit abilities when the walk
  unwinds.
- The next arrival starts fresh, with all of its abilities.

Compare `return;`, which ends only the ability it is in: the other abilities
for the arrival still run.

## disengage

`disengage;` ends the ability and stops the walk. After it, nothing more of the
walk runs:

- not the remaining abilities for this arrival;
- not the items still in the queue;
- not the exit abilities of any node, including the ones already visited and
  waiting to unwind;
- not the walker's `with exit` abilities.

`spawn` returns at once. The walker keeps its fields and its reports as they
were at that moment, so a search can set a result field and disengage.

Where it runs decides how much of the walk has already happened:

| `disengage` in | What has run | What is dropped |
|---|---|---|
| a walker's `with entry` ability | the `with entry` abilities before it, and it up to the `disengage` | every arrival, every exit, the `with exit` abilities |
| an entry ability at a node or edge (the walker's or the node's) | the arrivals so far | the rest of this arrival, the queue, every exit, the `with exit` abilities |
| an exit ability at a node or edge | the arrivals, and the exits so far | the remaining exits, the `with exit` abilities |
| a walker's `with exit` ability | the whole walk | the remaining `with exit` abilities |

A walker that disengaged can be spawned again; the new walk starts normally.

Both `skip` and `disengage` leave the ability the way `return` does: enclosing
`finally` blocks run.

## The three ways to leave an ability

```jac
node Stop {
    has name: str;

    can node_in with Ride entry {
        print("    node entry", self.name);
    }

    can node_out with Ride exit {
        print("    node exit", self.name);
    }
}

walker Ride {
    has at_b: str;

    can first with Stop entry {
        print("  first", here.name);
        visit [-->];
        if here.name == "b" {
            if self.at_b == "return" {
                return;
            }
            if self.at_b == "skip" {
                skip;
            }
            if self.at_b == "disengage" {
                disengage;
            }
        }
    }

    can second with Stop entry {
        print("  second", here.name);
    }

    can finish with exit {
        print("  finish");
    }
}

with entry {
    for how in ["return", "skip", "disengage"] {
        a = Stop(name="a");
        a ++> Stop(name="b") ++> Stop(name="c");
        print(how);
        w = a spawn Ride(at_b=how);
        print("  spawn returned a", type(w).__name__);
    }
}
```

```output
return
  first a
  second a
    node entry a
  first b
  second b
    node entry b
  first c
  second c
    node entry c
    node exit c
    node exit b
    node exit a
  finish
  spawn returned a Ride
skip
  first a
  second a
    node entry a
  first b
  first c
  second c
    node entry c
    node exit c
    node exit b
    node exit a
  finish
  spawn returned a Ride
disengage
  first a
  second a
    node entry a
  first b
  spawn returned a Ride
```

- With `return`, `second` and the node's entry ability still run at `b`.
- With `skip`, they do not; the walk goes on to `c`, and `b`'s exit ability
  runs with the others.
- With `disengage`, nothing follows: no `c`, no exits, no `finish`.

## What spawn returns

`spawn` always returns the walker, whatever ended the walk:

| The walk ended because | `spawn` returns | Fields and reports |
|---|---|---|
| the queue emptied | the walker | as the walk left them, exits included |
| `disengage` ran | the walker | as they were when it ran |
| an exception left an ability | nothing: the exception propagates | the walker object keeps what was set before it |

`skip` never ends a walk, so it does not change what `spawn` returns.

## Stopping a search early

```jac
node Room {
    has name: str,
        has_key: bool = False;
}

walker FindKey {
    has found: str = "",
        looked: int = 0;

    can look with Room entry {
        self.looked += 1;
        if here.has_key {
            self.found = here.name;
            disengage;
        }
        visit [-->];
    }
}

with entry {
    hall = Room(name="hall");
    hall ++> Room(name="study", has_key=True);
    hall ++> Room(name="attic") ++> Room(name="roof");
    w = hall spawn FindKey();
    print(w.found, w.looked);
}
```

```output
study 2
```

## What is rejected

`report`, `skip` and `disengage` (and `visit`) belong in an ability. Elsewhere,
including a walker's own methods, they are E2083:

```jac
# expect: E2083 x3
walker Ride {
    def helper {
        report 1;
    }
}

def stop {
    disengage;
}

with entry {
    skip;
}
```

With declared reports, a value of another type is E1001, and a `report` from an
ability that cannot tell which walker it adds to is E1277:

```jac
# expect: E1277 x2, E1001
obj Leg {
    has to: str;
}

node Port {
    has name: str;

    can note with entry {
        report self.name;
    }
}

walker Plain {
    can go with Port entry {
        report here.name;
    }
}

walker Route(Plain) {
    has reports: list[Leg] = [];

    can sail with Port entry {
        report Leg(to=here.name);
        report here.name;
    }
}

with entry {
    print((Port(name="x") spawn Route()).reports);
}
```

## Differences from Python and from the reference design

- `report` is not `return` and not `yield`: the ability keeps running, and the
  values are collected on the walker, not handed to a caller.
- In the reference design `report` also prints the value. Here it only adds it to the reports.
- In the reference design a walker's reports start empty on each spawn. Here a walker spawned
  again adds to the reports it already has.
- In the reference design `skip` ends the ability it is in and the node's other abilities still
  run. Here it also cancels the remaining abilities for that arrival.
