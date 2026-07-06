import asyncio;

import from jaclang.jac0core.archetype { Root }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jaclang.scale.memory.memory_hierarchy { ScaleTieredMemory }


obj _FailingBackend {
    def apply(changeset: any) {
        raise RuntimeError("transient backend outage");
    }

    def close { }
}


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
