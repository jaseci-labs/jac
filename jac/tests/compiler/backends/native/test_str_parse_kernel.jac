"""C6 gate (#7870): the zero-copy parse kernel's tokenize loop is
allocation-free per token in the enforced build -- tokens are slices of the
input, keyword compares run length-aware compares over descriptor parts
(`__jac_rt_str_cmp` on data and length), and nothing in the loop builds a
new string. The decision step's MIR is the witness. Behavioral identity
across modes rides the ownbench differential."""

import from pathlib { Path }
import from tests.support { KernelFixture, compile_mir }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob KERNEL = str(
         Path(__file__).resolve().parents[4]
             / "examples"
             / "ownbench"
             / "kernels"
             / "own_parse.jac"
     );

"""The MIR text of `name`'s function in a compiled fixture."""
def mir_function(fx: KernelFixture, name: str) -> str {
    head = f"fn @{fx.symbol(name)}(";
    for chunk in fx.mir().split("\n\n") {
        if chunk.startswith(head) {
            return chunk;
        }
    }
    raise AssertionError(f"no MIR function {name} in {fx.path}: demoted {fx.demoted()}");
}

def _tokenize_mir(gc_mode: str, enforce: bool) -> str {
    fx = compile_mir(
        KERNEL,
        "",
        CompileOptions(
            force_codespace="native",
            aot_mode=True,
            na_gc_mode=gc_mode,
            nogc_enforce_all=enforce
        )
    );
    assert not fx.is_demoted("tokenize") , str(fx.demoted());
    return mir_function(fx, "tokenize");
}

test "enforced tokenize loop allocates nothing per token" {
    body = _tokenize_mir("none", True);
    assert "@__jac_rt_alloc" not in body , "enforced tokenize still allocates";
    assert "@__jac_rt_str_new" not in body , "enforced tokenize copies tokens";
    assert "@__jac_rt_str_concat" not in body , "enforced tokenize builds strings";
    assert "@__jac_rt_str_cmp" in body , "keyword compares bypass descriptor parts";
}

test "managed tokenize is also view-based and allocation-free" {
    body = _tokenize_mir("rc", False);
    assert "@__jac_rt_alloc" not in body , "managed tokenize allocates per token";
    assert "@__jac_rt_str_new" not in body , "managed tokenize copies tokens";
}
