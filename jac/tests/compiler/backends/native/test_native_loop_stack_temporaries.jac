"""A builtin's scratch buffer is one stack slot per function, not one per call.

`os.path.realpath` wrote into a 4096-byte buffer allocated where the call
was emitted, and stack allocated in a loop body is not released until the
function returns: a loop of a few hundred calls overflowed the stack. The
kernel indexes the interfaces of a snapshot that way, so a program reaching
about 250 of them killed it with SIGSEGV. The fixed-size temporaries of the
os, string, input, random, OSP-predicate and parallel-for emitters are now
allocated once, in the function's entry block.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "a builtin called in a long loop does not grow the stack" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "loop_stack_temporaries.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "True" , out;
}
