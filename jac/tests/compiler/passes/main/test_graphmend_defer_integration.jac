"""Torch-gated: deferral collapses the split forward pass back to one FX graph."""
import builtins;
import contextlib;
import io;
import logging;
import os;
import tempfile;
import from tests.support {
    GRAPHMEND_FIXTURES as FIXTURES,
    graphmend_compile_path as _compile_path
}

"""nn.Module logger models, written to temp files at test time rather than
checked in as .py fixtures: the repository does not accept new Python files.
The logger call sits inside `forward` (a traced region) and the model is
wrapped at a call site (`model = torch.compile(Net())`), so the slot-registry
mechanism plus the injected forward hooks are what preserve the log."""
glob PY_FORWARD_HOOK_SRC = '''
import logging

import torch

logger = logging.getLogger("gm_forward_hook")


class Net(torch.nn.Module):
    def forward(self, x):
        x = torch.relu(x)
        logger.warning("GM-FORWARD-HOOK-LOG")
        return torch.sin(x) * 2.0


model = torch.compile(Net())
''',
     PY_FORWARD_HOOK_RAISES_SRC = '''
import logging

import torch

logger = logging.getLogger("gm_forward_hook_raises")


class Net(torch.nn.Module):
    def forward(self, x):
        x = torch.relu(x)
        logger.warning("GM-RAISING-FORWARD-LOG")
        raise ValueError("GM-BOOM")


model = torch.compile(Net())
''';

"""Import torch or skip the calling test."""
def _torch -> any {
    try {
        import torch;
        return torch;
    } except ImportError {
        testskip("torch not installed");
    }
}

"""Compile a generated .py model source and return its Python lowering."""
def _py_model_src(py_src: str, name: str, gm: bool) -> str {
    with tempfile.TemporaryDirectory() as tmp {
        path = os.path.join(tmp, name);
        with open(path, "w") as fh {
            fh.write(py_src);
        }
        return _compile_path(path, gm);
    }
}

"""Exec generated Python with @torch.compile rebound to identity, so the
caller can drive the raw function/model through a backend itself."""
def _exec_src(src: str, label: str) -> dict {
    torch = _torch();
    ns: dict = {};
    orig_compile = torch.compile;
    def _shim(*a: any, **k: any) -> any {
        if a {
            return a[0];
        }
        def _wrap(f: any) -> any {
            return f;
        }
        return _wrap;
    }
    torch.compile = _shim;
    try {
        exec(compile(src, label, "exec"), ns);
    } finally {
        torch.compile = orig_compile;
    }
    return ns;
}

"""Count the contiguous graphs the backend receives for one call of `target`."""
def _count_graphs_of(target: any, args: tuple) -> int {
    torch = _torch();
    graphs: list = [];
    def _backend(gm: any, inputs: any) -> any {
        graphs.append(gm);
        return gm.forward;
    }
    torch._dynamo.reset();
    torch.compile(target, backend=_backend)(*args);
    return len(graphs);
}

"""Compile a .jac fixture, exec it, and count graphs for one call of fn_name."""
def _count_graphs(fixture: str, gm: bool, fn_name: str, args: tuple) -> int {
    src = _compile_path(os.path.join(FIXTURES, fixture), gm);
    ns = _exec_src(src, fixture);
    return _count_graphs_of(ns[fn_name], args);
}

test "side-effect calls defragment to one contiguous graph" {
    # side_effect.jac doubles as the guard-cost check: the prepended
    # @__jac_se_guard__ boundary must not itself split the graph.
    torch = _torch();
    x = torch.tensor([1.0, 2.0, 3.0]);
    for fixture in [
        "side_effect.jac",
        "side_effect_logger.jac",
        "side_effect_clone.jac"
    ] {
        orig = _count_graphs(fixture, False, "f", (x, ));
        fixed = _count_graphs(fixture, True, "f", (x, ));
        assert orig >= 2 , f"{fixture}: expected >=2 graphs without GraphMend, got {orig}";
        assert fixed == 1 , f"{fixture}: expected 1 graph with GraphMend, got {fixed}";
    }
}

test "buffered arg is snapshotted against later in-place mutation" {
    # relu([1,2,3]) = [1,2,3]; the fixture then adds 100 in place. The clone at
    # the call site means the flushed print still reports the pre-mutation
    # value, not [101,102,103].
    torch = _torch();
    src = _compile_path(os.path.join(FIXTURES, "side_effect_clone.jac"), True);
    ns = _exec_src(src, "side_effect_clone.jac");
    buf = io.StringIO();
    torch._dynamo.reset();
    with contextlib.redirect_stdout(buf) {
        _count_graphs_of(ns["f"], (torch.tensor([1.0, 2.0, 3.0]), ));
    }
    out = buf.getvalue();
    assert "snap:" in out , f"deferred print did not run: {repr(out)}";
    assert "101" not in out , f"deferred print saw the post-mutation value: {repr(
        out
    )}";
    assert "1., 2., 3." in out , f"deferred print lost the snapshot value: {repr(out)}";
}

test "deferred print flushes on the exceptional exit" {
    # Deferral moves WHEN the print is emitted; an exit that never reaches the
    # in-function flush would lose it. The @__jac_se_guard__ boundary sits above
    # @torch.compile, so its finally runs on the raising path too.
    torch = _torch();
    def _run(gm: bool) -> tuple {
        src = _compile_path(os.path.join(FIXTURES, "side_effect_raises.jac"), gm);
        ns = _exec_src(src, "side_effect_raises.jac");
        printed: list = [];
        real_print = builtins.print;
        def _capture(*a: any, **k: any) {
            printed.append(" ".join([str(v) for v in a]));
        }
        builtins.print = _capture;
        caught: any = None;
        try {
            torch._dynamo.reset();
            try {
                ns["f"](torch.tensor([1.0, 2.0]));
            } except Exception as exc {
                caught = exc;
            }
        } finally {
            builtins.print = real_print;
        }
        return (printed, caught);
    }
    (orig_out, orig_exc) = _run(False);
    assert any(["GM-SE-BEFORE-RAISE" in line for line in orig_out]);
    assert isinstance(orig_exc, ValueError) and ("GM-SE-BOOM" in str(orig_exc));
    (fixed_out, fixed_exc) = _run(True);
    assert isinstance(fixed_exc, ValueError) , f"expected ValueError, got {repr(
        fixed_exc
    )}";
    assert "GM-SE-BOOM" in str(fixed_exc);
    assert any(["GM-SE-BEFORE-RAISE" in line for line in fixed_out]) , (
        "deferred print was lost on the exceptional exit -- the __jac_se_guard__ "
        "boundary must flush the global buffer in its finally"
    );
}

"""Run a generated logger model; return (graph_count, captured log messages)."""
def _run_model(py_src: str, name: str, logger_name: str, gm: bool) -> tuple {
    torch = _torch();
    src = _py_model_src(py_src, name, gm);
    ns = _exec_src(src, name);
    messages: list = [];
    class _Capture(logging.Handler) {
        def emit(self: any, record: any) {
            messages.append(record.getMessage());
        }
    }
    handler = _Capture();
    logging.getLogger(logger_name).addHandler(handler);
    try {
        count = _count_graphs_of(ns["model"], (torch.tensor([1.0, 2.0, 3.0]), ));
    } finally {
        logging.getLogger(logger_name).removeHandler(handler);
    }
    return (count, messages);
}

test "logger forward hook defragments and preserves the log" {
    _torch();
    (orig_graphs, orig_msgs) = _run_model(
        PY_FORWARD_HOOK_SRC, "logger_forward_hook.py", "gm_forward_hook", False
    );
    (fixed_graphs, fixed_msgs) = _run_model(
        PY_FORWARD_HOOK_SRC, "logger_forward_hook.py", "gm_forward_hook", True
    );
    assert orig_graphs >= 2 , f"expected a break without GraphMend, got {orig_graphs}";
    assert fixed_graphs == 1 , f"expected one graph with GraphMend, got {fixed_graphs}";
    # The log is preserved: replayed by the injected forward hook after the graph.
    assert "GM-FORWARD-HOOK-LOG" in fixed_msgs , "logger output was lost";
    assert "GM-FORWARD-HOOK-LOG" in orig_msgs;
}

test "the flush hook is registered with always_call=True" {
    # Without it the flush runs only on a successful forward, so a raising
    # forward drops every buffered logger call. Asserted on the generated source
    # so the guarantee is visible even where torch's hook semantics are not
    # exercised.
    _torch();
    src = _py_model_src(PY_FORWARD_HOOK_SRC, "logger_forward_hook.py", True);
    assert "register_forward_hook(__jac_log_flush_hook__, always_call=True)" in src;
    # The registrations are guarded: a call-site wrap of a plain function has
    # no hook methods, so unguarded registration would crash the import.
    assert "if hasattr(model, 'register_forward_pre_hook'):" in src;
}

test "a function wrapped at a call site does not crash on hook injection" {
    # `fast = torch.compile(fn)` is a legitimate entry shape; the injected hook
    # registrations must be hasattr-guarded because a compiled function has no
    # register_forward_pre_hook. The buffered print falls back to immediate
    # emission (region depth 0: no guard opens a region for this shape).
    torch = _torch();
    py_src = '''
import torch


def fn(x):
    x = torch.relu(x)
    print("GM-FN-WRAP-PRINT")
    return torch.sin(x)


fast = torch.compile(fn)
''';
    src = _py_model_src(py_src, "fn_wrap.py", True);
    ns = _exec_src(src, "fn_wrap.py");
    printed: list = [];
    real_print = builtins.print;
    def _capture(*a: any, **k: any) {
        printed.append(" ".join([str(v) for v in a]));
    }
    builtins.print = _capture;
    try {
        out = ns["fast"](torch.tensor([1.0, 2.0]));
    } finally {
        builtins.print = real_print;
    }
    assert any(["GM-FN-WRAP-PRINT" in line for line in printed]) , (
        "print output was lost for a call-site-wrapped function"
    );
    assert out is not None;
}

test "deferred logger flushes when the forward raises" {
    # A plain forward hook only runs on a successful return; always_call=True is
    # what replays the buffered log before the exception propagates.
    torch = _torch();
    def _run(gm: bool) -> tuple {
        src = _py_model_src(
            PY_FORWARD_HOOK_RAISES_SRC, "logger_forward_hook_raises.py", gm
        );
        ns = _exec_src(src, "logger_forward_hook_raises.py");
        messages: list = [];
        class _Capture(logging.Handler) {
            def emit(self: any, record: any) {
                messages.append(record.getMessage());
            }
        }
        handler = _Capture();
        logging.getLogger("gm_forward_hook_raises").addHandler(handler);
        caught: any = None;
        try {
            torch._dynamo.reset();
            try {
                torch.compile(ns["model"], backend="eager")(torch.tensor([1.0, 2.0]));
            } except Exception as exc {
                caught = exc;
            }
        } finally {
            logging.getLogger("gm_forward_hook_raises").removeHandler(handler);
        }
        return (messages, caught);
    }
    (orig_msgs, orig_exc) = _run(False);
    assert "GM-RAISING-FORWARD-LOG" in orig_msgs;
    assert isinstance(orig_exc, ValueError) and ("GM-BOOM" in str(orig_exc));
    (fixed_msgs, fixed_exc) = _run(True);
    assert isinstance(fixed_exc, ValueError) , f"expected ValueError, got {repr(
        fixed_exc
    )}";
    assert "GM-BOOM" in str(fixed_exc);
    assert "GM-RAISING-FORWARD-LOG" in fixed_msgs , (
        "deferred logger output was lost on the exceptional exit -- the flush "
        "hook must be registered with always_call=True"
    );
}
