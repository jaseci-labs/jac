---
description: The root node: what `root` is, where it can be used, whether a graph persists between runs, and how roots work in a served app.
keywords: root, Root
---
# root

`root` is a keyword that names the root node: a node the runtime makes before
the program's first statement runs. It is where a program usually hangs its
graph and starts its walkers.

## What root is

- `root` is an expression of type `Root`. `Root` is a node type the runtime
  declares, with no fields. It is a subtype of `Node`, like every node type.
- `root` can be read anywhere: in module code, in a function, in a method and
  in an ability. It needs no import.
- `root` is a node like any other. It is connected with `++>`, read with
  `[root -->]`, and has a `jid`.
- A walker's ability for the root is written with the type name:
  `can start with Root entry`.
- Nothing hangs off `root` until the program connects something to it.

```jac
node Note {
    has text: str;
}

walker Titles {
    has found: list[str] = [];

    can start with Root entry {
        visit [-->];
    }

    can at_note with Note entry {
        self.found.append(here.text);
    }
}

def add(text: str) {
    root ++> Note(text=text);
}

with entry {
    print(type(root).__name__, isinstance(root, Node), len([root -->]));
    add("milk");
    add("eggs");
    print(len([root -->]), (root spawn Titles()).found);
}
```

```output
Root True 0
2 ['milk', 'eggs']
```

A graph does not have to hang off `root`. Any node can be the start of a graph
and of a walk: `a spawn W()` starts at `a`. `root` is the node that is always
there, reachable from every function without being passed.

## A native program: nothing persists

In a program built from a file (`jac build prog.jac -o prog`), `root` is a
new, empty `Root` every time the program starts. The graph lives in memory for
the run and is gone when the program ends. There is no file behind it, and
nothing to clear between runs.

This program prints the same line every time it runs:

```jac
node Visit {}

with entry {
    root ++> Visit();
    print("visits so far:", len([root -->]));
}
```

```output
visits so far: 1
```

To keep a graph between runs, serve the program as an app (below), or write
the data out yourself.

## root.shared

`root.shared` is a second `Root`, distinct from `root`. In a native program
that is all it is. In a served app it is the one root that every caller sees;
see the next section.

```jac
with entry {
    print(type(root.shared).__name__, root.shared is root, root.shared is root.shared);
}
```

```output
Root False True
```

## A served app: a root for each user, kept between runs

An app's served space (a `space` on the `native` or `cpython` host that an
`app` runs, see [Apps](../apps/index.md), `jac docs apps`) keeps its graph:

- **The graph is stored.** After each call the space answers, the nodes and
  edges reachable from its roots are written to the app's data directory
  (`graph.db`); `commit()`, from `stdjac`, writes them before a long
  call returns. When the app starts again they are loaded, each with the `jid`
  it had, and each node's edges in the order they were made.
- **Each signed-in user has a root.** During a call made by a signed-in user,
  `root` is that user's own root, made the first time they call. What one user
  hangs off `root` is not reachable from another user's `root`. Calls the
  space answers at once each read their own caller's.
- **`root.shared` is everyone's.** It is one root for the whole space, the
  same in every call, and no user's own.
- **A call with no user has no `root`.** In a call made anonymously, or run by
  a schedule, reading `root` raises `RuntimeError`. `root.shared` works there,
  and a walker the call spawns on `root` (`root spawn W()`, or a walker endpoint
  the client spawns) starts at the shared root.
- **`allroots()`**, from `stdjac`, returns every user's root as a
  `list[Root]`. It does not include the shared root.

A walker served as an endpoint is the usual way to work on the caller's graph:
its `with Root entry` ability starts at the caller's root, or at the shared
root for an anonymous caller.

<!-- example: not checked: a module of an app's served space, which needs the project's archwire.jac -->
```jac
node Note {
    has text: str;
}

walker:pub add_note {
    has text: str;

    can run with Root entry {
        here ++> Note(text=self.text);
        report [n.text for n in [here --> [?:Note]]];
    }
}

def:pub shared_notes -> list[str] {
    return [n.text for n in [root.shared --> [?:Note]]];
}
```

Spawned by an anonymous client twice, with the app stopped and started in
between, `add_note` reports `["first"]` and then `["first", "second"]`: the
note made before the restart is still under the shared root.

[An app's data](../apps/data.md) (`jac docs root.shared`) has the rest:
when the graph is written, the data directory, `jobj` and `remove`, starting
with no data, and what happens when stored nodes no longer fit the program's
types. Signing in is in [Serving a space](../apps/server.md).

## What is rejected

`root` is a node, not a type. An ability for the root names the type `Root`;
`with root entry` is E1116:

```jac
# expect: E1116
walker Start {
    can begin with root entry {
        print("at the root");
    }
}

with entry {
    root spawn Start();
}
```

`root` is a keyword, and cannot be assigned (E0013):

```jac
# expect: E0013
node Home {}

with entry {
    root = Home();
}
```

## Differences from Python and from the reference design

- Python has no root object.
- In the reference design, a program run with `jac run` keeps the graph under `root` between
  runs: a second run finds what the first run connected. Here a native
  program starts with an empty `root` every run, and only an app's served
  space keeps its graph.
