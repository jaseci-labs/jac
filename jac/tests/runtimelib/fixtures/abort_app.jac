"""Fixture for abort-on-error tests: walkers that mutate then fail.

`LateWrite` saves an item, then another from an `on_commit` callback that `fault`
can make fail. `LatePeek`'s getter raises while its response serializes.
`LateFromReadTier` writes nothing itself, so it runs on the read tier.
"""

import from uuid { UUID }
import from jaclang.data.pgwire { PgWireError }
import from jaclang.runtime.exceptions { ReadOnlyRetry, WriteConflict }
import from jaclang.runtime.runtime { JacRuntimeInterface as Jac }
import from jaclang.server.exchange { respond }

node AbortItem {
    has name: str = "";
}

walker:protect CreateAndFail {
    can go with Root entry {
        here ++> AbortItem(name="ghost");
        raise Exception("intentional failure after mutation");
    }
}

walker:protect DeleteAndFail {
    can go with Root entry {
        for nbr in [-->] {
            del nbr;
        }
        raise Exception("intentional failure after delete");
    }
}

walker:protect CreateOk {
    has name: str = "kept";

    can go with Root entry {
        here ++> AbortItem(name=self.name);
        report {"ok": True};
    }
}

walker:protect CountItems {
    can go with Root entry {
        report {"count": len([-->])};
    }
}

glob runs: list[int] = [],
     late_runs: list[int] = [],
     peek_armed: list[int] = [],
     cancel_started: any = None,
     cancel_release: any = None;

def late_save(home: Root, name: str, fault: str = "") {
    def late {
        late_runs.append(1);
        mem: any = Jac.get_context().mem;
        store: any = mem.store;
        if fault == "own_db" {
            store.rows("SELECT 1/0", {});
        }
        if fault == "wrapped_db" {
            try {
                store.rows("SELECT 1/0", {});
            } except Exception as e {
                raise ValueError("the app's own error") from e;
            }
        }
        if fault == "raised_in_except" {
            try {
                store.rows("SELECT 1/0", {});
            } except Exception {
                raise ValueError("the app's own error");
            }
        }
        if fault == "other_db" {
            raise PgWireError({"C": "XX000", "M": "from another connection"});
        }
        if fault == "conflict" {
            raise WriteConflict(anchor_id=UUID(int=0));
        }
        if fault == "read_tier" {
            raise ReadOnlyRetry(anchor_id=UUID(int=0));
        }
        if fault == "chain" {
            on_commit(lambda { late_runs.append(1); });
        }
        if fault == "rival" {
            item = [home-->[?:AbortItem]][0];
            rival = store.new_session();
            rival.rows(
                "UPDATE anchors SET version = version + 1 WHERE id = CAST(:i AS uuid) RETURNING version",
                {"i": jid(item)}
            );
            rival.close();
            item.name = "moved";
        }
        home ++> AbortItem(name=name);
    }
    on_commit(late);
}

walker:protect LateWrite {
    has first: str = "first",
        late: str = "late",
        fault: str = "",
        status: int = 200,
        commit_first: bool = False;

    can go with Root entry {
        respond(status=self.status);
        runs.append(1);
        here ++> AbortItem(name=self.first);
        late_save(here, self.late, self.fault);
        if self.fault in ("nested_serial", "child_serial", "explicit_serial") {
            mem: any = Jac.get_context().mem;
            def nested {
                here ++> AbortItem(name="nested");
                mem.on_commit(lambda() { late_runs.append(1); });
            }
            if self.fault == "nested_serial" {
                mem.run_request(nested);
            } elif self.fault == "child_serial" {
                import from jaclang.runtime.context { ExecutionContext }
                child = ExecutionContext(_parent=Jac.get_context(), _own_session=True);
                try {
                    def child_body {
                        item = AbortItem(name="independent");
                        anchor: any = item.__jac__;
                        anchor.persistent = True;
                        child.mem.put(anchor);
                        child.mem.on_commit(lambda() { late_runs.append(1); });
                    }
                    child.mem.run_request(child_body);
                } finally {
                    child.close();
                }
            } else {
                Jac.commit();
            }
            here ++> AbortItem(name="rolled-back");
            store: any = mem.store;
            real_commit = store.commit;
            remaining = [1];
            def fail_once {
                if remaining[0] and store.in_txn() {
                    remaining[0] -= 1;
                    store.rollback();
                    raise PgWireError({"C": "40001", "M": "serialization failure"});
                }
                real_commit();
            }
            store.commit = fail_once;
        }
        if self.commit_first {
            commit();
        }
        report {"ok": True};
    }
}

def:protect late_note(late: str = "late", status: int = 200) -> str {
    respond(status=status);
    runs.append(1);
    root ++> AbortItem(name="first");
    late_save(root, late);
    return "noted";
}

node Peeky {
    has peek: int {
        getter {
            if peek_armed {
                peek_armed.clear();
                raise ValueError("the getter's own failure");
            }
            return 1;
        }
    }
}

walker:protect LatePeek {
    can go with Root entry {
        runs.append(1);
        here ++> AbortItem(name="first");
        on_commit(lambda { peek_armed.append(1); });
        report Peeky();
    }
}

walker:protect LateFromReadTier {
    can go with Root entry {
        runs.append(1);
        late_save(here, "late");
    }
}

walker:protect CancelDurable {
    can go with Root entry {
        runs.append(1);
        mem: any = Jac.get_context().mem;
        def nested {
            here ++> AbortItem(name="nested");
            mem.on_commit(lambda() { late_runs.append(1); });
        }
        mem.run_request(nested);
        cancel_started.set();
        assert cancel_release.wait(10);
    }
}
