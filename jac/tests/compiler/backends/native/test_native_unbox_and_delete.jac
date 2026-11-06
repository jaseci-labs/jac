"""Reading an any value as a scalar checks its runtime tag, and `del` of a
property runs its deleter.

MIR read the payload of an `any` without looking at its tag, so a str read
as int printed its address and a float read as int printed its bit pattern;
now one tag compare guards the read and a mismatch raises TypeError. `del
c.radius` was refused as "del of AtomTrailer"; a property with a deleter now
calls it, and a field without one is still refused, as NaIRGen refused it.
"""
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { assert_native_identity, native_build, native_run }

glob FIXTURES: str = str(Path(__file__).resolve().parent / "fixtures");

test "any values read as scalars match Python where Python also rejects them" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "any_unbox_checked.jac"), profiles=["managed"]
    );
    assert out.splitlines()[-1] == "TypeError TypeError" , out;
}

test "a native slot of another type rejects the any value it is given" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "mismatch");
        native_build(
            os.path.join(FIXTURES, "any_unbox_mismatch.jac"), out_bin, memory="managed"
        );
        out = native_run(out_bin, None);
    }
    assert out.splitlines()
        == [
            "TypeError: expected int, got float",
            "TypeError: expected bool, got str"
        ] , out;
}

test "del of a property runs its deleter" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "prop_deleter.jac"), profiles=["managed"]
    );
    assert out.splitlines()[-1] == "0.0 ''" , out;
}

test "del of a plain field is still refused" {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, "_del_plain_field.jac"),
        use_str="obj Box { has size: int = 1; }\n"
        "with entry { b = Box(); del b.size; print(b); }\n",
        options=CompileOptions(native_required=True, no_ir_cache=True)
    );
    messages = [e.pretty_print() for e in prog.errors_had];
    assert any("del of AtomTrailer" in m for m in messages) , messages;
}
