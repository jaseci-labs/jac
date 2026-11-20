"""`set(...)` and `frozenset(...)` lower natively over ranges and other iterables.

The native `set` constructor only knew bytes, lists and sets, so
`set(range(1, n + 1))`, the same over a tuple or a dict, and `frozenset` of
any of them were refused (E5092) and their function sent to Python. For
numeric elements they now drain the iterable the way `list` does; a native
build refuses any demoted function, so identity with the Python backend
under every memory profile also proves the native path was taken.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { assert_native_identity }

"""The IR lines of the function whose name ends in `.<name>`."""
def _function_ir(text: str, name: str) -> str {
    body: list[str] = [];
    inside = False;
    for line in text.splitlines() {
        if line.startswith("define") and f'.{name}"(' in line {
            inside = True;
        }
        if inside {
            body.append(line);
            if line == "}" {
                break;
            }
        }
    }
    return "\n".join(body);
}

test "native set and frozenset over ranges and other iterables agree with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "set_from_iterable.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "3 3 [1, 2, 3]" , out;
    assert lines[1] == "[5, 15, 4, 1, 5] [0, 0, 4, 1, 0]" , out;
    assert lines[2] == "[2, 4, 9] [3, 5, 7]" , out;
    assert lines[3] == "[-0.5, 1.5, 2.5] 0" , out;
}

test "the list a set drains is dropped under nogc once the set is filled" {
    # `set(range(n))` drains the range into a temporary list first. A
    # headerless build frees a temporary only at a release it knows how to
    # act on, so the list must be handed to one: without it every call
    # leaves the list and its buffer behind.
    source = (
        "def drained(count: int) -> int {\n"
        "    seen = set(range(count));\n    return len(seen);\n}\n"
        "def frozen(count: int) -> int {\n"
        "    seen = frozenset(range(count));\n    return len(seen);\n}\n"
    );
    with tempfile.TemporaryDirectory() as tmp {
        prog = JacProgram();
        ir = prog.compile(
            file_path=os.path.join(tmp, "set_drain.jac"),
            use_str=source,
            options=CompileOptions(
                force_codespace='native',
                aot_mode=True,
                na_gc_mode="none",
                nogc_enforce_all=True,
                skip_native_engine=True,
                no_ir_cache=True
            )
        );
        assert not prog.errors_had , str(prog.errors_had);
        text = str(ir.gen.llvm_ir);
    }
    for name in ("drained", "frozen") {
        body = _function_ir(text, name);
        assert '@"__list_new_i64"' in body , f"{name} no longer drains through a list:\n{body}";
        assert '@"__drop_List_i64"' in body , f"{name} never drops its temporary list:\n{body}";
    }
}
