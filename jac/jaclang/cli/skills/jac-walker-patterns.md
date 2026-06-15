---
name: jac-walker-patterns
description: Writing walkers that traverse the graph - the core of Object-Spatial Programming (OSP) in Jac. Entry points, visit/report, spawn results, disengage/skip, exit abilities, get-or-create `visit ... else`, lookup-base walker inheritance, walker API responses. Load when creating, editing, or debugging walker traversal or OSP code. Pair with `jac-node-edge-patterns` (the graph shape the walker moves through).
---

A walker is a mobile procedure that enters nodes and runs type-matched entry points. Walker state lives on the walker via `has`; traversal is driven by `visit`; results come back via `report`. Entry points can live on **both** sides - the walker reacts to nodes it enters, and nodes can react to arriving walkers.

```jac
node Item {
    has name: str;

    can greet with Finder entry {
        # node side: self = this node, visitor = the arriving walker
        print(f"{self.name} greeted by {visitor.target}");
    }
}

walker Finder {
    has target: str;
    has matches: list[str] = [];
    has reports: list[list[str]] = [];   # typed report channel - the `= []` is required

    can on_root with Root entry {
        visit [-->];
    }

    can on_item with Item entry {
        # walker side: self = walker, here = current node
        if here.name == self.target {
            self.matches.append(here.name);   # accumulate - do NOT report per match
        }
        visit [-->];
    }

    can finish with Root exit {
        report self.matches;                  # ONE report, after traversal completes
    }
}

with entry {
    root ++> Item(name="foo");
    root ++> Item(name="bar");

    result = root spawn Finder(target="foo");
    print(result.reports[0] if result.reports else []);   # ['foo']
}
```

## Reports and spawn results

- **Type the report channel: `has reports: list[T] = [];`** - then `report X` (write side) and `result.reports[i]` (read side) both check against `T`. **Omitting the `= []` default makes `reports` a required spawn parameter** - every `root spawn W()` fails with E1050. A single `report some_list;` arrives as `list[list[T]]` (one outer slot per `report` call).
- **Accumulate, then report once from an exit ability** (as in the example). Per-match reporting scatters N tiny reports - a documented anti-pattern. Exit abilities are deferred and run LIFO (post-order: deepest node's exit fires first), so `with Root exit` runs after the whole traversal - and bottom-up aggregation falls out for free.
- **Report typed nodes/objs, not hand-built dicts.** `report here;` serializes with field metadata; API and client callers receive hydrated typed instances (`task.title`, not `task["title"]`).
- **`report` also prints each value to stdout** - the answer to "why is my output doubled?".
- **Nested spawns: the inner walker's own `.reports` stays empty** - its reported values flow into the *outer* response stream instead. Pass results back via `has` attributes on the inner walker and read them after `root spawn inner;`.
- Safe access when reports may be empty: `result.reports[0] if result.reports else None`.

## Traversal control

- `skip;` ends the *current ability only* (like an early return) - the walker continues with its queue. `disengage;` halts the whole walker immediately - queued visits are discarded. Use `disengage` for search-style early exits.
- `visit ... else { ... }` - the else body runs only when the visit enqueued **nothing**. Its main use is **get-or-create**: try to walk into a node, create it on miss, and visit the fresh one - found or created, the same downstream ability runs. `visit fresh` works directly on the connect-result list (`++>` returns a list):

```jac
node Day {
    has date: str;
}

walker log_visit {
    can run with Root entry {
        today = "2026-06-12";
        visit [here-->[?:Day, date == today]] else {
            fresh = here ++> Day(date=today);
            visit fresh;            # visit accepts the connect-result list
        }
    }

    can record with Day entry {
        print("on " + here.date);   # found OR just created - same code path
    }
}
```

Re-running is idempotent: the second run's `visit` finds the existing `Day`, so the `else` never fires (verified: two runs, one `Day` total).

- Default queueing appends, so traversal is breadth-first. `visit :0: [-->];` inserts at the queue front - depth-first.
- Typed context blocks dispatch on the runtime node type inside one ability: `->Dog{ print(here.name); }`. Union entries match several node types: `can checkup with Dog | Cat entry { ... }`.
- Walkers inherit: `walker Sub(Base)` reuses the base's `has` fields and abilities (`override can log with Root entry { ... }` replaces a base ability for the same node type). The high-leverage form is the **lookup-base pattern**: a base walker resolves the target node once (jid string -> `jobj` -> type guard -> `visit`), and each action walker subclasses it with a single entry ability - littleX shares 3 lookup bases across 10 action walkers this way:

```jac
node Tweet {
    has content: str;
    has likes: list[str] = [];
}

walker find_tweet {
    has target_id: str = "";

    can locate with Root entry {
        target = jobj(self.target_id);
        if isinstance(target, Tweet) {
            visit [target];
        }
    }
}

walker like_tweet(find_tweet) {       # inherits target_id + locate
    can like with Tweet entry {
        here.likes.append("alice");
        report here.likes;
        disengage;
    }
}
```

`delete_tweet`, `add_comment`, ... are each one more subclass with one ability - the jid resolution and `isinstance` guard live in one place.

## Pitfalls

- `Root` in type annotations, bare `root` as a value (canonical). `root()` still compiles for backward-compat but emits a deprecation warning - always write `root`, `root ++> node`, `[root -->]`.
- **`visit` is a statement, not a method.** `visit [-->]` queues the *nodes* reachable over outgoing edges (`[edge -->]` is the form that yields edge objects); `visit (node_expr)` queues one specific node. Variants: `[<--]` incoming, `[->:EdgeType:->]` typed - single arrows; `[-->:EdgeType:]` is a parse error. Do NOT write `self.visit(...)` - a walker has no `visit` attribute (fails E1030).
- Walkers don't `return` - they `report X;` (appears in `result.reports`) or `disengage;`.
- Every entry needs a `with ... entry` clause - bare `can foo { ... }` (no `with`) is invalid (E0034).
- **A walker's generic `with entry` is NOT a per-node catch-all.** It fires only at the spawn location, never on later visits (verified: spawn at root, visit children - only root runs it). For catch-all behavior, give your nodes a shared base archetype and write `with BaseNode entry`, or use a union entry. The *node* side is the opposite: `can x with entry` declared in a **node** fires for **every** walker that visits it.
- Entry points are **`can`**, NOT `def`. Plain helper methods can still be `def`, but bodies that fire on node arrival must be `can`.
- **Keyword pairs depend on which side you're writing.** Inside a *walker* entry (`can ... with NodeType entry` in a walker): `self` = the walker, `here` = the current node. Inside a *node* entry (`can ... with WalkerType entry` in a node): `self` = the node, `visitor` = the arriving walker. Mixing them is the #1 walker bug.
- **The literal keyword `node` is not a type.** `can foo with node entry { ... }` fails `jac check` with E2018 - name a declared node archetype (or `Root`, or a shared base archetype). A node with no matching entry is simply passed through.
- **The node you spawn on - and every node you then visit - runs its matching entry, *including the origin*.** `some_node spawn W()` fires `W`'s `with <Type> entry` on `some_node` itself before any `visit`. This causes a classic **off-by-one** when counting or collecting. Fix: spawn on `root` and `visit [-->]` to reach the children you actually mean, or guard the origin inside the entry.

Related guides: `jac-node-edge-patterns` (graph shape, filtering, deletion), `jac-testing` (per-test root isolation), `jac-debugging` (stale-cache and NodeAnchor triage), `jac-concurrency` (async walkers), `jac-sv-endpoints` (walkers as API endpoints).
