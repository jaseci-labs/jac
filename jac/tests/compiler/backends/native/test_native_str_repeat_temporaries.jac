"""`s * n` owns the buffer it builds and releases an owned str operand.

The fixture runs from a `--debug` build, so the RC trace lists every
allocation and free; a repeat result or a concat operand that is never
released shows up as a `str_repeat` / `str_concat` MALLOC with no FREE.
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_run }

glob FIXTURE = str(
         Path(__file__).resolve().parent / "fixtures" / "rc_str_repeat_temporaries.jac"
     ),
     MALLOC_RE = re.compile(r"RC MALLOC\s+id=(\d+)\s.*\bop=(str_concat|str_repeat)\b"),
     FREE_RE = re.compile(r"RC FREE\s+id=(\d+)\s");

def check_repeat_temporaries(memory: str) {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "rc_str_repeat_temporaries");
        native_build(FIXTURE, out_bin, memory=memory, extra=["--debug"]);
        out = native_run(out_bin);
    }
    lines = out.splitlines();
    assert lines[-1] == "123" , lines[-1];
    allocated: dict[str, str] = {};
    freed: set[str] = set();
    for line in lines {
        malloc = MALLOC_RE.search(line);
        if malloc {
            allocated[malloc.group(1)] = malloc.group(2);
        }
        free = FREE_RE.search(line);
        if free {
            freed.add(free.group(1));
        }
    }
    assert "str_repeat" in allocated.values() , out[-2000:];
    assert "str_concat" in allocated.values() , out[-2000:];
    leaked = {
        aid: op
        for (aid, op) in allocated.items()
        if aid not in freed
    };
    assert not leaked , leaked;
}

test "string repeat frees its result and owned operand with reference counting" {
    check_repeat_temporaries("rc");
}

test "string repeat frees its result and owned operand with cycle collection" {
    check_repeat_temporaries("managed");
}
