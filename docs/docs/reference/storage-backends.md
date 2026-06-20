# Custom Storage Backends

This page is for plugin authors writing a custom storage backend -- a Postgres adapter, a DynamoDB wrapper, an in-memory test double, or anything else that stores the Jac object-spatial graph.

The basic persistence interface (`PersistentMemory`) is covered in [Plugin Authoring → Recipe 7](plugin-authoring.md#recipe-7-custom-persistence-backends). That recipe covers `sync`, `bulk_put`, quarantine sidecars, schema aliases, and the `jac db` operator surface. Read it first.

This page covers the **query pushdown layer**: how to tell the runtime planner what your backend can do natively, so traversals like `node --> [?:User, age < 28][0:50]` become a single server-side query instead of load-all + filter-in-Python.

---

## Why pushdown matters

When a Jac program traverses a graph with a type filter and field predicates:

```jac
with entry {
    results = [root --> [?:Order, status == "pending", total > 1000]];
}
```

Without pushdown, the runtime has to:

1. Load every node reachable from `root` across the wire.
2. Deserialize every anchor in Python.
3. Discard the ones that don't match.

At 10,000 neighbors this is a ~200× overhead vs. a single `WHERE` clause or `collection.find()`. The pushdown layer eliminates it for backends that can express the query natively.

The hook for this is **not** `edges_to_nodes` or `get_edges` (those hooks carry no query parameters by design -- they're the correctness fallback). Pushdown goes through `execute_plan` + `capabilities()`.

---

## The contract at a glance

Two methods on your backend class enable pushdown:

```jac
obj MyBackend(PersistentMemory) {
    def capabilities -> set[str];
    def execute_plan(plan: QueryPlan) -> Generator[Anchor, None, None];
}
```

The planner calls `capabilities()` to learn what your backend can do natively. It then builds a `QueryPlan` containing only the dimensions your backend declared, and calls `execute_plan(plan)`. If `execute_plan` is not implemented, the planner falls back to the topology index + `batch_get` floor path automatically -- no crash, no wrong results, just slower queries.

---

## The `QueryPlan` object

`QueryPlan` lives in `jaclang.runtimelib.query_plan`. Every field is optional; the planner only populates the ones your `capabilities()` include.

| Field | Type | What it means |
|---|---|---|
| `root_id` | `UUID \| None` | Root of the traversal. Use this to scope the query to the right tenant / namespace. |
| `chain` | `list[HopSpec]` | Ordered hops: `(edge_type, node_type, direction)`. The final hop is the target node type. |
| `node_type_final` | `str \| None` | Shortcut to `chain[-1].node_type` -- the archetype class name of the nodes to return. |
| `field_predicates` | `dict[str, list[FieldPredicate]]` | Field-level constraints on the final hop. Key is the bare field name; value is a list of `FieldPredicate` objects (ANDed). |
| `id_in` | `set[UUID] \| None` | Pre-narrowed candidate set from the topology index. When present, restrict your query to these IDs instead of scanning everything. |
| `slc` | `slice \| None` | Pagination: `slice(offset, offset + limit)`. |
| `post_filter` | `Callable \| None` | Python-side safety filter. The planner applies this to every anchor you yield, so you can ignore it -- but it's there if you want to inspect it. |

### `HopSpec`

```jac
obj HopSpec {
    has edge_type: (str | None),   # None = any edge type
        node_type: (str | None),   # None = any node type
        direction: int;            # 1 = outbound, -1 = inbound, 0 = either
}
```

### `FieldPredicate`

`FieldPredicate` is in `jaclang.jac0core.filter_spec`. It carries a single constraint on one field with a backend-neutral operator name.

```jac
obj FieldPredicate {
    has op: str,    # backend-neutral: eq, ne, lt, lte, gt, gte, in, nin
        value: Any;
}
```

Translate `op` to your native syntax at query time:

| `op` | SQL | MongoDB |
|---|---|---|
| `eq` | `field = %s` | `{"$eq": value}` |
| `ne` | `field != %s` | `{"$ne": value}` |
| `lt` | `field < %s` | `{"$lt": value}` |
| `lte` | `field <= %s` | `{"$lte": value}` |
| `gt` | `field > %s` | `{"$gt": value}` |
| `gte` | `field >= %s` | `{"$gte": value}` |
| `in` | `field = ANY(%s)` | `{"$in": value}` |
| `nin` | `field != ALL(%s)` | `{"$nin": value}` |

Multiple predicates on the **same** field are ANDed (`age >= 20 AND age < 28`). Multiple fields are also ANDed.

---

## Capability flags

`capabilities()` returns a `set[str]`. Each flag is a promise: the planner will only include that dimension in the plan if you declared it.

| Flag | What the planner sends you | What you must handle |
|---|---|---|
| `type_pushdown` | `plan.node_type_final` is set | Filter results to nodes of that archetype class name |
| `field_pushdown` | `plan.field_predicates` is populated | Apply the `FieldPredicate` constraints natively |
| `id_in` | `plan.id_in` is set when the topology index has pre-narrowed | Restrict the query to those UUIDs only |
| `slice` | `plan.slc` is set | Apply `OFFSET` / `LIMIT` (or equivalent) natively |

Declare only the flags you fully support. Partial declarations are safe -- the planner combines what you can do with its own topology index narrowing for the rest.

```jac
def capabilities -> set[str] {
    return {'type_pushdown', 'field_pushdown', 'id_in', 'slice'};
}
```

---

## `execute_plan` contract

`execute_plan` must `yield` `NodeAnchor` objects for every matching node, in any order (unless you declared `slice`, in which case order matters). The planner applies `plan.post_filter` on your output as a safety net -- you don't need to apply it yourself.

```jac
obj MyBackend(PersistentMemory) {
    def execute_plan(plan: QueryPlan) -> any {
        (query, skip_n, limit_n) = _plan_to_native_query(plan);
        cursor = self.collection.find(query).skip(skip_n);
        if limit_n is not None {
            cursor = cursor.limit(limit_n);
        }
        for doc in cursor {
            if (anchor := self._load_anchor(doc)) {
                yield anchor;
            }
        }
    }
}
```

**Opt out gracefully.** If at runtime you can't handle a particular plan (e.g. a capability you declared is unavailable right now), return early without yielding. The planner detects zero results and may fall back. Better: only declare capabilities that are always available.

---

## Worked example: Postgres adapter sketch

This sketch shows how the translation layer works. It is not a complete implementation -- `_load_anchor`, connection management, and error handling are omitted for clarity.

```python
from jaclang.runtimelib.query_plan import QueryPlan
from jaclang.runtimelib.memory import PersistentMemory

class PostgresBackend(PersistentMemory):

    def capabilities(self) -> set:
        return {"type_pushdown", "field_pushdown", "id_in", "slice"}

    def execute_plan(self, plan: QueryPlan):
        where_clauses = []
        params = []

        # Type filter
        if plan.node_type_final:
            where_clauses.append("data->>'arch_type' = %s")
            params.append(plan.node_type_final)

        # Root scoping
        if plan.root_id:
            where_clauses.append("root_id = %s")
            params.append(str(plan.root_id))

        # Candidate set from topology index
        if plan.id_in:
            where_clauses.append("id = ANY(%s)")
            params.append([str(uid) for uid in plan.id_in])

        # Field predicates
        _OP_MAP = {
            "eq": "=", "ne": "!=", "lt": "<", "lte": "<=",
            "gt": ">", "gte": ">=",
        }
        for field, preds in (plan.field_predicates or {}).items():
            for pred in preds:
                if pred.op in _OP_MAP:
                    where_clauses.append(
                        f"(data->'archetype'->>'{field}')::numeric {_OP_MAP[pred.op]} %s"
                    )
                    params.append(pred.value)
                elif pred.op == "in":
                    where_clauses.append(
                        f"data->'archetype'->>'{field}' = ANY(%s)"
                    )
                    params.append(pred.value)

        sql = "SELECT * FROM anchors"
        if where_clauses:
            sql += " WHERE " + " AND ".join(where_clauses)

        # Slice
        if plan.slc:
            offset = plan.slc.start or 0
            limit  = plan.slc.stop - offset if plan.slc.stop else None
            sql += f" OFFSET {offset}"
            if limit:
                sql += f" LIMIT {limit}"

        with self.conn.cursor() as cur:
            cur.execute(sql, params)
            for row in cur:
                if anchor := self._load_anchor(row):
                    yield anchor
```

---

## The fallback guarantee

If your backend does not implement `execute_plan`, or if `capabilities()` returns an empty set, the runtime falls back automatically:

1. The **topology index** narrows the candidate set by type (fast, in-memory).
2. `batch_get` loads the candidates.
3. The **Python-level post-filter** (the `FilterSpec` lambda) discards non-matching nodes.

Results are always correct. The only difference is query cost. You can ship a backend without pushdown and add `execute_plan` later -- the planner adapts.

---

## Testing your backend

Use the `execute_plan_fetch_count` pattern from `MongoBackend` to prove pushdown is happening:

```jac
test "execute_plan called, not batch_get" {
    mongo.reset_counters();
    results = [r --> [?:Order, status == "pending"]];
    assert mongo.execute_plan_fetch_count == len(results);
    assert mongo.fetch_count == 0;  # batch_get was not used
}
```

If `fetch_count > 0`, the fallback floor path was taken -- either the backend isn't declaring the right capabilities, or the planner determined it couldn't use pushdown for this query shape.

---

## Reference

- `jaclang.runtimelib.query_plan` -- `QueryPlan`, `HopSpec`, `FieldPredicate` types
- `jaclang.runtimelib.memory` -- `PersistentMemory` base class
- `jac-scale/jac_scale/impl/memory_hierarchy.mongo.impl.jac` -- `MongoBackend`, the canonical pushdown implementation
- [Plugin Authoring → Recipe 7](plugin-authoring.md#recipe-7-custom-persistence-backends) -- basic persistence interface (`sync`, `bulk_put`, quarantine, aliases)
- [Persistence & Schema Migration](persistence.md) -- schema fingerprints, drift tolerance, quarantine model
