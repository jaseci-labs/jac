"""Small checked helpers inline into their callers.

Every checked operation (an overflow, a shift, a null view) branches to a
call of the unit's raise helper. LLVM's inliner charged each such call site
as a full call, so an accessor a few loads long with a handful of checks
cost more than the inline threshold and stayed out of line in every caller:
JacPython's dict entry accessors ran as separate functions on every lookup.
The raise helper now tells the inliner a raise site adds about one
instruction, so these helpers inline; a raise from an inlined helper still
lands in the caller's handler.
"""

import os;
import re;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.backends.native.llvm.binding { parse_bitcode }
import from tests.support { compile_native_ir, native_build, native_run }

glob FIXTURE: str = "inline_checked_helpers.jac",
     CALLERS: list[str] = ["sum_keys", "first_and_last", "key_or_flag"];

"""The text of function `name` in the module text `text` ("" when absent)."""
def fn_body(text: str, name: str) -> str {
    found = re.search(r'define [^\n]*\.' + name + r'"?\(.*?\n}\n', text, re.S);
    return found.group(0) if found else "";
}

"""The calls in `body` to the fixture's `entry_key`."""
def entry_key_calls(body: str) -> list[str] {
    return re.findall(r'call [^\n]*\.entry_key"?\(', body);
}

test "the raise helper charges the inliner one instruction per raise site" {
    mod = compile_native_ir(FIXTURE);
    text = str(mod.gen.llvm_ir);
    head = re.search(r'define [^\n]*@"?__jac_exc_raise"?\([^\n]*', text);
    assert head is not None , "no raise helper in the unit";
    assert '"call-inline-cost"="5"' in head.group(0) , head.group(0);
    assert "noreturn" in head.group(0) , head.group(0);
}

test "a checked accessor inlines into every caller of its unit" {
    mod = compile_native_ir(FIXTURE);
    assert mod.gen.native_bitcode is not None , "no optimized bitcode";
    raw = str(mod.gen.llvm_ir);
    opt = str(parse_bitcode(mod.gen.native_bitcode));
    for caller in CALLERS {
        assert entry_key_calls(fn_body(raw, caller)) , f"{caller} never called entry_key";
        body = fn_body(opt, caller);
        assert body , f"{caller} not found in the optimized IR";
        assert not entry_key_calls(body) , f"entry_key stayed out of line in {caller}:\n{body}";
    }
}

test "a raise from an inlined accessor lands in the caller's handler" {
    source = str(Path(__file__).resolve().parent / "fixtures" / FIXTURE);
    with tempfile.TemporaryDirectory() as scratch {
        for memory in ["rc", "managed"] {
            binary = os.path.join(scratch, f"inline_checked_helpers.{memory}");
            native_build(source, binary, memory=memory);
            out = native_run(binary);
            assert out.splitlines() == ["288 1071", "21 -1", "288 1071", "21 -1"] , (
                f"{memory}: {out}"
            );
        }
    }
}
