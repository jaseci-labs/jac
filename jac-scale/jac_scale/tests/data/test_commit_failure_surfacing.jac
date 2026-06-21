"""A failed flush must surface, not vanish (#6633 review).

`ScaleTieredMemory.commit` used to swallow every exception at
logger.warning, and `acommit` then marked the request committed
unconditionally. On the spawn path — the dominant production path —
a transient backend error during commit silently lost the request's
graph mutations: no error to the caller, and the close-time backstop
(`if not self._committed`) was bypassed too.

The contract under test: commit propagates flush failures (core
`TieredMemory.commit` never swallowed), a failed acommit leaves
`_committed` False so close() retries, and the unit of work survives
the failure for that retry.
"""

import asyncio;

import from jaclang.jac0core.archetype { Root }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jac_scale.memory_hierarchy { ScaleTieredMemory }


"""L3 stand-in whose flush always fails, like a Mongo outage mid-request."""
obj _FailingBackend {
    def apply(changeset: any) {
        raise RuntimeError("transient backend outage");
    }

    def close { }
}


"""A ScaleTieredMemory wired by hand (no Mongo/Redis): empty L1, one
pending create intent, and an L3 whose apply() always fails."""
def _mem_with_pending_intent -> ScaleTieredMemory {
    mem = ScaleTieredMemory.__new__(ScaleTieredMemory);
    mem.__mem__ = {};
    mem.changes = ChangeSet();
    mem.l2 = None;
    mem.l3 = _FailingBackend();
    mem._committed = False;
    ranch = Root().__jac__;
    ranch.persistent = True;
    mem.changes.record_create(ranch);
    return mem;
}


test "commit surfaces backend apply failure instead of swallowing it" {
    mem = _mem_with_pending_intent();
    raised = False;
    try {
        mem.commit();
    } except RuntimeError {
        raised = True;
    }
    assert raised , (
        "commit must propagate a backend flush failure so the request "
        "lifecycle can abort/error — a swallowed failure is silent data loss"
    );
    assert not mem.changes.is_empty() , (
        "a failed commit must keep the unit of work so the close-time "
        "backstop (or an explicit retry) still has something to flush"
    );
}


test "acommit does not mark the request committed when the flush fails" {
    mem = _mem_with_pending_intent();
    raised = False;
    try {
        asyncio.run(mem.acommit());
    } except RuntimeError {
        raised = True;
    }
    assert raised , "acommit must propagate the underlying commit failure";
    assert not mem._committed , (
        "a failed flush must leave _committed False: otherwise close() skips "
        "its backstop commit and the request's mutations are silently lost"
    );
}
