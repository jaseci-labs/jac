"""Keyset pagination written in Jac source, end to end.

A feed keyed on a timestamp alone drops or duplicates rows whenever two
entries share a timestamp. The tiebreak needs a composite key, which the
closed sublanguage now admits as a tuple of declared field names against a
tuple value of the same arity -- same operators, same push-to-SQL guarantee,
one more arity.

These drive the real traversal through a real store: the source form parses
and compiles, the composite predicate selects the same rows the equivalent
object-space filter would, and paging a feed with duplicate timestamps
neither drops nor repeats an entry.
"""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.runtime.context { ExecutionContext }

node Feed {
    has name: str = "";
}

node Entry {
    has at: int = 0,
        seq: int = 0;
}

edge Carried: Feed --> Entry {}


def _ctx(tmpdir: str) -> ExecutionContext {
    return ExecutionContext(
        base_path_dir=tmpdir, full_target_path=str(Path(tmpdir) / "ks_app.jac")
    );
}


"""A feed of 12 entries over 4 distinct timestamps -- 3 entries share each."""
def _seed -> Feed {
    feed = Feed(name="main");
    root ++> feed;
    for i in range(12) {
        feed +>:Carried():+> Entry(at=(i // 3), seq=i);
    }
    return feed;
}


test "a composite key in source selects the same rows as object space" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            feed = _seed();
            ctx.mem.commit();
            cut_at = 2;
            cut_seq = 7;
            got = [feed->:Carried:->[?:Entry, (at,seq)<(cut_at,cut_seq)]];
            everything = [feed->:Carried:->[?:Entry]];
            want = [
                e
                for e in everything
                if (e.at, e.seq) < (cut_at, cut_seq)
            ];
            assert sorted([e.seq for e in got]) == sorted([e.seq for e in want]) , (
                f"composite key selected {sorted([e.seq for e in got])}, "
                f"object space says {sorted([e.seq for e in want])}"
            );
            assert len(got) > 0 and len(got) < len(everything) , len(got);
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}


test "paging a feed with duplicate timestamps drops nothing and repeats nothing" {
    with TemporaryDirectory() as td {
        old = JacRuntime.exec_ctx;
        ctx = _ctx(td);
        JacRuntime.exec_ctx = ctx;
        try {
            feed = _seed();
            ctx.mem.commit();
            page_size = 5;
            cur_at = 99;
            cur_seq = 99;
            seen: list[int] = [];
            for _round in range(6) {
                batch = [feed->:Carried:->[?:Entry, (at,seq)<(cur_at,cur_seq)]];
                batch.sort(key=lambda (e: Entry) { (-e.at, -e.seq); });
                page = batch[:page_size];
                if not page {
                    break;
                }
                for e in page {
                    seen.append(e.seq);
                }
                last = page[len(page) - 1];
                cur_at = last.at;
                cur_seq = last.seq;
            }
            assert sorted(seen) == list(range(12)) , (
                f"paging lost or repeated entries: {sorted(seen)}"
            );
            assert len(seen) == len(set(seen)) , f"duplicate rows across pages: {seen}";
        } finally {
            JacRuntime.exec_ctx = old;
            ctx.close();
        }
    }
}
