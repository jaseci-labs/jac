# Persistence & Schema Migration

Jac apps persist their object-spatial graph automatically. Anything reachable from `root` survives across runs -- but the schema of your `node`/`obj`/`edge`/`walker` archetypes inevitably evolves: you add a field, rename one, change a type, rename a class. This page covers what happens when you do.

The short version: **edits never delete persisted data**. Schema changes are tolerated, type changes are coerced, and rows that genuinely can't be loaded land in a quarantine sidecar instead of being dropped. You inspect and rescue them with [`jac db`](cli/index.md#database-operations).

---

## What gets persisted

Every Jac archetype instance has a backing **anchor** that the runtime tracks. When an anchor is reachable from `root` (directly or via edges) and marked `persistent`, the runtime writes it to the configured storage backend on `commit()` (and at process exit).

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

After `jac enter app.jac create`, alice and bob live in `.jac/data/<app>.db`. A subsequent `jac enter app.jac dump` (with a walker that traverses `[-->]`) sees them.

**Backends.** Out of the box, `SqliteMemory` writes to `.jac/data/<app>.db`. Install [`jac-scale`](plugins/jac-scale.md) and configure `MONGODB_URI` and persistence flips to `MongoBackend`. The storage swaps; the developer-facing model (this page) doesn't change.

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

Every persisted row (or document) is **stamped with the fingerprint at save time**. On load, the runtime compares the stored fingerprint against the live class's current fingerprint:

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

Stored data has `age: 30`, the live class no longer declares `age`. The stale value is **silently dropped** instead of leaking onto the rehydrated archetype as an undeclared attribute. Subsequent saves write the row without the dead field.

### Renamed field

Treated as "remove old + add new with default." If you want the old value to flow into the new field, you'll need a Layer 4 escape hatch (not yet shipped -- see [Limitations](#limitations)).

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
| `None` | `Optional[T]` | passes through; non-`None` coerces against `T` |

If a field declared as `Union[A, B, C]`, the coercer tries each variant in order and accepts the first that succeeds.

When coercion **fails** (e.g. `str("abc")` → `int`), the raw stored value is kept, a debug-level log is emitted, and the anchor still loads. Downstream code that uses the field will see the wrong type and may fail at use site -- but no data is lost. (This bias toward "load with bad value" over "block load" is deliberate; you can always inspect the row with `jac db quarantine show` if you've forced it into quarantine via stricter validation, but the default is to keep the data alive.)

---

## Quarantine, never delete

Some changes can't be auto-handled:

- The archetype class was renamed or moved (and no alias is registered).
- The stored data is corrupt JSON.
- A required field is missing and has no default.
- The Serializer raises during reconstruction.

In every such case, the row is **moved to a quarantine sidecar**:

- SQLite: `anchors_quarantine` table.
- MongoDB: `<collection>_quarantine` collection.

The quarantine row carries the full original payload, the timestamp, the error message, and the source format version. **Nothing is ever silently deleted** -- that's the contract. Inspect with `jac db quarantine list` / `jac db quarantine show <id>`. Recover (after you fix the cause) with `jac db recover` / `jac db recover-all`.

If you've used Jac before and remember "delete `.jac/data/` to run again after editing a node," that workflow is no longer required. Schema edits don't wipe data; they at worst move data to quarantine where you can rescue it.

---

## Class renames: the alias decorator

A renamed class is the most common reason rows go to quarantine: the stored row says `arch_module=__main__, arch_type=LegacyPerson`, but the live registry only has `__main__.Person`. Lookup fails, row quarantines.

The fix is the `@archetype_alias` decorator, an ambient Jac builtin (no import needed):

```jac
@archetype_alias("__main__.LegacyPerson")
node Person {
    has name: str;
}
```

At class-definition time the decorator records `"__main__.LegacyPerson" → "__main__.Person"` in `Serializer._aliases`. On the next load, `_get_class("__main__", "LegacyPerson")` misses in the main registry, finds the alias, and returns the new class. Deserialization proceeds against `Person`. The old data flows in.

**Stack the decorator** when a class has been renamed multiple times in its history:

```jac
@archetype_alias("v1.Person")
@archetype_alias("v2.Human")
node User {
    has name: str;
}
```

**The argument is the fully-qualified old name as it appeared in stored data** -- i.e. `__module__ + "." + __name__` of the class at the time it was persisted. For files imported via `jac enter app.jac`, the module is `__main__`.

### Code-resident vs. DB-resident aliases

The decorator above is **code-resident**: lives in source, travels through git, applies wherever the code runs. That's the normal path.

For emergency operator rescue without a code deploy, aliases can also be added directly to the database:

```bash
jac db alias add "__main__.LegacyPerson" "__main__.Person"
```

DB-resident aliases live in an `aliases` table (SQLite) or `<collection>_aliases` companion collection (Mongo, e.g. `_anchors_aliases` for the default `_anchors` collection) and are loaded into the same in-process `Serializer._aliases` map at backend connect time. After adding one, run `jac db recover-all --app app.jac` to retry any rows currently quarantined for that class.

---

## Backend portability

Everything above is **backend-agnostic**. The `PersistentMemory` interface defines the contract; both `SqliteMemory` and the `jac-scale` `MongoBackend` implement it, and so will any future plugin-provided backend (Postgres, DynamoDB, whatever).

That means the same set of guarantees holds regardless of where your data lives:

- Fingerprints are stamped on every persisted row/document.
- Drift detection runs on every load.
- Quarantine sidecars exist for every backend.
- Aliases (both decorator and CLI-managed) work the same way.
- The `jac db` CLI talks to the live backend through the abstract interface -- same commands, same output, different storage underneath.

For plugin authors implementing a custom backend, see [Plugin Authoring → Recipe 7: Custom persistence backends](plugin-authoring.md#recipe-7-custom-persistence-backends) for the eight methods you need to implement.

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
jac enter app.jac create
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
jac enter app.jac dump
# alice:30:x@y   ← age coerced int→str, email defaulted, class resolved via alias
# bob:25:x@y
```

Three forms of drift handled automatically: class rename via alias, type change via coercion, new field via default.

---

## Inspecting and rescuing data

When something goes wrong (un-aliased rename, malformed stored value, an exception during deserialization), data ends up in quarantine. The full operator workflow:

```bash
# 1. See the state of the world.
jac db inspect --app app.jac

# 2. List what's quarantined.
jac db quarantine list --app app.jac

# 3. Show one row in full to understand why it failed.
jac db quarantine show <row-id-prefix> --app app.jac

# 4. Add a rescue alias if it's a class-rename problem.
jac db alias add "__main__.OldName" "__main__.NewName" --app app.jac

# 5. Re-attempt every quarantined row.
jac db recover-all --app app.jac
```

Full subcommand reference: [CLI → Database Operations](cli/index.md#database-operations).

---

## Limitations

Currently out of scope (planned for future Layer 4 work):

- **Per-archetype `migrate_from(data, from_version)` hook** -- for the small fraction of changes auto-coercion can't handle.
- **Per-field rename hint** (e.g. `@rename_field("old", "new")`) -- today, a rename is "drop old, add new with default."
- **Edge orphan policy** -- when a node quarantines, its incident edges currently stay in the live table; the policy for cascade-delete vs. keep-as-stub is a Layer 4 decision.
- **Deep container coercion** -- `list[int] → list[str]` doesn't recurse into elements.
- **Redis cache parity** -- the L2 cache (`RedisBackend` in jac-scale) still uses pickle. Since it's a cache (the L3 backend is the source of truth), the impact is bounded; the same machinery could be ported when needed.

If you hit one of these and need a workaround today, the path is: stop the app, drop the affected rows manually from the DB, re-create them with code. The quarantine sidecar gives you the original payload for reference.
