"""Fixture: a vote whose first run can be made to conflict, deterministically.

`Vote` casts the caller's ballot once: it marks the ballot edge under the
caller's root, reads the poll's edges (a graph read, which flushes the edge
first), then counts the vote on the poll node. It commits once before any of
that, so the poll it holds was read by an earlier transaction than the one
that writes it. Two switches, each consumed by the run that honours it:

- `rival_commits`: once this transaction has read the poll and its voters, a
  second connection commits a change to the poll row, so this request's write
  of the poll is stale and the upsert reports a `WriteConflict` after the edge
  was already flushed.
- `commit_faults`: each entry is taken by one run and makes that many of the
  request's following COMMITs fail the way Postgres fails a serializable
  transaction at commit (rolled back, SQLSTATE 40001).

`runs` counts how many times the walker body ran, `failed_commits` how many
COMMITs were made to fail.

`ReadPoll` reads the poll through a typed hop. With `lock_exhaustions`
armed, that many of the request's following queries first make Postgres
itself fail the transaction the way an exhausted predicate-lock table does
(SQLSTATE 53200); `exhausted_queries` counts them.

`Bump` is a read-modify-write of one `Counter` that holds its transaction
open for `hold` seconds, the shape of a real update handler; many of them
at once on the same counter is the contention case. With `busy` the hold
is CPU work instead of a sleep, so the requests compete for the process as
well as for the row, the way a saturated server does.

`Deliver` reports a status dict that its own `on_commit` callback marks as
sent, the shape of a send-then-confirm handler.
"""

import from jaclang.data.pgwire { PgWireError }
import from time { sleep, time }
import from jaclang.runtime.runtime { JacRuntimeInterface as Jac }

glob runs: list[int] = [],
     rival_commits: list[int] = [],
     commit_faults: list[int] = [],
     failed_commits: list[int] = [],
     lock_exhaustions: list[int] = [],
     exhausted_queries: list[int] = [];

node Poll {
    has total: int = 0;
}

edge Ballot: any --> any {
    has cast: bool = False;
}


def request_store -> any {
    mem: any = Jac.get_context().mem;
    return mem.store;
}


def rival_bump(poll_id: str) {
    rival: any = request_store().new_session();
    try {
        rival.rows(
            "UPDATE anchors SET version = version + 1, props = jsonb_set("
            "props, '{archetype,total}',"
            " to_jsonb(CAST(props->'archetype'->>'total' AS int) + 100))"
            " WHERE id = CAST(:i AS uuid) RETURNING version",
            {"i": poll_id}
        );
    } finally {
        rival.close();
    }
}


def fail_commits(times: int) {
    store: any = request_store();
    real_commit = store.commit;
    left = [times];
    def failing_commit {
        if left[0] > 0 and store.in_txn() {
            left[0] -= 1;
            failed_commits.append(1);
            store.rollback();
            raise PgWireError(
                {
                    "C": "40001",
                    "M": "could not serialize access due to read/write"
                    " dependencies among transactions"
                }
            );
        }
        real_commit();
    }
    store.commit = failing_commit;
}


def exhaust_queries(times: int) {
    store: any = request_store();
    real_rows = store.rows;
    left = [times];
    def exhausting_rows(sql: str, params: dict[str, any]) -> list[tuple[any, ...]] {
        if left[0] > 0 and store.in_txn() {
            left[0] -= 1;
            exhausted_queries.append(1);
            real_rows(
                "DO $$ BEGIN RAISE EXCEPTION 'out of shared memory' "
                "USING ERRCODE = '53200'; END $$",
                {}
            );
        }
        return real_rows(sql, params);
    }
    store.rows = exhausting_rows;
}


walker:pub ReadPoll {
    can read_total with Root entry {
        if lock_exhaustions {
            exhaust_queries(lock_exhaustions.pop());
        }
        polls = [here-->[?:Poll]];
        report polls[0].total;
    }
}


walker:pub Seed {
    can plant with Root entry {
        here +>:Ballot():+> Poll();
    }
}


walker:pub Vote {
    can cast_ballot with Root entry {
        runs.append(1);
        polls = [here-->[?:Poll]];
        poll = polls[0];
        commit();
        if commit_faults {
            fail_commits(commit_faults.pop());
        }
        for ballot in [edge here->:Ballot:->] {
            if not ballot.cast {
                ballot.cast = True;
                voters = [poll<--];
                if rival_commits {
                    rival_commits.pop();
                    rival_bump(jid(poll));
                }
                poll.total += len(voters);
            }
        }
    }
}


walker:pub Tally {
    can count with Root entry {
        polls = [here-->[?:Poll]];
        for ballot in [edge here->:Ballot:->] {
            report {"cast": ballot.cast, "total": polls[0].total};
        }
    }
}


node Counter {
    has n: int = 0;
}


walker:pub SeedCounter {
    can plant with Root entry {
        if not [here-->[?:Counter]] {
            here ++> Counter();
        }
    }
}


walker:pub Bump {
    has hold: float = 0.05,
        busy: bool = False;

    can bump with Root entry {
        counter = [here-->[?:Counter]][0];
        seen = counter.n;
        if self.busy {
            until = time() + self.hold;
            spins = 0;
            while time() < until {
                spins += 1;
            }
        } else {
            sleep(self.hold);
        }
        counter.n = seen + 1;
    }
}


walker:pub ReadCounter {
    can read with Root entry {
        report [here-->[?:Counter]][0].n;
    }
}

walker:pub Deliver {
    can go with Root entry {
        status = {"sent": False};
        def mark_sent {
            status["sent"] = True;
        }
        Jac.on_commit(mark_sent);
        report status;
    }
}
