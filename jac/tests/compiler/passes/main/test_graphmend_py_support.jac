"""GraphMend on plain Python (.py) source files.

This is the primary target: `jac run model.py --graphmend`. The .py front-end
(PyastBuildPass) produces UniIR whose nodes unparse differently from .jac-origin
nodes, so detection/transform must match structurally (not via unparse text).
These tests guard that all three transformations fire on .py source.
"""
import ast;
import os;
import tempfile;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

"""Python model sources, written to temp files at test time rather than
checked in as .py fixtures: the repository does not accept new Python files,
and the point of each fixture is only that GraphMend ingests .py source,
which a generated file exercises just as well."""
glob PY_SRCS: dict[str, str] = {
    'py_val_guard.py': '''
import torch


@torch.compile()
def f(x, mask):
    x = torch.relu(x)
    if not mask.all():
        raise ValueError("mask must be all true")
    return torch.sin(x) * 2.0
''',
    'py_where_return.py': '''
import torch


@torch.compile()
def f(a, b):
    x = a / (torch.abs(a) + 1)
    if b.sum() < 0:
        return x * (b * -1)
    else:
        return x * (b * -2)
''',
    'py_side_effect.py': '''
import torch


@torch.compile()
def f(x):
    x = torch.relu(x)
    print(x)
    return torch.sin(x) * 2.0
''',
    'py_callsite_module.py': '''
import torch


class MyModel(torch.nn.Module):
    def forward(self, x):
        x = torch.relu(x)
        if x.sum() > 0:
            return x * 2.0
        else:
            return x * 3.0


model = MyModel()
compiled = torch.compile(model)
'''
};

"""Write a generated .py model to a temp file, compile it, and return its
generated Python source."""
def _pysrc(name: str, gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, name);
        with open(path, "w") as fh {
            fh.write(PY_SRCS[name]);
        }
        prog = JacProgram();
        mod = prog.compile(
            file_path=path,
            options=CompileOptions(graphmend=gm, type_check=False)
        );
        pa = mod.gen.py_ast;
        mod_ast = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

test "py: data-dependent control flow lowers to torch.where" {
    src = _pysrc("py_where_return.py", True);
    assert "return torch.where(" in src;
    assert "if b.sum() < 0" not in src;
}

test "py: print side effect is buffered and flushed" {
    src = _pysrc("py_side_effect.py", True);
    # Positional arg snapshotted (hoisted + cloned-if-tensor) at the call site.
    assert "__gm_se_arg_0 = x" in src;
    assert (
        "__jac_se_emit__(print, "
        "(__gm_se_arg_0.clone() if hasattr(__gm_se_arg_0, 'clone') "
        "else __gm_se_arg_0,), {})"
    )
        in src;
    assert "__jac_se_flush__()" in src;
}

test "py: validation guard lowers to torch._assert_async" {
    src = _pysrc("py_val_guard.py", True);
    # exception type/message folded into a trap marker + boundary guard decorator
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "@__jac_trap_guard__" in src;
    assert "raise ValueError" not in src;
}

test "py: no transformation when graphmend disabled" {
    src = _pysrc("py_where_return.py", False);
    assert "torch.where(" not in src;
    assert "if b.sum() < 0" in src;
}

test "py: torch.compile(model) call site tags the wrapped class methods" {
    # entry point is the call site, not a decorator; the undecorated forward
    # method's data-dependent branch must still be rewritten.
    src = _pysrc("py_callsite_module.py", True);
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

test "py: call-site wrapped model untouched when graphmend disabled" {
    src = _pysrc("py_callsite_module.py", False);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0" in src;
}
