"""Pointer reinterpret casts lower natively, as the NaIRGen backend lowered them.

js_engine and the CEF desktop shim cast between an address (`int`) and a
str, an obj or a C struct under `# jac:ignore[E1001]`. MIR refused every one
of them ("Native lowering failed for conversion 'int to str'", "'obj UVBuf to
int'", "'c.struct cef_browser_t to int'"), so whole call graphs demoted out of
libjs_engine.so. The casts mean:

- `s: str = p` views the NUL-terminated bytes at `p` as a borrowed str whose
  refcount root is `p` itself; `x.f = p` stores it as a str field the same way.
- `p: int = s` is the address of NUL-terminated bytes holding `s`: the string
  itself when it is whole, a copy when it is a slice. Either way the address
  holds a reference of its own, so it stays valid after `s` is released.
- an obj and an address convert both ways as the object's pointer.
- `v: S = p` for a C struct `S` makes `v` a view of the struct at `p` (field
  writes land in that memory), and a C struct used as an `int` is the address
  of its storage, or its bits when it is an all-integer struct of 33 to 64 bits.

A global int initialized with a u64-range literal (`0xFFFF_0000_0000_0000`)
holds the literal's 64-bit pattern, like the NaIRGen static initializer.
"""

import os;
import tempfile;
import from pathlib { Path }
import from tests.support { native_build, native_run }

glob FIXTURES: Path = Path(__file__).resolve().parent / "fixtures",
     EXPECTED: list[str] = [
         "cast hello 5",
         "copy hello",
         "field hello 3",
         "say orld",
         "slice cdef",
         "iov ok",
         "iov len 7",
         "obj True",
         "pair 34",
         "poked 39 4",
         "same True",
         "filled 3 9",
         "word True"
     ];

def run_fixture(memory: str, name: str = "pointer_reinterpret") -> list[str] {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, f"{name}.{memory}");
        native_build(str(FIXTURES / f"{name}.jac"), out_bin, memory=memory);
        return native_run(out_bin).splitlines();
    }
}

"""Raw `write` calls and buffered prints interleave by profile, so compare as sets."""
def assert_lines(lines: list[str]) {
    assert sorted(lines) == sorted(EXPECTED) , "\n".join(lines);
}

test "pointer reinterpret casts under the managed profile" {
    assert_lines(run_fixture("managed"));
}

test "pointer reinterpret casts under the rc profile" {
    assert_lines(run_fixture("rc"));
}

test "a global int keeps the 64-bit pattern of a u64-range literal" {
    assert run_fixture("rc", "u64_global_literal")
        == ["mask True True", "tag 65535", "high True"];
}
