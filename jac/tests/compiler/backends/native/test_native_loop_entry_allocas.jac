"""Builtins that need a stack slot take it from the function's entry block.

`float(s)` and `int(s)` hand the C parser the address of an end pointer,
`rpartition` keeps its scan cursor in memory, the set relations and copies
count through a slot, and a parallel `flow for` sizes its thread tables by
the thread count. A slot reserved where the call is lowered is a fresh one
every time a loop runs the call, given back only when the function returns,
so a long enough loop overflows the stack (it was a SIGSEGV on the guard
page inside `strtod`). The fixed-size slots belong in the entry block; the
thread tables, whose size is only known at run time, are given back after
the join. A long loop of each runs in a one-megabyte stack.
"""

import os;
import resource;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     FIXTURE: str = "loop_entry_allocas.jac",
     EXPECTED: list[str] = ["375000.0", "700000", "500000", "1000000", "90000"];

test "a long loop of them runs in a one-megabyte stack" {
    def small_stack {
        (_soft, hard) = resource.getrlimit(resource.RLIMIT_STACK);
        resource.setrlimit(resource.RLIMIT_STACK, (1024 * 1024, hard));
    }
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "loop_entry_allocas");
        native_build(str(FIXTURES / FIXTURE), binary, memory="rc");
        proc = subprocess.run(
            [binary],
            capture_output=True,
            text=True,
            timeout=120,
            preexec_fn=small_stack
        );
        assert proc.returncode == 0 , f"exit {proc.returncode} (a stack overflow is -11) {proc.stderr[-400:]}";
        assert proc.stdout.splitlines() == EXPECTED , proc.stdout;
    }
}
