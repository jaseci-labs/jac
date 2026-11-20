---
description: The object-spatial model in one page: data as a graph of nodes joined by edges, and computation as walkers that move over it.
keywords: object-spatial, osp, object-spatial programming
---
# Object-spatial programming

Jac has a second way to structure a program beside objects and functions. Data
is a graph: **nodes** joined by **edges**. Computation is a **walker**, an
object that moves over the graph and runs code at each place it arrives. The
code that runs is an **ability**: a block triggered by a walker arriving at, or
leaving, a node or an edge of a given type.

None of this exists in Python, so nothing about it can be guessed. Each part
has a page of its own; this page shows how they fit.

| Thing | Declared with | What it is | Page |
|---|---|---|---|
| node | `node Name { ... }` | An object that can be joined to others by edges | [Nodes](nodes.md) |
| edge | `edge Name: A --> B { ... }` | A directed link from one node to another, with fields of its own | [Edges](edges.md) |
| walker | `walker Name { ... }` | An object that visits nodes, with its state in its fields | [Walkers](walkers.md) |
| ability | `can name with T entry { ... }` | Code that runs when a walker enters or leaves a `T` | [Abilities](abilities.md) |
| `root` | (built in) | The node every program starts with | [root](root.md) |

## A worked example

```jac
node Project {
    has name: str;
}

node Task {
    has title: str,
        done: bool = False;
}

edge Contains: Project --> Task {}

edge Blocks: Task --> Task {}

walker OpenTasks {
    has found: list[str] = [];

    can start with Root entry {
        visit [-->];
    }

    can at_project with Project entry {
        print("project", here.name);
        visit [->:Contains:->];
    }

    can at_task with Task entry {
        if not here.done {
            self.found.append(here.title);
        }
    }
}

with entry {
    site = root ++> Project(name="site");
    draft = site +>:Contains:+> Task(title="draft", done=True);
    review = site +>:Contains:+> Task(title="review");
    site +>:Contains:+> Task(title="publish");
    draft +>:Blocks:+> review;
    w = root spawn OpenTasks();
    print(w.found);
    print([t.title for t in [site ->:Contains:->][?done == True]]);
    print([t.title for t in [review <-:Blocks:<-]]);
}
```

```output
project site
['review', 'publish']
['draft']
['draft']
```

What each part does:

1. **Declarations.** `Project` and `Task` are node types. `Contains` is an edge
   type that leads from a `Project` to a `Task`; `Blocks` leads from a `Task`
   to a `Task`.
2. **Building the graph.** `root ++> Project(name="site")` makes a `Project`,
   joins `root` to it with an edge of the default type, and evaluates to the
   `Project` (a connect expression is its right operand). `site
   +>:Contains:+> Task(...)` joins with an edge of type `Contains`. See
   [Connecting nodes](connecting.md).
3. **Starting a walk.** `root spawn OpenTasks()` makes a walker and runs it,
   starting at `root`. The expression returns the walker once the walk is over.
   See [Walkers](walkers.md).
4. **Abilities fire by type.** The walker arrives at `root`, a `Root`, so
   `start` runs. Inside an ability `here` is the node the walker is at and
   `self` is the walker. See [Abilities](abilities.md).
5. **Moving.** `visit [-->]` queues the nodes `here` has edges to. A walker
   moves only where an ability sends it; when its queue is empty the walk
   ends. `visit [->:Contains:->]` queues only the nodes reached by `Contains`
   edges. See [visit](visit.md).
6. **Results.** The walker collects titles in its field `found`, which the
   caller reads from the walker `spawn` returned.
7. **Queries without a walker.** `[site ->:Contains:->]` is an edge reference:
   the list of nodes `site` reaches by `Contains` edges, here a `list[Task]`.
   `[?done == True]` filters a list by a field. `[review <-:Blocks:<-]` follows
   edges backward. See [Edge references](edge-references.md).

## The rules that matter most

- **A graph is ordinary objects.** A node is an object with fields and
  methods. What makes it a node is that edges can join it to other nodes.
- **Edges are directed and are objects too.** Every edge has a source and a
  destination, and may have fields. A node keeps its edges in the order they
  were made, and every query returns them in that order.
- **A walker goes only where `visit` sends it.** There is no automatic
  traversal. Each `visit` adds to the walker's queue, and the walker takes the
  next item from the front. Nothing stops it visiting a node twice; a walk over
  a graph with a cycle needs its own record of where it has been.
- **Abilities are chosen by type, on both sides.** At each node the walker's
  abilities for that node's type run, then the node's abilities for that
  walker's type. A subtype matches its base type's abilities.
- **Exit abilities run when the walk unwinds,** in the reverse of the order
  the nodes were entered, after the queue is empty. They do not run as the
  walker moves on to the next node.
- **`spawn` is a call.** It runs the whole walk before it returns, and it
  returns the walker.
- **`root` is new in every run of a native program.** A graph is kept between
  runs only in an app's served space. See [root](root.md).

## Where to go next

| To learn | Read | Or run |
|---|---|---|
| Declaring nodes | [Nodes](nodes.md) | `jac docs node` |
| Declaring edges and their endpoints | [Edges](edges.md) | `jac docs edge` |
| `++>` and the other connect operators, `del` | [Connecting nodes](connecting.md) | `jac docs connect` |
| `[-->]`, typed references, filters | [Edge references](edge-references.md) | `jac docs edge-references` |
| Walkers and `spawn` | [Walkers](walkers.md) | `jac docs spawn` |
| `visit` and the order of a walk | [visit](visit.md) | `jac docs visit` |
| Abilities, `here`, `visitor`, the order abilities run in | [Abilities](abilities.md) | `jac docs can` |
| `report`, `skip`, `disengage` | [Walker control](walker-control.md) | `jac docs report` |
| `root` and what persists | [root](root.md) | `jac docs root` |
| Idioms for searching and collecting | [Graph queries](graph-queries.md) | `jac docs graph-queries` |

## Differences from Python and from the reference design

In Python none of this exists: there is no `node`, `edge`, `walker`, `can`,
`visit`, `spawn` or edge operator. A node is not a dataclass with a list of
neighbours; its edges are kept by the runtime and reached only through edge
references.

jac's object-spatial language differs from the reference design's (jaseci's jaclang, checked
against the reference design 0.38.3) in these ways. Each is described on the page named.

| Subject | In the reference design | Here | Page |
|---|---|---|---|
| The type of `[a -->]` | Untyped: any field can be read from its items | `list[Node]`; a field needs a typed reference, a filter or a typed target | [Edge references](edge-references.md) |
| `a <++> b` | One edge, seen from both ends | Two edges, one each way | [Connecting nodes](connecting.md) |
| An ability with the same name in a subclass | Replaces the base's | Both run, the base's first | [Abilities](abilities.md) |
| `skip` | Ends the ability; the other abilities for that node still run | Ends the ability and every ability still to run for that node, the walker's and the node's | [Walker control](walker-control.md) |
| `report` | Prints the value and adds it to the reports; a second walk starts the list again | Adds to the reports only; a second walk adds to the same list | [Walker control](walker-control.md) |
| `root` between runs of `jac run` / a built program | The graph is kept | A new `root` each run | [root](root.md) |
| `[node a -->]` | The same as `[a -->]` | Refused (E5090); write `[a -->]` | [Edge references](edge-references.md) |
| Unary `spawn W()` | Compiles, and fails when it runs | Refused when compiled (E5090); write `root spawn W()` | [Walkers](walkers.md) |
