"""`s * n` owns the buffer it builds and releases an owned str operand.

The fixture runs from a `--debug` build, so the RC trace lists every
allocation and free by address while the trace is on; a repeat result or a
concat operand that is never released shows up as a MALLOC whose address is
never freed before the trace stops.
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_run }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "rc_str_repeat_temporaries.jac"
     ),
     MALLOC_RE = re.compile(r"^RC MALLOC\s+ptr=(0x[0-9a-f]+)$"),
     FREE_RE = re.compile(r"^RC FREE\s+ptr=(0x[0-9a-f]+)$");

def check_repeat_temporaries(memory: str) {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "rc_str_repeat_temporaries");
        native_build(FIXTURE, out_bin, memory=memory, extra=["--debug"]);
        out = native_run(out_bin);
    }
    lines = out.splitlines();
    assert lines[-1] == "123" , lines[-1];
    allocations = 0;
    live: set[str] = set();
    for line in lines {
        malloc = MALLOC_RE.search(line);
        if malloc {
            allocations += 1;
            live.add(malloc.group(1));
        }
        free = FREE_RE.search(line);
        if free {
            live.discard(free.group(1));
        }
    }
    assert allocations >= 6 , out[-2000:];
    assert not live , sorted(live);
}

test "string repeat frees its result and owned operand with reference counting" {
    check_repeat_temporaries("rc");
}

test "string repeat frees its result and owned operand with cycle collection" {
    check_repeat_temporaries("managed");
}
