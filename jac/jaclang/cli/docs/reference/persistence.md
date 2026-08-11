# Persistence & Schema Migration

Jac apps persist their object-spatial graph automatically, under one rule: whatever is reachable from `root` persists. The rule is called *persistence by reachability*, and the `root` node is the distinguished node anchoring every topology (each served user is issued a root of their own). But the schema of your `node`/`obj`/`edge`/`walker` archetypes inevitably evolves: you add a field, rename one, change a type, rename a class. This page covers what happens when you do.

The short version: **edits never delete persisted data**. Schema changes are tolerated, type changes are coerced, and rows that genuinely can't be loaded land in a quarantine sidecar instead of being dropped. For changes that need intent -- a field rename, a custom value transform -- archetypes declare their history in a [`__jac_schema__` hook](#declared-drift-rules-__jac_schema__) and the runtime repairs old rows on load.

---

## What gets persisted, and where

Every Jac archetype instance has a backing **anchor** that the runtime tracks. When an anchor is reachable from `root` (directly or via edges) and marked `persistent`, the runtime writes it to the store when the unit of work commits (each served request commits at its end; a `jac run` commits at process exit).

```jac
node Person { has name: str; }

walker create {
    can s with Root entry {
        # Both nodes become persistent because they're attached to root.
        here ++> Person(name="alice");
        here ++> Person(name="bob");
    }
}
```

**The store is Postgres, always.** There is exactly one persistence stack:

- **Local development**: the runtime provisions an **embedded Postgres server** automatically, one database per project, under a shared data directory. No installation, no configuration, no daemon to manage -- `jac run` and `jac start` just work. `jac db status` shows the server state and row counts; `jac db stop` shuts it down.
- **External server**: set the `JAC_DB_URL` environment variable (or `[scale.database] url` in `jac.toml`) to a `postgresql://user:pass@host:port/db` URL and the runtime connects there instead. Kubernetes deploys provision a Postgres StatefulSet and inject `JAC_DB_URL` into every pod.

Anchors live in an `anchors` table with `jsonb` payloads; the same database also carries the `quarantine` sidecar, a `kv_state` utility table, and (under jac-scale) the `jac_docs` table for scheduler jobs and webhook API keys. `jac db inspect` summarizes anchors by kind and archetype; `jac db sql "..."` runs one SQL statement against the project store when you need to look closer.

!!! info "Why reachability? Persistence is a predicate, not an event"
    In the I/O conception, persistence is something a program *does* at a moment -- open a session, call save -- and forgetting to do it is a bug. Jac makes persistence a *predicate*: a datum is durable exactly while it stands in a reachable position, the same way a value is live under garbage collection exactly while it's reachable from the collector's roots. One rule serves both temporal directions -- reachability decides what survives the past (collection) and what survives into the future (persistence). The idea has a research lineage (it is the identification rule of *orthogonal persistence*, pioneered in PS-algol in the 1980s), with one deliberate restriction that makes it practical: Jac persists the **topology** (nodes and edges), not the whole language heap -- closures, walker-local state, and ordinary objects stay transient, because they are the moving parts, not the remembered world.

---

## Concurrent writes: check-then-create and convergence

A common walker pattern is *find-or-create*: look something up, create it only if it's missing.

```jac
walker ensure_profile {
    can go with Root entry {
        profiles = [-->[?:UserProfile]];
        if profiles {
            report profiles[0];
        } else {
            here ++> UserProfile(tier="free");   # only when missing
        }
    }
}
```

Under concurrency this is a race: two requests against the same `root` can both read an empty `[-->[?:UserProfile]]`, both take the create branch, and both attach a profile -- a duplicate that was meant to be unique. The runtime closes this race with **the database transaction itself**, so the pattern above is safe without app-level locks.

**How it works.** Each request runs its reads and writes inside one Postgres transaction at the `SERIALIZABLE` isolation level, and **the transaction is the single source of truth**: what commits is what happened. When two requests race on overlapping data, Postgres lets one commit and aborts the other with a serialization conflict before it can write a duplicate.

**Convergence (default).** A rejected request does not error. The server rolls back its uncommitted work, discards its in-memory view, and **replays the walker (or function) from the start**. The replay re-reads the graph -- now containing the winner's node -- takes the *find* branch, and returns normally. Two racing find-or-creates converge on one node; the client sees a normal `200`, not a duplicate and not an error.

**The losing unit of work is atomic.** Because everything a request staged rides in one transaction, a lost race rolls back completely -- no orphan child rows, no half-linked edges. This holds identically for a single local process and a multi-pod deployment sharing one database.

**Side effects and replay: `on_commit`.** Because a losing request replays from scratch, an *external* side effect in the body (charging a card, sending mail, registering a token) would otherwise run more than once. Defer such effects with the `on_commit(...)` ambient builtin (no import needed): it registers a callback that runs only after the unit of work commits successfully, and is discarded on abort/replay -- so it fires exactly once, for the attempt that wins.

```jac
walker me {
    can go with Root entry {
        if not [-->[?:UserProfile]] {
            new = here ++> UserProfile(tier="free");
            on_commit(lambda { grant_signup_bonus(new); });   # once, post-commit
        }
    }
}
```

**Configuration.** The policy is set in [`jac.toml`](config/index.md#serve) under `[serve]`:

| Key | Default | Meaning |
|-----|---------|---------|
| `on_conflict` | `"retry"` | `"retry"` converges via replay; `"fail"` returns a typed `409 write_conflict` immediately (for clients that handle conflicts themselves) |
| `conflict_max_attempts` | `5` | Max attempts under `"retry"` before giving up with a `409` |
| `conflict_backoff_ms` | `0` | Linear backoff (ms x attempt) between replay attempts |

---

## The schema fingerprint

Every archetype class carries a stable schema fingerprint at runtime:

```jac
node Person {
    has name: str;
    has age: int = 0;
}

with entry {
    print(Person.__jac_fingerprint__);  # e.g. "2231007f4104e5bd"
}
```

The fingerprint is a SHA-256 hash of `(module, class_name, sorted [(field_name, type_repr)])`, truncated to 16 hex chars. Two important properties:

1. **Same schema → same fingerprint.** Two runs of the same code produce identical fingerprints.
2. **Different schema → different fingerprint.** Add a field, remove a field, change a type -- the fingerprint changes.

```jac
node Person {
    has name: str;
    has age: int = 0;
    has email: str = "";  # ← added
}
# Person.__jac_fingerprint__ = "dd9dfc47a9284086"  (was 2231007f4104e5bd)
```

Every persisted row is **stamped with the fingerprint at save time**. On load, the runtime compares the stored fingerprint against the live class's current fingerprint:

- **Match** → fast path, deserialize normally.
- **Mismatch** → log a drift notice at INFO and proceed with best-effort load (next sections).

You don't write fingerprint code. The runtime does it. Fingerprints are how the persistence layer detects "the schema changed since this row was saved" without you telling it.

---

## Schema drift tolerance

For the common 80% of schema changes, the runtime handles drift transparently.

### Added field with a default

```jac
# v1                       # v2
node Person {              node Person {
    has name: str;             has name: str;
                               has email: str = "x@y";  # new
}                          }
```

On reload of v1-stored data with v2 code: `name` comes through unchanged, `email` takes its declared default. No warning, no quarantine.

### Removed field

Stored data has `age: 30`, the live class no longer declares `age`. The stale value doesn't leak onto the rehydrated archetype as an undeclared attribute -- instead it's **preserved in the attic**, a `__jac_attic__` sub-document that rides along with the row (see [The attic](#the-attic-nothing-is-destroyed)). Subsequent saves carry the attic forward, so the value remains recoverable. (Under `JAC_SCHEMA_REPAIR=off` or `detect`, the legacy behavior applies: the value is silently dropped.)

### Renamed field

Without a declaration, a rename looks like "remove old + add new with default" -- the old value lands in the attic and the new field takes its default. To make the old value flow into the new field, declare the rename with [`schema_alias`](#declared-drift-rules-__jac_schema__):

```jac
impl Person.__jac_schema__ -> None {
    schema_alias("name", stored="username");
}
```

### Type changed

Handled by the **coercion table**. `Serializer.coerce(value, target_type)` runs on every field during deserialization and converts the stored value to the live class's declared type:

| From | To | Notes |
|------|----|----|
| `str` | `int` / `float` / `bool` | bool parses `"true"`/`"1"`/`"yes"` and `"false"`/`"0"`/`"no"` |
| `int` / `float` / `bool` | `str` | `str(value)` |
| `int` ↔ `float` ↔ `bool` | each other | standard Python casts |
| `str` (ISO format) | `datetime` / `date` / `time` | `fromisoformat` |
| `str` | `UUID` | `UUID(value)` |
| value | `Enum` | by value, falls back to by-name lookup |
| `list` ↔ `tuple` | each other | shallow conversion |
| `None` | `T \| None` | passes through; non-`None` coerces against `T` |

If a field is declared as `A \| B \| C`, the coercer tries each variant in order and accepts the first that succeeds.

When coercion **fails** (e.g. `str("abc")` → `int`), the raw stored value is kept, a debug-level log is emitted, and the anchor still loads. Downstream code that uses the field will see the wrong type and may fail at use site -- but no data is lost. This bias toward "load with bad value" over "block load" is deliberate: the default is to keep the data alive.

---

## Quarantine, never delete

Some changes can't be auto-handled:

- The archetype class was renamed or moved (and no alias is registered).
- The stored payload is corrupt.
- A required field is missing and has no default.
- The Serializer raises during reconstruction.

In every such case, the row is recorded in the **`quarantine` sidecar table** in the project database, carrying the missing/broken anchor id, the citing row (if any), and the failure kind. **Nothing is ever silently deleted** -- that's the contract. Inspect it directly:

```bash
jac db sql "SELECT * FROM quarantine"
```

A recoverable quarantine (say, a class-missing row) heals on a later load once the cause is fixed -- deploy the code with the right [`@archetype_alias`](#class-renames-the-alias-decorator) or [`__jac_schema__`](#declared-drift-rules-__jac_schema__) declarations and touch the data again.

If you've used Jac before and remember "delete the data directory to run again after editing a node," that workflow is no longer required. Schema edits don't wipe data; they at worst quarantine rows until the fixed code loads them.

---

## Dangling references and read-path healing

Quarantine handles a row that *exists* but can't be loaded. A **dangling reference** is the opposite failure: a row that cites another row which is *gone*. A node's edge list names an edge that no longer exists; an edge names an endpoint node that no longer exists.

Because every unit of work commits in one transaction, a crash cannot create a dangling reference -- danglers come from history (data corrupted before the transactional model shipped) or an operator's manual surgery. They still need handling, because the citing row is live and a naive traversal that touched the missing referent would raise on every read.

**The read path heals them automatically.** When a traversal resolves a reference whose target is genuinely gone, it does not raise. Instead it:

1. files the missing referent into the `quarantine` table (with the citing row recorded),
2. prunes the stale citation from the citing row, staged as a normal write so the repair persists on the request's commit -- even a read-only request self-heals,
3. skips the dead reference and continues, so the rest of the traversal returns normally.

A *recoverable* quarantine is left untouched on the read path -- its citations stay intact so the connection can be restored once you fix the cause. Only a referent that is absent everywhere is treated as a genuine dangler and healed. Direct attribute access on a stale handle still raises: that is a programmer error, not a storage state, and only graph traversal heals.

---

## Class renames: the alias decorator

A renamed class is the most common reason rows quarantine: the stored row says `arch_module=__main__, arch_type=LegacyPerson`, but the live registry only has `__main__.Person`. Lookup fails, row quarantines.

The fix is the `@archetype_alias` decorator, an ambient Jac builtin (no import needed):

```jac
@archetype_alias("__main__.LegacyPerson")
node Person {
    has name: str;
}
```

At class-definition time the decorator records `"__main__.LegacyPerson" → "__main__.Person"` in the Serializer's alias map. On the next load, the lookup for `__main__.LegacyPerson` misses in the main registry, finds the alias, and returns the new class. Deserialization proceeds against `Person`. The old data flows in.

**Stack the decorator** when a class has been renamed multiple times in its history:

```jac
@archetype_alias("v1.Person")
@archetype_alias("v2.Human")
node User {
    has name: str;
}
```

**The argument is the fully-qualified old name as it appeared in stored data** -- i.e. `__module__ + "." + __name__` of the class at the time it was persisted. For files run via `jac run --entry ... app.jac`, the module is `__main__`.

Aliases are **code-resident**: they live in source, travel through git, and apply wherever the code runs (`schema_was` inside `__jac_schema__` is the same machinery in declaration form).

---

## Declared drift rules: `__jac_schema__`

The drift tolerance above is automatic but generic: it can default a new field or coerce a type, but it can't know that `username` *became* `name`, or that a comma-separated string should now split into a `list[str]`. For changes that need intent, an archetype declares its stored-shape history in a `__jac_schema__` hook.

The hook uses Jac's decl/impl separation, so the model declaration shows only the *present* shape and the history lives in the impl file:

```jac
# models.jac -- only the present
node User {
    has name: str = "";
    has tags: list[str] = [];

    static def __jac_schema__ -> None;
}
```

```jac
# impl/models.impl.jac -- the ledger of the past
def split_tags(doc: dict) -> dict {
    doc["tags"] = [t.strip() for t in doc["tags"].split(",") if t.strip()];
    return doc;
}

impl User.__jac_schema__ -> None {
    schema_was("myapp.models.OldUser");       # class rename
    schema_alias("name", stored="username");  # field rename
    schema_drop("legacy_bio");                # removed field: preserve its remains
    schema_upgrade(
        split_tags,
        when=(lambda (doc: dict) { isinstance(doc.get("tags"), str); })
    );
}
```

The four builders are ambient Jac builtins (no import needed) and are only callable inside an executing `__jac_schema__`:

| Builder | Declares | Effect on load |
|---------|----------|----------------|
| `schema_was(old_fqn)` | The class was previously `module.ClassName` | Stored rows under the old name resolve to this class (same machinery as `@archetype_alias`) |
| `schema_alias(new, stored=old)` | Field `new` was previously stored as `old` | Old key is renamed in place; the value flows into the new field (then coercion runs as usual). On save, the old name is also written as a shadow copy ([dual-write](#rolling-deploys-dual-write)) |
| `schema_drop(field)` | A deleted field may still exist in stored rows | Its stored value moves to the [attic](#the-attic-nothing-is-destroyed) instead of being dropped |
| `schema_upgrade(fn, when=pred)` | An arbitrary `dict -> dict` transform | `fn` runs on a copy of the raw stored dict when `pred(doc)` is true; it must return the full replacement dict and be idempotent |

Rules are **shape-matched, not version-matched**: there are no version integers to maintain. A rename applies to any stored row that still carries the old key and lacks the new one, which keeps repair robust when dev, staging, and production saw different intermediate schemas. Every rule application is idempotent, so re-repairing an already-repaired row is a no-op.

The engine runs in the core Serializer, **before** field deserialization -- so every deployment shape (embedded local server, external Postgres, multi-pod) repairs identically, and coercion/defaults still apply to the repaired values afterward.

### Validation at startup

Rules are validated against the live `has` declarations when the class registers (i.e. at import time). Contradictions fail the app at startup, never silently mid-traffic:

- `schema_alias("name", stored="username")` requires `name` to be a declared field and `username` to *not* be one (if the old field still exists, nothing was renamed).
- `schema_drop("x")` requires `x` to not be declared (the rule is about a deleted field's stored remains).
- Two aliases can't share a stored name, and two aliases can't target the same field.
- Calling a builder outside `__jac_schema__` raises immediately.

Field rules are **inherited by subclasses** (they inherited the fields, so they inherit the fields' history); `schema_was` applies only to the defining class.

### The attic: nothing is destroyed

Repaired-away values are never deleted. Removed fields (declared via `schema_drop` or simply unknown to the current class) move into a `__jac_attic__` sub-document stored alongside the row:

```json
{ "name": "ada", "tags": ["math"],
  "__jac_attic__": { "legacy_bio": { "value": "...", "reason": "dropped" } } }
```

The attic round-trips through loads and saves -- including under `JAC_SCHEMA_REPAIR=off`, so an emergency rollback can never destroy previously preserved data. It persists until you explicitly clean it up (a future census-gated *contract* phase will automate this).

### Rolling deploys: dual-write

During a rolling deploy, old-version pods read the same database as new-version pods. To keep them working, every aliased field is **dual-written**: saves emit both `name` and `username` with the same value (on full saves and partial field updates alike), so old readers keep finding the field they know.

On load, a row with *both* keys is recognized as dual-written, not drifted: an equal shadow is stripped silently (no write-back churn), and a differing shadow -- an old pod wrote `username` against an already-upgraded row -- resolves deterministically: the new name wins and the conflicting value is preserved in the attic as `shadow-conflict`. Shadows persist until a future contract phase strips them.

### The kill switch: `JAC_SCHEMA_REPAIR`

| Value | Behavior |
|-------|----------|
| `repair` (default) | Rules applied, attic written, dual-write active |
| `detect` | Drift is detected and logged (`steps not applied: [...]`) but nothing is mutated -- a production dry-run |
| `off` | Legacy load behavior (no renames, no upgrades, no new atticing). Previously written attics still round-trip so data is never lost |

### Worked example: a field rename end to end

```jac
# app.jac (v1)
node Person {
    has username: str = "",
        bio: str = "";
}

with entry { root ++> Person(username="ada", bio="first programmer"); }
```

After running v1, rename the field and delete `bio` in v2, declaring both:

```jac
# app.jac (v2)
node Person {
    has name: str = "";

    static def __jac_schema__ -> None;
}

impl Person.__jac_schema__ -> None {
    schema_alias("name", stored="username");
    schema_drop("bio");
}

with entry {
    for p in [root -->] {
        print(f"{p.name} / attic: {p?.__jac_attic__}");
    }
}
```

```text
INFO - Serializer: repaired __main__.Person: ['rename username -> name', 'attic bio']
ada / attic: {'bio': {'value': 'first programmer', 'reason': 'dropped'}}
```

The old value flowed into the renamed field, the deleted field's value is preserved, and no row went anywhere near quarantine.

---

## Worked example: a survivable schema change

Starting code:

```jac
# app.jac (v1)
node Person {
    has name: str;
    has age: int = 0;
}

walker create {
    can s with Root entry {
        here ++> Person(name="alice", age=30);
        here ++> Person(name="bob", age=25);
    }
}

walker dump {
    can r with Root entry { visit [-->]; }
    can p with Person entry { print(f"{here.name}:{here.age}"); }
}
```

```bash
jac run --entry create app.jac
# (alice and bob persist)
```

Now edit the schema -- add a field, change `age` from `int` to `str`, rename the class -- all at once:

```jac
# app.jac (v2)

@archetype_alias("__main__.Person")
node Human {
    has name: str;
    has age: str = "unknown";   # was int
    has email: str = "x@y";     # new field
}

walker dump {
    can r with Root entry { visit [-->]; }
    can p with Human entry {
        print(f"{here.name}:{here.age}:{here.email}");
    }
}
```

```bash
jac run --entry dump app.jac
# alice:30:x@y   ← age coerced int→str, email defaulted, class resolved via alias
# bob:25:x@y
```

Three forms of drift handled automatically: class rename via alias, type change via coercion, new field via default.

---

## Inspecting the store

The [`jac db`](cli/index.md#database-operations) command talks to the project's Postgres store, embedded or external:

```bash
# Server state and row counts (anchors, quarantine, kv_state).
jac db status

# Summarize anchors by kind and archetype.
jac db inspect

# Arbitrary SQL against the project database.
jac db sql "SELECT * FROM quarantine"
jac db sql "SELECT count(*) FROM anchors WHERE kind = 'node'"

# Run the embedded server in the foreground (pods/containers), stop it locally.
jac db serve
jac db stop
```

---

## Limitations

Currently out of scope (planned follow-on work):

- **Contract phase** -- attic data and dual-written shadow fields persist indefinitely; the census-gated cleanup that strips them once no old-version reader remains is future work. Until then they cost a little storage but are harmless.
- **Rename auto-inference** -- the runtime won't guess that a removed field and an added field of the same type are a rename; you declare it with `schema_alias`. (A schema registry that proposes such inferences is future work.)
- **Background sweep** -- repair is lazy (on read); cold rows that are never read stay at their old shape until touched. They repair correctly whenever that happens.
- **Compiler enforcement** -- there's no build-time lint yet that detects an undeclared breaking change against a schema lockfile.
- **Deep container coercion** -- `list[int] → list[str]` doesn't recurse into elements (a `schema_upgrade` callback covers this case today).

For arbitrary transforms the escape hatch is `schema_upgrade` -- a `dict -> dict` callback with full control over the raw stored document. If something still can't be expressed, the quarantine sidecar preserves the original payload for manual handling.
