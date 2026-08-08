"""GraphMend trap-lowering (validation guard) tests.

Assertions run against the generated Python source (the lowering target),
plus the detection tag table where source alone cannot distinguish "not
detected" from "detected but declined by the trap pass"."""
import ast;
import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "graphmend"
     );

"""Compile a source file and return its generated Python source."""
def _compile_path(path: str, gm: bool) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=path, options=CompileOptions(graphmend=gm, type_check=False)
    );
    pa = mod.gen.py_ast;
    mod_ast = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

"""Compile a checked-in .jac fixture and return its generated Python source."""
def _pysrc(name: str, gm: bool) -> str {
    return _compile_path(os.path.join(FIXTURES, name), gm);
}

"""Compile a fixture with graphmend on and count the detection tags recorded.

Observes detection directly (the side table survives the full compile), so a
guard the trap pass would decline anyway still cannot hide a mis-tag."""
def _break_count(name: str) -> int {
    prog = JacProgram();
    prog.compile(
        file_path=os.path.join(FIXTURES, name),
        options=CompileOptions(graphmend=True, type_check=False)
    );
    return len(prog.graphmend_breaks);
}

"""A Python-source model with a tensor-bool validation guard.

Written to a temp file at test time rather than checked in as a .py fixture:
the repository does not accept new Python files, and the point of the fixture
is only that GraphMend ingests .py source, which a generated file exercises
just as well."""
glob PY_VAL_GUARD_SRC = '''
import torch


@torch.compile()
def f(x, mask):
    x = torch.relu(x)
    if not mask.all():
        raise ValueError("mask must be all true")
    return torch.sin(x) * 2.0
''';

"""Compile the generated .py model above and return its Python lowering."""
def _py_fixture_src(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_val_guard.py");
        with open(path, "w") as fh {
            fh.write(PY_VAL_GUARD_SRC);
        }
        return _compile_path(path, gm);
    }
}

test "torch.equal guard lowers to the tensor-equality assert helper" {
    src = _pysrc("val_guard.jac", True);
    # The original ValueError type/message are folded into a trap marker so the
    # boundary @__jac_trap_guard__ decorator can restore them at the call site.
    assert (
        "__jac_tensor_eq_assert__(attention_mask, expected, "
        "'[[GM-TRAP ValueError]]unsupported attention mask[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    # helper imports are emitted and the raising branch is gone
    assert "import __jac_tensor_eq_assert__" in src;
    assert "raise ValueError" not in src;
    assert "if not torch.equal" not in src;
    assert _break_count("val_guard.jac") == 1;
}

test "tensor-bool guard lowers to torch._assert_async directly" {
    src = _pysrc("val_guard_all.jac", True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
    assert "if not mask.all()" not in src;
}

test "py source: validation guard lowers to torch._assert_async" {
    # The .py front-end (PyastBuildPass) produces UniIR whose nodes unparse
    # differently from .jac-origin nodes, so the trap pattern must match
    # structurally; this guards `jac run model.py --graphmend`.
    src = _py_fixture_src(True);
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
}

test "no transformation when graphmend disabled" {
    src = _pysrc("val_guard.jac", False);
    assert "__jac_tensor_eq_assert__(" not in src;
    assert "if not torch.equal(attention_mask, expected):" in src;
    assert "raise ValueError('unsupported attention mask')" in src;
    src = _py_fixture_src(False);
    assert "torch._assert_async(" not in src;
    assert "if not mask.all():" in src;
}

test "f-string guard message declines instead of dropping the diagnostic" {
    # MultiString.lit_value accumulates only String parts, so folding an
    # f-string into the trap marker would yield a well-formed marker wrapped
    # around an EMPTY message: right exception type, lost diagnostic, no signal.
    src = _pysrc("guard_fstring_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "if not mask.all()" in src;
    assert "raise ValueError(f'" in src;
    # The decline is the trap pass declining, not detection missing it; the two
    # scopes must stay distinguishable or a real detection regression could hide
    # behind this test.
    assert _break_count("guard_fstring_msg.jac") == 1;
}

test "runtime-expression guard message declines instead of losing the type" {
    # A concatenation is not a literal, so no marker can be built and the
    # boundary guard would have nothing to restore: lowering would surface the
    # failure as RuntimeError rather than the original ValueError.
    src = _pysrc("guard_dynamic_msg.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('bad mask in ' + name)" in src;
    assert _break_count("guard_dynamic_msg.jac") == 1;
}

test "guard in a compiled class declines for want of a call boundary" {
    # The archetype is an entry point, so the guard IS tagged, but no enclosing
    # ability carries the decorator: there is no compiled boundary at which the
    # trap guard could restore the exception, and the async assert may surface
    # after the method returns.
    src = _pysrc("guard_in_compiled_class.jac", True);
    assert "torch._assert_async(" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "raise ValueError('mask must be all true')" in src;
    assert _break_count("guard_in_compiled_class.jac") == 1;
}

test "static (non-tensor) guard is not rewritten" {
    # `if not isinstance(flag, str): raise` has no tensor-data dependence;
    # Dynamo traces it without a break, so GraphMend must leave it alone.
    src = _pysrc("static_guard.jac", True);
    assert "torch._assert_async(" not in src;
    assert "__jac_tensor_eq_assert__(" not in src;
    assert "if not isinstance(flag, str)" in src;
    assert "raise TypeError" in src;
    # rewrite absence alone would not prove precision: the trap pass would
    # decline this shape even if it were mis-tagged, so check the tag table
    assert _break_count("static_guard.jac") == 0;
}
