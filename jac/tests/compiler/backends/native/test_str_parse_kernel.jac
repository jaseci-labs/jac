"""C6 gate (#7870): the zero-copy parse kernel's tokenize loop is
allocation-free per token in the enforced build -- tokens are rootless
slice views, keyword compares run length-aware memcmp over descriptor
parts (__jac_str_cmp3), and char probes read the static char cache.
Behavioral identity across modes rides the ownbench differential."""

import os;
import re;
import from pathlib { Path }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { unit_symbol }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob KERNEL = str(
         Path(__file__).resolve().parents[4]
             / "examples"
             / "ownbench"
             / "kernels"
             / "own_parse.jac"
     );

def _tokenize_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=KERNEL,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    sym = re.escape(unit_symbol(ir, "tokenize"));
    m = re.search(r'define[^\n]*@"?' + sym + r'"?\([^\n]*\n(.*?)\n\}', text, re.DOTALL);
    assert m , "tokenize fn not found in IR";
    return m.group(1);
}

test "enforced tokenize loop allocates nothing per token" {
    body = _tokenize_ir("none", True);
    assert "s.view" in body , "tokens are not slice views";
    assert "__jac_halloc" not in body , "enforced tokenize still allocates";
    assert "__rc_alloc" not in body , "enforced tokenize emits rc allocation";
    assert "__jac_str_cmp3" in body , "keyword compares bypass descriptor parts";
    assert "s.view.root" not in body , "enforced views carry a root store";
}

test "managed tokenize is also view-based and allocation-free" {
    body = _tokenize_ir("rc", False);
    assert "s.view" in body , "managed tokens are not slice views";
    assert "__rc_alloc" not in body , "managed tokenize allocates per token";
}
