"""Fast paths for strings, numbers as text and counting in a dict.

- A comparison against a one-character literal reads the other string's first
  byte instead of calling `__jac_str_cmp` and `memcmp`.
- `str(int)`, an int's repr and f-strings of plain `{str}`/`{int}` pieces
  format digits directly instead of through `vsnprintf`.
- A float's shortest repr takes a direct path for values with up to six
  decimals below 1e15, and otherwise tries 15, 16 and 17 digits instead of
  every precision from one up (subnormals keep the full search).
- `d[k] = d.get(k, c) op e` hashes `k` once and probes once.

The fixture prints what the Python backend prints under rc and managed.
"""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { assert_native_identity, jac_command, NATIVE_FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob STR_FIXTURE: str = os.path.join(NATIVE_FIXTURES, "str_dict_fast_paths.jac");

"""The unoptimized IR of `fixture`."""
def fixture_ir(fixture: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=fixture, options=CompileOptions(aot_mode=True, na_gc_mode="rc")
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(mod.gen.llvm_ir);
}

"""The body of the function whose name ends in `name`."""
def body_of(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*' + re.escape(name) + r'"?\(.*?\n}\n', text, re.S);
    assert found is not None , f"{name} not found in the IR";
    return found.group(0);
}

test "strings, numbers and dict counts take their fast paths" {
    text = fixture_ir(STR_FIXTURE);
    assert "s1.first" in body_of(text, ".compares") , "no one-byte compare";
    assert "dcu.slot" in body_of(text, ".counters") , "no single-probe update";
    numbers = body_of(text, ".numbers");
    assert "__jac_fmt_i64" in numbers and "fd.total" in numbers , "f-strings still use snprintf";
    assert "fr.fast.emit" in body_of(text, '@"__jac_float_repr"') , "no direct float repr";
}

test "the program prints what the Python backend prints under rc and managed" {
    assert_native_identity(STR_FIXTURE, profiles=["rc", "managed"]);
}


test "a single-probe dict update on unsigned values adds unsigned" {
    fixture = os.path.join(NATIVE_FIXTURES, "dict_counter_unsigned.jac");
    with tempfile.TemporaryDirectory() as scratch {
        binary = os.path.join(scratch, "probe");
        comp = subprocess.run(
            jac_command("build", "--native", fixture, "-o", binary),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert comp.returncode == 0 , comp.stderr[-1500:];
        proc = subprocess.run([binary], capture_output=True, text=True, timeout=120);
    }
    assert proc.stdout.splitlines()
        == ["9223372036854775808", "raised OverflowError"] , (
        proc.stdout + proc.stderr[-800:]
    );
}
