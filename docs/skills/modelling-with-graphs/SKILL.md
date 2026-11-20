---
name: modelling-with-graphs
description: Use when designing or changing a Jac program whose data is things joined by relationships (people and teams, tasks and dependencies, pages and links, syntax trees): choosing between a graph and plain objects, declaring nodes and typed edges, building from root, and querying with walkers, abilities, visit, report and edge references.
---
# Modelling with graphs

## When to use this

Use it when the data is entities joined by relationships, or when the work is a traversal: follow links to unknown depth, stop at the first match, compute a tree bottom-up, behave differently per kind of thing. It assumes `writing-jac`. For a served app's graph that persists between requests, continue in `building-an-app`.

Choose the shape first:

| The data is | Model it as |
|---|---|
| Things joined by relationships, many to many, links that carry data | Nodes and typed edges |
| A tree or graph walked to unknown depth, with work that differs per kind | Node types per kind, and walkers with an ability per kind |
| A record, a flat list, a lookup table, a buffer of numbers | `obj`, `list`, `dict`: no graph |
| A tight numeric loop | Plain values; nodes add cost without clarity |

## Before you start

Nothing about nodes, edges and walkers can be inferred from Python, and the reference design's rules differ in places. Read the overview, then the idioms:

```sh
jac docs language/object-spatial
jac docs graph-queries
```

## Steps

1. **Declare a node type per kind of thing**, with `has` fields: `node Person { has name: str; }`. Kinds are types, not a `kind` field: a walker then picks its ability by type, with no `if kind == ...`. A shared base node (`node Expr {}`, `node Num(Expr) {...}`) lets one ability handle every kind.
2. **Declare an edge type per relationship**, with its endpoints and any fields: `edge Member: Team --> Person { has since: int = 2020; }`. An edge always names its endpoints.
3. **Build the graph from `root`.** `root` is the node every program starts with; hang top-level nodes off it so they can be found again. A connect expression evaluates to its right operand, so `x = a +>:E(f=1):+> B(...)` makes, connects and returns the new node. Make each edge inside its connect expression, and connect it from its declared source to its declared target.
4. **Query a fixed number of hops with an edge reference.** `[a ->:Member:->]` is the nodes `Member` edges lead to from `a`, typed by the edge's target; `[a <-:Member:<-]` goes backward; `[edge a ->:Member:->]` gives the edges with their fields; `[root --> [?:Team, name == called]]` filters by type and field.
5. **Walk to unknown depth with a walker.** Its fields are the walk's state and its result. Each `can name with T entry { ... }` runs when it arrives at a `T`; `here` is the node, `self` the walker. It goes only where `visit` sends it.
6. **Start it with `spawn`**: `w = start spawn Payroll();` runs the whole walk and returns the walker. Read the result from its fields, or from its `reports`.
7. **Check, format, build and run** as in `writing-jac`.

A complete program with each step:

```jac
node Team {
    has name: str;
}

node Person {
    has name: str,
        salary: int;
}

edge Leads: Person --> Team {}

edge Member: Team --> Person {
    has since: int = 2020;
}

"""The team named `called`, made under `root` the first time it is asked for."""
def team(called: str) -> Team {
    found = [root --> [?:Team, name == called]];
    if found {
        return found[0];
    }
    return root ++> Team(name=called);
}

walker Payroll {
    has reports: list[Person] = [],
        total: int = 0,
        seen: set[str] = set();

    can at_team with Team entry {
        if jid(here) in self.seen {
            return;
        }
        self.seen.add(jid(here));
        visit [->:Member:->];
    }

    can at_person with Person entry {
        self.total += here.salary;
        if here.salary > 100 {
            report here;
        }
        visit [->:Leads:->];
    }
}

with entry:__main__ {
    eng = team("eng");
    ann = Person(name="ann", salary=150);
    bob = Person(name="bob", salary=90);
    cat = Person(name="cat", salary=120);
    eng +>:Member(since=2019):+> ann;
    eng +>:Member:+> bob;
    ann +>:Leads:+> team("infra");
    team("infra") +>:Member:+> cat;
    cat +>:Leads:+> eng;
    w = eng spawn Payroll();
    print(w.total, [p.name for p in w.reports]);
    print([e.since for e in [edge eng ->:Member:->]]);
    print(len([root -->]), [t.name for t in [root --> [?:Team]]]);
}

test "payroll counts every member and reports the well paid" {
    t = Team(name="t");
    t +>:Member:+> Person(name="dee", salary=200);
    t +>:Member:+> Person(name="eve", salary=50);
    w = t spawn Payroll();
    assert w.total == 250;
    assert [p.name for p in w.reports] == ["dee"];
}
```

```output
360 ['ann', 'cat']
[2019, 2020]
2 ['eng', 'infra']
```

The program's main code is in `with entry:__main__`, which runs when the program is run but not under `jac test`: the test builds a graph of its own. `team` is find-or-create: the second `team("infra")` finds the node the first made. `has reports: list[Person]` types the walker's reports, so `w.reports` items have their fields. `cat` leads `eng`, a cycle; the `seen` set keyed by `jid` stops the walk going round it.

## The rules that matter in practice

- **A walker goes only where `visit` sends it**, and takes its queue first in, first out: breadth-first. `visit :0: [-->];` puts nodes at the front, for depth-first.
- **A walker does not remember where it has been.** On a graph with shared nodes or cycles, keep a `set` of `jid(here)` and return early when seen.
- **At each node the walker's abilities run, then the node's** (a node may have `can greet with Payroll entry`). A walker's abilities trigger on node and edge types; a node's on walker types. When several of a walker's abilities match one node (one `with Expr entry`, one `with Neg entry`), they run in the order they are declared, and one inherited from a base walker before the walker's own.
- **Exit abilities run after the queue is empty,** in reverse order of arrival: in a tree every child's exit runs before its parent's, which makes them the place for bottom-up work (`jac docs graph-queries`, "Compute bottom-up"). Put `visit` in entry abilities.
- **`report x;` adds to the walker's reports and carries on; `disengage;` ends the walk; `skip;` ends this node's abilities.** A second spawn of the same walker adds to the same reports.
- **A walker has one set of fields for the whole walk.** Keep per-node values in a `dict` keyed by `jid`.
- **`root` is new in every run of a native program.** Nothing persists between runs unless an app's served space keeps it.

## What a correct result looks like

`jac check` is quiet, and the program prints what the walk collected. Test a walker with a `test` block that builds a small graph, spawns it, and asserts on its fields, as the program above does, and keep the program's own main code in `with entry:__main__`, which a test run leaves out (`testing-and-formatting`). `jac test` passes.

## Mistakes to expect

```jac
# expect: W3040, E1030
node Team {
    has name: str;
}

node Person {
    has name: str;
}

edge Member: Team --> Person {}

def team(name: str) -> Team {
    found = [root --> [?:Team, name == name]];
    return found[0] if found else root ++> Team(name=name);
}

with entry {
    t = team("eng");
    t +>:Member:+> Person(name="ann");
    first = [t -->][0];
    print(first.name);
}
```

| Code | What it means | Fix |
|---|---|---|
| W3040 | `name == name` in a filter: the left is the item's field, the right the variable outside | Rename the variable: `def team(called: str)` |
| E1030 | `[t -->]` is a `list[Node]`, whose items have no fields | A typed reference `[t ->:Member:->]`, or a filter `[t -->][?:Person]` |
| E2086 | `edge Leads {}` names no endpoints | `edge Leads: Person --> Team {}` |
| E1116 | `with root entry`: a trigger is a type, not a value | `with Root entry` |
| E5090 | `spawn W()` with no start, or `can` outside an archetype | `root spawn W()`; abilities belong to a walker, node or edge |
| E1277 | A `report` in a node's ability that may run for a walker with typed reports | Report from that walker's own abilities |
| E2083 | `visit`, `report`, `skip` or `disengage` outside an ability | Move it into a walker's or node's ability |

## Where to look things up

| Question | Command |
|---|---|
| The model in one page | `jac docs language/object-spatial` |
| Nodes, edges, endpoints | `jac docs nodes`, `jac docs edges` |
| `++>`, `+>:E:+>`, `del` | `jac docs connect` |
| `[a -->]`, typed references, filters | `jac docs edge-references` |
| `spawn`, walker fields | `jac docs spawn` |
| The queue and its order | `jac docs visit` |
| Ability order, `here`, `visitor` | `jac docs abilities` |
| `report`, `skip`, `disengage` | `jac docs report` |
| Find-or-create, collect, prune, bottom-up | `jac docs graph-queries` |
| `root` and what persists | `jac docs root` |
