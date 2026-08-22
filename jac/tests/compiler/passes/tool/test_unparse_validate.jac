"""Unparse validation tests – migrated from test_unparse_validate.py.

Tests that Jac files can be unparsed consistently.
Parametrized roundtrip tests are in tests/compiler/test_micro_suite.jac.
"""

import os;
import from difflib { unified_diff }
import from tests.support { JAC_ROOT }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.tool.jac_formatter_pass { format_module }
import from jaclang.compiler.passes.tool.unparse_pass { unparse_module, unparse_node }

glob LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "double unparse" {
    code_gen_pure = JacProgram().compile(os.path.join(LANG_FIXTURES, "circle.jac"));
    x = unparse_module(code_gen_pure);
    y = unparse_module(code_gen_pure);
    assert x == y , "Double unparse produced different results:\n"
        + "\n".join(unified_diff(x.splitlines(), y.splitlines()));
}

test "filter compr unparses to bracket syntax" {
    code_gen = JacProgram().compile(
        use_str='with entry { x[?:Foo, a==5]; }', file_path="t.jac"
    );
    unparsed = unparse_module(code_gen);
    assert "[?" in unparsed , "Filter compr should unparse as [?:...] but got: "
        + unparsed;
    assert "(?" not in unparsed , "Removed (?:...) syntax should not appear in unparsed output: "
        + unparsed;
}

test "bracket filter unparse roundtrip" {
    code_gen = JacProgram().compile(
        use_str='with entry { x[?:Foo, a==5]; }', file_path="t.jac"
    );
    first = unparse_module(code_gen);
    code_gen2 = JacProgram().compile(use_str=first, file_path="t.jac");
    second = unparse_module(code_gen2);
    assert first == second , "Bracket filter unparse roundtrip failed:\n"
        + "\n".join(unified_diff(first.splitlines(), second.splitlines()));
}

test "typed enum base unparse roundtrip" {
    # `enum X: T { ... }` shorthand must round-trip through unparse.
    src = "enum Color: int { RED=0, GREEN=1 } enum Tag: str { OPEN='open' }";
    first = unparse_module(JacProgram().compile(use_str=src, file_path="t.jac"));
    second = unparse_module(JacProgram().compile(use_str=first, file_path="t.jac"));
    assert first == second , "Typed enum unparse roundtrip failed:\n"
        + "\n".join(unified_diff(first.splitlines(), second.splitlines()));
    assert ": int" in first , (
        "Unparse should emit the `: T` shorthand, not the parenthesized " "form; got:\n"
        + first
    );
    assert ": str" in first , (
        "Unparse should emit the `: str` shorthand; got:\n" + first
    );
}

test "the tooling printers keep the surface Module.unparse/format had" {
    # `Module.unparse`/`Module.format`/`UniNode.unparse` left the node types
    # so `unitree` can seal (they orchestrate tool passes and read `gen.jac`,
    # a `CodeGenTarget` field). The three behaviours they had have to survive
    # the move, and they are distinct: the formatted rendering, the raw
    # `UnparsePass` rendering, and the per-node rendering.
    src = "obj C { has x: int = 1; }\nwith entry { c = C(); }\n";
    mod = JacProgram().compile(use_str=src, file_path="t.jac");
    formatted = unparse_module(mod);
    assert formatted == format_module(mod) , (
        "requires_format=True must be exactly the formatter's rendering"
    );
    once = unparse_module(JacProgram().compile(use_str=formatted, file_path="t.jac"));
    twice = unparse_module(JacProgram().compile(use_str=once, file_path="t.jac"));
    assert once == twice , "formatted rendering does not settle:\n"
        + "\n".join(unified_diff(once.splitlines(), twice.splitlines()));
    raw = unparse_module(mod, requires_format=False);
    assert raw and raw != formatted , (
        "requires_format=False must be the UnparsePass rendering, not the "
        f"formatter's; got {raw!r}"
    );
}

test "unparse_node renders a sub-node the way Module rendering does" {
    src = "with entry { x = (1 + 2) * 3; }\n";
    mod = JacProgram().compile(use_str=src, file_path="t.jac");
    raw = unparse_module(mod, requires_format=False);
    assert "1 + 2" in raw , raw;
    exprs = mod.get_all_sub_nodes(uni.BinaryExpr);
    assert exprs , "fixture should contain binary expressions";
    for e in exprs {
        rendered = unparse_node(e);
        assert rendered , f"empty rendering for {type(e).__name__}";
        assert rendered in raw , f"{rendered!r} not found in {raw!r}";
    }
    toks = mod.get_all_sub_nodes(uni.Int);
    assert toks , "fixture should contain int tokens";
    for t in toks {
        assert unparse_node(t) == t.value;
    }
}
