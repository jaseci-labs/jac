---
description: What a serving app keeps - each caller's root and the shared root, the graph written after every call and at commit(), the data directory, data that no longer fits, and a fresh start.
keywords: JAC_<APP>_DATA, JAC_FRESH, data directory, graph.db, accounts.db, commit
---
# An app's data

A serving app keeps the graph its endpoints build. Nothing in the program saves or loads: nodes
connected to a root are there the next time the server starts. This page says whose root `root`
is, when the graph is written, where it is kept, and what happens when the program's types change
under kept data.

`root`, nodes, edges and walkers themselves are the language's: see `jac docs root` and
`jac docs walker`.

## Whose root

In a program that serves, `root` depends on who is calling.

| Form | Means |
|---|---|
| `root` | The signed-in caller's own root. Each account has one, made the first time it calls. |
| `root.shared` | The one root that belongs to no caller: public data, and what anonymous callers and scheduled functions work on |
| `allroots()` | Every caller's root (never the shared one), from `stdjac` |

Which of them a call has:

| The call is for | A walker spawned by the request starts at | `root` in its code |
|---|---|---|
| A signed-in caller, on a `:pub` or `:protect` endpoint | That caller's root | That caller's root |
| No one, on a `:pub` endpoint | `root.shared` | Raises `RuntimeError` |
| No one: a scheduled function | | Raises `RuntimeError` |

`root.shared` and `allroots()` work in all three.

A server answers its calls at once, each on a thread of its own
([Serving a space](server.md#calls-at-once)), and `root` is the call's own: two calls running
together each read their own caller's root, and so does a thread a call starts.

So a `:pub` walker that connects to `here` at `Root` gives every signed-in caller a private list
and all anonymous callers one common list:

```jac
import from stdjac { allroots }

node Note {
    has text: str;
}

walker:pub AddNote {
    has text: str;

    can add with Root entry {
        here ++> Note(text=self.text);
        report [n.text for n in [here --> [?:Note]]];
    }
}

def:pub mine -> int {
    return len([root --> [?:Note]]);
}

def:pub everyone -> int {
    return len(allroots());
}
```

Called without a session, `mine` fails (the server answers 500 and prints
`` `root` is no one's here: this runs for no caller, which has `root.shared` and `allroots()` ``).
A function meant for anonymous callers uses `root.shared`; one that needs the caller's root is
tagged `:protect`, which refuses anonymous callers before the function runs.

A program that does not serve (one with an `entry`, or any program built outside an app) has one
root, which `root` always is.

## What of the graph is in memory

An app starts with its roots, and the rest of its graph comes as its calls reach it:

- **A node comes with its fields.** Its edges come when they are first read or changed
  (`[n -->]`, `visit`, `del n --> m`), all of them at once, with the node at the other end of each.
- **What has come stays,** so a node is one object however it is reached, and a walk over it
  again asks the store nothing.
- **So an app holds what its calls have reached,** however much it keeps: it starts, and answers a
  call, in time and memory that do not grow with the graph.

Nothing in the program says any of this: `root`, `-->` and `visit` mean what they mean in a program
that keeps nothing.

## When the graph is written

The calls a server answers at once work on one graph in memory. It is written:

- **When an endpoint returns, a stream ends or is closed because its client has gone, or a
  scheduled function ends.** What is in memory is compared with what was read, and what changed is written: each node and edge whose fields
  changed, and each made since that a kept node leads to. The write is of everything in memory, so
  it takes with it what a call still running has changed so far.
- **Where the program calls `commit()`**, from `stdjac`: the same write, now. It is for a
  call that runs long, or a stream, whose work so far should be kept whatever happens next.
- **What is taken out of what is kept:** an edge the program deleted, and a node with no edge into
  it that is no root, with its edges out, and so on down from it. Nodes that lead to each other
  and are cut off together keep their rows: nothing reaches them, and nothing in memory tells them
  from nodes another walk still reaches. `sweep()` takes those out.
- An endpoint that raises, and a stream that raises, writes nothing of its own; what it changed
  in memory is written with the next write.

## Several instances on one store

Several programs may keep one graph: several instances of an app whose `store` plugin they can
all reach, as the standard one's file is for the programs of one machine.

- **A call starts on what the others have written.** As it starts, what other instances wrote
  since this one last looked is taken in: a node in memory is given its new fields, and gains and
  loses the edges it gained and lost.
- **A write that another's write got ahead of is not made.** Every kept node and edge has a
  version, and a write expects each one it changes to be as it was read. When one is not, nothing
  of the write is kept, what the call changed in memory is put back, and **the call runs again**,
  on what the other wrote. So an endpoint's body may run more than once: what it does outside the
  graph (a request it sends, a file it writes) is done each time.
- **After 4 tries the call fails:** its caller gets `409` with `"kind": "conflict"`. `commit()`
  called by the program raises `StoreConflict` (from `stdjac`) instead, since what a stream has
  sent cannot be run again.

```jac
import from stdjac { commit }

node Line {
    has text: str;
}

def:pub import_all(batches: list[list[str]]) -> Iterator[int] {
    kept = 0;
    for batch in batches {
        for text in batch {
            root.shared ++> Line(text=text);
        }
        commit();
        kept += len(batch);
        yield kept;
    }
}
```

Each batch is kept before its count is sent: a server stopped while the stream runs has every
batch whose count it sent. A write compares everything in memory with what was read, so its cost
grows with what the app has reached: commit at a milestone, not at each item of a stream. In a
program that keeps no graph, `commit()` does nothing.

Every node and edge has an id, `jid(x)`: 32 hex digits given when it is made, kept with it and given
back when it comes from the store. An id names the same node across restarts, so a client can hold one.
An id is never given again: once a node is removed, `jobj` of its id is `None`, and a node made
after it gets an id of its own.
These functions, from `stdjac`, work with ids:

| Function | Does |
|---|---|
| `jobj(id)` | The node or edge with that id, or `None` |
| `remove(n)` | Takes node `n` and its edges out of the graph |
| `allroots()` | Every caller's root |
| `commit()` | Writes what changed in the graph, now (above) |
| `sweep()` | Takes out of what is kept every node and edge no root leads to, and gives how many rows went. It reads the id of everything kept, so its cost grows with the store: it is for a quiet hour, from a scheduled function or by hand |

```jac
import from stdjac { jobj, remove }

node Note {
    has text: str;
}

def:pub note_ids -> list[str] {
    return [jid(n) for n in [root.shared --> [?:Note]]];
}

def:pub read(id: str) -> str | None {
    n = jobj(id);
    if not isinstance(n, Note) {
        return None;
    }
    return n.text;
}

def:pub drop(id: str) -> bool {
    n = jobj(id);
    if not isinstance(n, Note) {
        return False;
    }
    remove(n);
    return True;
}
```

`jobj` returns an `any`: the id a caller sends may name nothing (`None`), an edge, or a node of
another type. Test what it gives with `isinstance` before using it as a `Note`. Without the test,
given the id of a `Tag` node, `n.text` raises `AttributeError: 'Tag' object has no attribute 'text'`,
and `n: Note | None = jobj(id)` raises `TypeError: expected Note, found Tag`.

## Where it is kept

| File | Holds |
|---|---|
| `graph.db` | The graph: one row per node and per edge, in SQLite. It is what the standard `store` plugin keeps: a project that binds another keeps its graph where that plugin does ([Plugins](plugins.md)) |
| `accounts.db` | Accounts and sessions ([Serving a space](server.md)) |
| `jobs/` | The input and progress of running jobs |
| `arrangement` | The arrangement its user chose, for an app whose artifact holds several ([Building apps](building.md#several-arrangements-in-one-artifact)) |
| `local-user` | Who is using it now, for a desktop app with local users ([Hosts](hosts.md#local-users)) |

They are in the app's **data directory**:

- by default `.jac/data/<app>` in the project, as an absolute path fixed when the app is built;
- or wherever `JAC_<APP>_DATA` says, which is what a deployment sets.

```sh
JAC_API_DATA=/var/lib/api dist/api-linux-x86_64
```

A `cpython` space that a native app runs in its own process keeps a graph of its own, in
`<data directory>/<space>/graph.db`.

## Data that no longer fits

The kept graph is typed by the program that wrote it. When the program changes, the data may not
fit the new program. The server then says so, all of it at once, and stops with status 1:

```text
api can't start with the data it kept in .jac/data/api:
  accounts.db  is laid out as an older jac wrote it, which this one can't upgrade (layout 0; this one reads layout 1)
  graph.db     holds 2 svc.Gone whose type this program no longer has; and holds 1 svc.Note that no longer fit the type (missing field 'text')
To set that data aside and start empty, run `jac run api --fresh` in the project, or start the program with JAC_FRESH=1.
```

What makes data not fit:

| Change to the program | Kept data |
|---|---|
| A field added with a default | Fits: old nodes take the default |
| A field added without a default | Does not fit: `missing field '<name>'` |
| A field's type changed | Does not fit |
| A node or edge type renamed, moved to another module, or removed | Does not fit: the kept rows name a type the program no longer has |
| The files were written by a newer jac | Does not fit: `is laid out as a newer jac writes it` |

A type is kept under its module's name and its own (`svc.Note`), so moving a node type between
modules is a rename.

When a newer jac changes how the files themselves are laid out, it upgrades a file of an older
layout as it opens it: the file is first copied beside itself as it was (`graph.db.layout2`), then
upgraded in one transaction, and the server says what it did. A layout no upgrade leads from is
reported as above.

## A fresh start

`jac run <app> --fresh` starts the app with no data. What it kept is not deleted: the data
directory is moved to one beside it named for the moment.

```sh
jac run api --fresh
```

```text
api: its data is set aside in .jac/data/api.2026-11-12-152710, and it starts with none
listening on http://127.0.0.1:8000/
```

`--fresh` sets `JAC_FRESH=1` for the program it starts; setting the variable yourself does the same
for a program started directly.

Only data the project keeps for itself is set aside. An app told where its data is
(`JAC_<APP>_DATA`) refuses a fresh start and leaves the directory alone:

```text
api keeps its data where JAC_API_DATA says, in /var/lib/api: only a project's own data is set aside for a fresh start. Move that directory yourself.
```

## What goes wrong

| Symptom | Cause |
|---|---|
| A `:pub` endpoint answers 500, and the server prints `` `root` is no one's here `` | It reads `root` for an anonymous caller. Use `root.shared`, or tag it `:protect`. |
| `<app> can't start with the data it kept in ...` | A node type changed under kept data. Give the new field a default, or start fresh. |
| Data vanishes after a rebuild on another machine | The default data directory is an absolute path from the build. Set `JAC_<APP>_DATA`. |
| A node is gone after a restart | Nothing connected it to a root when its call returned |
| A long call's work is lost when the server stops | The graph is written when the call returns: call `commit()` where the work so far should be kept |
