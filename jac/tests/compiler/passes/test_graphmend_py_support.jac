"""Entry-point resolution and claiming on plain Python source."""
import ast;
import os;
import tempfile;
import from tests.support { GRAPHMEND_FIXTURES as FIXTURES }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

"""A Python model wrapped at a call site through a variable, written to a temp
file at test time rather than checked in as a .py fixture: the repository does
not accept new Python files, and the point of the fixture is only that
GraphMend ingests .py source, which a generated file exercises just as well."""
glob PY_CALLSITE_SRC = '''
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
''';

"""Write the generated .py model to a temp file, compile it, and return its
generated Python source."""
def _pysrc(gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "py_callsite_module.py");
        with open(path, "w") as fh {
            fh.write(PY_CALLSITE_SRC);
        }
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=CompileOptions(graphmend=gm));
        pa = mod.gen.py_ast;
        mod_ast: any = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

"""Compile a checked-in fixture and return its generated Python source."""
def _fixture_src(name: str) -> str {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, name), options=CompileOptions(graphmend=True)
    );
    pa = mod.gen.py_ast;
    mod_ast: any = pa[0] if isinstance(pa, list) else pa;
    return ast.unparse(mod_ast);
}

test "py: torch.compile(model) call site tags the wrapped class methods" {
    # The entry point is the call site (resolved through `model = MyModel()`),
    # not a decorator; the undecorated forward method's data-dependent branch
    # must still be rewritten.
    src = _pysrc(True);
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

test "py: call-site wrapped model untouched when graphmend disabled" {
    src = _pysrc(False);
    assert "torch.where(" not in src;
    assert "if x.sum() > 0" in src;
}

test "a helper defers to the caller's region instead of flushing" {
    # Dynamo inlines the helper into the decorated entry's graph, so the
    # reachability closure covers it: the helper's print buffers and only the
    # entry drains it. A flush at the helper's return would split the graph
    # from the inside.
    src = _fixture_src("se_in_helper.jac");
    # the helper buffers...
    assert "__jac_se_emit__(print," in src;
    # ...but emits NO flush of its own -- that would split the caller's graph
    assert "__jac_se_flush__()" not in src;
    # ...and the compiled entry carries the guard that drains it, even though
    # the entry holds no side-effect call itself.
    assert "@__jac_se_guard__" in src;
    assert src.index("@__jac_se_guard__") < src.index("@torch.compile");
}

"""Compile a generated .py the way an imported model module is compiled: no
local torch.compile, seeded by its proven Module forwards."""
def _py_model_src(py_src: str, name: str) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, name);
        with open(path, "w") as fh {
            fh.write(py_src);
        }
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=CompileOptions(graphmend=True));
        pa = mod.gen.py_ast;
        mod_ast: any = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

glob PY_MODEL_GUARD_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, mask: torch.Tensor):
        x = torch.relu(x)
        if not mask.all():
            raise ValueError("mask must be all true")
        return torch.sin(x)
''',
     PY_WRAPPED_GUARD_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x, mask: torch.Tensor):
        x = torch.relu(x)
        if not mask.all():
            raise ValueError("mask must be all true")
        return torch.sin(x)


model = torch.compile(Net())
''';

test "a validation guard with no boundary in reach is declined" {
    # No decorated function and no call-site wrap, so nothing would decode the
    # marker.
    src = _py_model_src(PY_MODEL_GUARD_SRC, "model_guard.py");
    assert "torch._assert_async(" not in src;
    assert "raise ValueError('mask must be all true')" in src;
}

test "a validation guard lowers behind the call-site wrap boundary" {
    # The boundary is the call site, not the method: a decorator on `forward`
    # would sit inside the compiled callable and never see the async assert.
    src = _py_model_src(PY_WRAPPED_GUARD_SRC, "wrapped_guard.py");
    assert (
        "torch._assert_async(mask.all(), "
        "'[[GM-TRAP ValueError]]mask must be all true[[/GM-TRAP]]')"
        in src
    );
    assert "raise ValueError" not in src;
    assert "@__jac_trap_guard__" not in src;
    assert "model = __jac_trap_guard__(model)" in src;
}

glob PY_ENTRY_WRAP_SRC = '''
import torch


class Net(torch.nn.Module):
    def forward(self, x):
        return torch.relu(x)


model = torch.compile(Net())
''';

test "the entry wrap gets the trap boundary attach" {
    # Every torch.compile call-site assignment gets the boundary attached; for
    # a torch Module the runtime wraps `forward` in place, so an async assert
    # failure from any guard the compiled call reaches is restored to its
    # original exception at the outermost eager frame.
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, "entry_wrap.py");
        with open(path, "w") as fh {
            fh.write(PY_ENTRY_WRAP_SRC);
        }
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=CompileOptions(graphmend=True));
        pa = mod.gen.py_ast;
        mod_ast: any = pa[0] if isinstance(pa, list) else pa;
        src = ast.unparse(mod_ast);
    }
    assert "model = __jac_trap_guard__(model)" in src;
    # the helper import must be emitted by the preamble
    assert any(
        [
            ("from jaclang" in line) and ("__jac_trap_guard__" in line)
            for line in src.splitlines()
        ]
    );
}

"""A discriminant validation guard from a real model file (Apache-2.0),
vendored against upstream drift. The message is a literal because formatting a
tensor inside the graph would itself force a break."""
glob PY_DISCRIMINANT_GUARD_SRC = '''
import torch


def rational_quadratic_spline_root(a: torch.Tensor, b: torch.Tensor, c: torch.Tensor):
    discriminant = b.pow(2) - 4 * a * c
    if not (discriminant >= 0).all():
        raise RuntimeError("invalid discriminant in rational quadratic spline")
    return (2 * c) / (-b - torch.sqrt(discriminant))


class Spline(torch.nn.Module):
    def forward(self, a, b, c):
        return rational_quadratic_spline_root(a, b, c)


model = torch.compile(Spline())
''',
     PY_DISCRIMINANT_GUARD_FSTRING_SRC = '''
import torch


def rational_quadratic_spline_root(a: torch.Tensor, b: torch.Tensor, c: torch.Tensor):
    discriminant = b.pow(2) - 4 * a * c
    if not (discriminant >= 0).all():
        raise RuntimeError(f"invalid discriminant {discriminant}")
    return (2 * c) / (-b - torch.sqrt(discriminant))


class Spline(torch.nn.Module):
    def forward(self, a, b, c):
        return rational_quadratic_spline_root(a, b, c)


model = torch.compile(Spline())
''';

test "the real discriminant guard shape lowers under a literal message" {
    src = _py_model_src(PY_DISCRIMINANT_GUARD_SRC, "discriminant_guard.py");
    assert (
        "torch._assert_async((discriminant >= 0).all(), "
        "'[[GM-TRAP RuntimeError]]invalid discriminant in rational quadratic "
        "spline[[/GM-TRAP]]')"
        in src
    );
    assert "if not (discriminant >= 0).all():" not in src;
}

test "a guard with a non-literal message is declined" {
    # The verbatim upstream form carries an f-string message; folding it into
    # the assert would evaluate the tensor format on every call inside the
    # graph, so the lowering declines and the break is left intact.
    src = _py_model_src(
        PY_DISCRIMINANT_GUARD_FSTRING_SRC, "discriminant_guard_fstring.py"
    );
    assert "torch._assert_async(" not in src;
    assert "if not (discriminant >= 0).all():" in src;
}

glob PY_MODEL_MIXED_SRC = '''
import torch


def reachable_helper(x):
    print("IN-HELPER", x)
    return x * 2


def unreachable_util(x):
    print("UTIL", x)
    if x.sum() > 0:
        y = x * 2
    else:
        y = x * 3
    return y


class Net(torch.nn.Module):
    def forward(self, x):
        return reachable_helper(torch.relu(x))
''';

test "only forward-reachable code is transformed" {
    # The compiled region is the reachability closure over the call graph
    # (what Dynamo would inline), not the whole module: a utility no forward
    # reaches keeps its print and its data-dependent branch untouched.
    src = _py_model_src(PY_MODEL_MIXED_SRC, "model_mixed.py");
    assert "__jac_se_emit__(print," in src;
    assert "print('UTIL', x)" in src;
    assert "torch.where(" not in src;
}

"""The decorated forward is replaced at class-definition time by the
decorator's `wrapper` closure, so the closure, not the decorated body, is what
runs under torch.compile."""
glob PY_MODEL_DECORATOR_SRC = '''
import torch
from functools import wraps


def dynamic_update(rope_forward):

    @wraps(rope_forward)
    def wrapper(self, x):
        if x.sum() > 0:
            y = x * 2.0
        else:
            y = x * 3.0
        return rope_forward(self, y)
    return wrapper


class Net(torch.nn.Module):
    @dynamic_update
    def forward(self, x):
        return torch.relu(x)
''';

test "a decorator's wrapper closure is analyzed and transformed" {
    # The module has a forward, so the whole-module fallback stays off and the
    # closure is reachable ONLY through the decorator edge: forward's decorator
    # resolves to `dynamic_update`, whose nested closures join the region.
    src = _py_model_src(PY_MODEL_DECORATOR_SRC, "model_decorator.py");
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

"""The wrapper calls a SIBLING closure that holds the break; resolving it
needs lexical scope, since a module-level lookup cannot see it."""
glob PY_MODEL_SIBLING_SRC = '''
import torch


def dynamic_update(rope_forward):

    def frequency_update(self, x):
        if x.sum() > 0:
            y = x * 2.0
        else:
            y = x * 3.0
        return y

    def wrapper(self, x):
        x = frequency_update(self, x)
        return rope_forward(self, x)
    return wrapper


class Net(torch.nn.Module):
    @dynamic_update
    def forward(self, x):
        return torch.relu(x)
''';

test "a wrapper's sibling closure is reached through lexical scope" {
    # Only `wrapper` is enqueued from the decorator (it is the one that invokes
    # the decorated function); the break lives one call deeper in a sibling
    # closure, which resolves only by walking enclosing function scopes.
    src = _py_model_src(PY_MODEL_SIBLING_SRC, "model_sibling.py");
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

"""A decorator that rewrites metadata and returns the ORIGINAL function: its
body runs once at decoration time, never inside the graph."""
glob PY_MODEL_METADATA_DECO_SRC = '''
import torch


def describe(fn):
    print('DESCRIBING')
    fn.__doc__ = build_doc(fn)
    return fn


def build_doc(fn):
    print('BUILDING', fn.__name__)
    return 'doc'


class Net(torch.nn.Module):
    @describe
    def forward(self, x):
        return torch.relu(x)
''';

test "a metadata decorator's helpers stay out of the region" {
    # `describe` never invokes the decorated function -- it returns it -- so it
    # is not a call-time wrapper and neither it nor `build_doc` runs inside the
    # graph. Deferring their prints would replay import-time output at the
    # first forward.
    src = _py_model_src(PY_MODEL_METADATA_DECO_SRC, "model_metadata_deco.py");
    assert "__jac_se_emit__(" not in src;
    assert "print('DESCRIBING')" in src;
    assert "print('BUILDING', fn.__name__)" in src;
}

glob PY_MODEL_DECO_NOISY_SRC = '''
import torch


def noisy_decorator(fn):
    print('DECORATING', fn.__name__)

    def wrapper(self, x):
        print('CALLING', x)
        return fn(self, x)
    return wrapper


class Net(torch.nn.Module):
    @noisy_decorator
    def forward(self, x):
        return torch.relu(x)
''';

test "decoration-time code stays out of the compiled region" {
    # Only the decorator's closures run under the compiled graph; the
    # decorator's own body runs once at class-definition time, so deferring
    # its side effects would replay them at the wrong moment. The closure's
    # runtime print buffers, the decoration-time print must stay eager.
    src = _py_model_src(PY_MODEL_DECO_NOISY_SRC, "model_deco_noisy.py");
    assert "__jac_se_emit__(print," in src;
    assert "print('DECORATING', fn.__name__)" in src;
}

"""Write a generated .py source to a temp file and compile it in entry-file
mode (no scope): the region comes from the local torch.compile entries."""
def _py_entry_src(py_src: str, name: str) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, name);
        with open(path, "w") as fh {
            fh.write(py_src);
        }
        prog = JacProgram();
        mod = prog.compile(file_path=path, options=CompileOptions(graphmend=True));
        pa = mod.gen.py_ast;
        mod_ast: any = pa[0] if isinstance(pa, list) else pa;
        return ast.unparse(mod_ast);
    }
}

glob PY_ENTRY_DECORATOR_SRC = '''
import torch


def logging_wrap(fn):

    def wrapper(x):
        if x.sum() > 0:
            y = x * 2.0
        else:
            y = x * 3.0
        return fn(y)
    return wrapper


@torch.compile
@logging_wrap
def entry(x):
    return torch.relu(x)
''';

test "entry-file: a stacked decorator's closure is analyzed and transformed" {
    # `torch.compile` receives `logging_wrap(entry)`, i.e. the closure, so the
    # closure is the compiled code. The decorated entry is the seed and the
    # decorator edge pulls `wrapper` into the region without any scope flag.
    src = _py_entry_src(PY_ENTRY_DECORATOR_SRC, "entry_decorator.py");
    assert "torch.where(" in src;
    assert "if x.sum() > 0" not in src;
}

"""An init behind an existence guard calls a function whose body calls its OWN
nested helper; the purity proof must resolve that helper lexically, and one
unresolvable callee declines the merge."""
glob PY_MODEL_NESTED_PURITY_SRC = '''
import torch


def compute_inv(v):

    def clamp01(s):
        if s <= 0:
            return 0.0
        return s
    return clamp01(v) + 1.0


class Net(torch.nn.Module):
    def forward(self, x, position_ids, limit):
        seq_len = torch.max(position_ids) + 1
        if seq_len > limit:
            if not hasattr(self, "long_state"):
                self.long_state = compute_inv(2.0)
            self.register_buffer("state", self.long_state)
        else:
            self.register_buffer("state", self.base_state)
        return torch.relu(x)
''';

test "a candidate's nested helper resolves in the purity proof" {
    # The tag on the outer branch is only useful if the transform CONSUMES it:
    # the setup's init calls compute_inv, whose nested clamp01 must resolve
    # lexically for the body to prove pure and the common call to merge.
    src = _py_model_src(PY_MODEL_NESTED_PURITY_SRC, "model_nested_purity.py");
    assert "torch.where(" in src;
    assert "if seq_len > limit" not in src;
}
