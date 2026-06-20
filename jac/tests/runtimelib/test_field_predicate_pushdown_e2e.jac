"""End-to-end value-predicate pushdown, driven by real Jac queries.

These tests exercise the full path a user hits: a `[-->[?:T, val > N]]`
comprehension compiles, plans, and routes through the hybrid executor. A
recording L3 backend stands in for Mongo so we can intercept exactly which
predicates were pushed and which rows the backend returned, proving the DB
side did the filtering rather than an in-memory scan.

Each test uses its own node/edge types so the shared session graph stays
isolated.
"""

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }

node BasicAcct {
    has balance: int = 0;
}

edge BHolds {}

node CompAcct {
    has balance: int = 0,
        age: int = 0,
        tier: str = "std";
}

edge CJoined {}

node HybAcct {
    has balance: int = 0;
}

edge HHas {}


"""Apply one MongoDB-style operator the way a backend would."""
def _op_ok(op: str, actual: any, val: any) -> bool {
    if op == "$eq" {
        return actual == val;
    }
    if op == "$ne" {
        return actual != val;
    }
    if op == "$lt" {
        return actual < val;
    }
    if op == "$lte" {
        return actual <= val;
    }
    if op == "$gt" {
        return actual > val;
    }
    if op == "$gte" {
        return actual >= val;
    }
    if op == "$in" {
        return actual in val;
    }
    if op == "$nin" {
        return actual not in val;
    }
    return True;
}


"""True when an archetype satisfies every field predicate in the plan."""
def _backend_match(arch: any, preds: dict) -> bool {
    for (field, ops) in preds.items() {
        actual = getattr(arch, field, None);
        for (op, val) in ops.items() {
            if not _op_ok(op, actual, val) {
                return False;
            }
        }
    }
    return True;
}


# Stand-in L3 with native field pushdown. Filters its store server-side and
# records every plan plus the ids it actually returned, so tests can assert
# the backend fetched only the rows the predicate matched.
obj _RecordingL3 {
    has store: dict = {},
        calls: list = [];

    def capabilities -> set[str] {
        return {"type_pushdown", "field_pushdown", "id_in"};
    }

    def execute_plan(plan: any) -> list {
        out: list = [];
        returned: list = [];
        for (id, anchor) in self.store.items() {
            if plan.id_in is not None and id not in plan.id_in {
                continue;
            }
            if not _backend_match(anchor.archetype, plan.field_predicates) {
                continue;
            }
            out.append(anchor);
            returned.append(id);
        }
        self.calls.append(
            {
                "predicates": plan.field_predicates,
                "id_in": plan.id_in,
                "returned": returned
            }
        );
        return out;
    }

    def get(id: any) -> any {
        return self.store.get(id);
    }

    def put(anchor: any) { }
    def sync { }
    def commit(anchor: any = None) { }
    def close { }
}


"""Evict node anchors from L1 into the stub so the query treats them as cold."""
def _go_cold(ctx: any, stub: any, nodes: list) {
    for n in nodes {
        anchor = n.__jac__;
        stub.store[anchor.id] = anchor;
        ctx.mem.__mem__.pop(anchor.id, None);
    }
}


"""Re-evict ids that a prior query promoted back into L1."""
def _chill(ctx: any, ids: list) {
    for id in ids {
        ctx.mem.__mem__.pop(id, None);
    }
}


def _threshold -> int {
    return 1500;
}


test "filter pushdown fetches only matching rows from the backend" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    orig_l3 = ctx.mem.l3;
    stub = _RecordingL3();
    try {
        r = root;
        nodes: list = [];
        for i in range(20) {
            n = BasicAcct(balance=i * 200);
            r +>:BHolds:+> n;
            nodes.append(n);
        }
        _go_cold(ctx, stub, nodes);
        ctx.mem.l3 = stub;

        result = [r->:BHolds:->[?:BasicAcct, balance>3000]];
        vals = sorted([a.balance for a in result]);
        assert vals == [3200, 3400, 3600, 3800] , f"got {vals}";

        # Interception: the backend was asked once, with the converted
        # predicate, over all 20 candidates, and handed back only the 4 that
        # matched. That gap (20 in, 4 out) is the DB-side filtering.
        assert len(stub.calls) == 1 , f"expected one backend call, got {len(
            stub.calls
        )}";
        call = stub.calls[0];
        assert call["predicates"] == {"balance": {"$gt": 3000}} , (
            f"predicate not pushed: {call['predicates']}"
        );
        assert len(call["id_in"]) == 20 , f"candidate set was {len(call['id_in'])}";
        assert len(call["returned"]) == 4 , (
            f"backend returned {len(
                call['returned']
            )} rows, expected only the 4 matches"
        );
    } finally {
        ctx.mem.l3 = orig_l3;
        ctx.close();
        set_config(JacConfig());
    }
}


test "compound and complex predicates push down correctly" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    orig_l3 = ctx.mem.l3;
    stub = _RecordingL3();
    try {
        r = root;
        data = [
            (1000, 20, "std"),
            (1500, 25, "gold"),
            (2000, 30, "gold"),
            (2500, 35, "plat"),
            (3000, 40, "std"),
            (3500, 45, "plat")
        ];
        nodes: list = [];
        for (b, a, t) in data {
            n = CompAcct(balance=b, age=a, tier=t);
            r +>:CJoined:+> n;
            nodes.append(n);
        }
        ids = [n.__jac__.id for n in nodes];
        _go_cold(ctx, stub, nodes);
        ctx.mem.l3 = stub;

        # Compound range on one field -> merged operator dict.
        stub.calls = [];
        _chill(ctx, ids);
        r1 = [r->:CJoined:->[?:CompAcct, balance>=1000, balance<2000]];
        assert sorted([a.balance for a in r1]) == [1000, 1500];
        assert stub.calls[-1]["predicates"] == {
            "balance": {"$gte": 1000, "$lt": 2000}
        } , f"got {stub.calls[-1]['predicates']}";

        # Compound across two fields -> both pushed.
        stub.calls = [];
        _chill(ctx, ids);
        r2 = [r->:CJoined:->[?:CompAcct, balance>1000, age>=30]];
        assert sorted([a.balance for a in r2]) == [2000, 2500, 3000, 3500];
        assert stub.calls[-1]["predicates"] == {
            "balance": {"$gt": 1000},
            "age": {"$gte": 30}
        } , f"got {stub.calls[-1]['predicates']}";

        # Membership (`in` / `not in`) conversion to `$in` / `$nin` is covered
        # in the unit test; it can't be exercised as a real query here because
        # `jac format` corrupts `field in [...]` inside a filter comprehension
        # (drops the space -> `fieldin[...]`).

        # Computed comparator: the resolved value is what gets pushed.
        stub.calls = [];
        _chill(ctx, ids);
        r4 = [r->:CJoined:->[?:CompAcct, balance>_threshold()]];
        assert sorted([a.balance for a in r4]) == [2000, 2500, 3000, 3500];
        assert stub.calls[-1]["predicates"] == {"balance": {"$gt": 1500}} , (
            f"got {stub.calls[-1]['predicates']}"
        );
    } finally {
        ctx.mem.l3 = orig_l3;
        ctx.close();
        set_config(JacConfig());
    }
}


test "hybrid evaluates fresh L1 nodes locally and pushes only cold ones" {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    ctx = ExecutionContext();
    JacRuntime.set_context(ctx);
    orig_l3 = ctx.mem.l3;
    stub = _RecordingL3();
    try {
        r = root;
        nodes: list = [];
        for i in range(10) {
            n = HybAcct(balance=i * 100);
            r +>:HHas:+> n;
            nodes.append(n);
        }
        # Even-indexed go cold (into the backend); odd-indexed stay resident.
        cold: list = [];
        cold_ids: set = set();
        resident_ids: set = set();
        for (i, n) in enumerate(nodes) {
            if i % 2 == 0 {
                cold.append(n);
                cold_ids.add(n.__jac__.id);
            } else {
                resident_ids.add(n.__jac__.id);
            }
        }
        _go_cold(ctx, stub, cold);
        ctx.mem.l3 = stub;

        # A resident node mutated this session must be judged on its live
        # value, never a stale stored one. balance 100 -> 999 should pass.
        nodes[1].balance = 999;

        result = [r->:HHas:->[?:HybAcct, balance>500]];
        vals = sorted([a.balance for a in result]);
        # Resident odd live vals {999, 300, 500, 700, 900} pass: 999, 700, 900.
        # Cold even vals {0, 200, 400, 600, 800} pass via backend: 600, 800.
        assert vals == [600, 700, 800, 900, 999] , f"got {vals}";

        # The backend was consulted only about the cold partition; the fresh
        # resident node was never pushed.
        assert len(stub.calls) == 1 , f"expected one backend call, got {len(
            stub.calls
        )}";
        call = stub.calls[0];
        assert call["id_in"] == cold_ids , (
            f"backend id_in {call['id_in']} should equal cold set {cold_ids}"
        );
        assert not (call["id_in"] & resident_ids) , "resident ids must not be pushed";
        assert call["predicates"] == {"balance": {"$gt": 500}};
        assert 999 in vals , "fresh L1 value must win over any stored snapshot";
    } finally {
        ctx.mem.l3 = orig_l3;
        ctx.close();
        set_config(JacConfig());
    }
}
