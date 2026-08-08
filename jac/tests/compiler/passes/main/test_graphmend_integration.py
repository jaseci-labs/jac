"""Torch-gated integration tests for GraphMend [Defer] and --graphmend-scope.

Confirm the *runtime* claim that the transformations defragment the FX graph:
compile each fixture with and without ``--graphmend`` and count how many
contiguous graphs TorchDynamo's backend actually receives. This is the paper's
metric -- a side-effect call splits the forward pass into multiple graphs;
GraphMend collapses it back to one. The trap and predication integration tests
live in ``test_graphmend_trap_integration.jac`` and
``test_graphmend_where_integration.jac``.

Graph count (via a counting backend) is used rather than
``explain().graph_break_count`` (which under-reports for small functions) or
``fullgraph=True`` (which is stricter than how models actually run -- it rejects
the harmless *trailing* break left by the side-effect epilogue flush even though
the expensive compute is a single contiguous graph).

Skipped automatically when PyTorch is not installed.
"""

import ast
import logging
import os
import sys
from pathlib import Path

import pytest

torch = pytest.importorskip("torch")

from jaclang.jac0core.compile_options import CompileOptions  # noqa: E402
from jaclang.jac0core.program import JacProgram  # noqa: E402

pytestmark = pytest.mark.filterwarnings("ignore")

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures", "graphmend")


def _compile_src(fixture: str, graphmend: bool) -> str:
    prog = JacProgram()
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, fixture),
        options=CompileOptions(graphmend=graphmend, type_check=False),
    )
    py = mod.gen.py_ast
    py = py[0] if isinstance(py, list) else py
    return ast.unparse(py)


def _count_graphs(fixture: str, graphmend: bool, fn_name: str, *args: object) -> int:
    """Compile a fixture and count the contiguous graphs the backend receives.

    ``@torch.compile`` is neutralized to an identity decorator so the rewritten
    body is what we drive through a counting backend ourselves.
    """
    src = _compile_src(fixture, graphmend)
    ns: dict = {}
    orig_compile = torch.compile
    torch.compile = lambda *a, **k: a[0] if a else (lambda f: f)
    try:
        exec(compile(src, fixture, "exec"), ns)
    finally:
        torch.compile = orig_compile

    graphs: list = []

    def backend(gm: object, inputs: object) -> object:
        graphs.append(gm)
        return gm.forward  # type: ignore[attr-defined]

    torch._dynamo.reset()
    torch.compile(ns[fn_name], backend=backend)(*args)
    return len(graphs)


def _assert_defragmented(fixture: str, fn_name: str, *args: object) -> None:
    orig = _count_graphs(fixture, False, fn_name, *args)
    fixed = _count_graphs(fixture, True, fn_name, *args)
    assert orig >= 2, (
        f"{fixture}: expected a fragmented graph (>=2) without GraphMend, got {orig}"
    )
    assert fixed == 1, (
        f"{fixture}: expected one contiguous graph with GraphMend, got {fixed}"
    )


def test_print_side_effect_defragmented():
    x = torch.tensor([1.0, 2.0, 3.0])
    _assert_defragmented("side_effect.jac", "f", x)


def test_logger_side_effect_defragmented():
    x = torch.tensor([1.0, 2.0, 3.0])
    _assert_defragmented("side_effect_logger.jac", "f", x)


def test_print_side_effect_defragmented_with_clone():
    """The snapshot-clone of a buffered arg must not reintroduce a graph break."""
    x = torch.tensor([1.0, 2.0, 3.0])
    _assert_defragmented("side_effect_clone.jac", "f", x)


def _run_fixture_capturing_stdout(fixture: str, fn_name: str, *args: object) -> str:
    """Compile a fixture with GraphMend, drive it through a counting backend, and
    return everything written to stdout by the deferred-side-effect flush."""
    import contextlib
    import io

    src = _compile_src(fixture, True)
    ns: dict = {}
    orig_compile = torch.compile
    torch.compile = lambda *a, **k: a[0] if a else (lambda f: f)
    try:
        exec(compile(src, fixture, "exec"), ns)
    finally:
        torch.compile = orig_compile

    def backend(gm: object, inputs: object) -> object:
        return gm.forward  # type: ignore[attr-defined]

    buf = io.StringIO()
    torch._dynamo.reset()
    with contextlib.redirect_stdout(buf):
        torch.compile(ns[fn_name], backend=backend)(*args)
    return buf.getvalue()


def test_buffered_arg_is_snapshotted_against_later_mutation():
    """The buffered tensor is mutated in place after the print; the deferred
    output must show the pre-mutation snapshot, not the mutated value.

    relu([1,2,3]) = [1,2,3]; an in-place add of 100 would make it [101,102,103].
    The clone at the call site means the flushed print still reports [1,2,3].
    """
    x = torch.tensor([1.0, 2.0, 3.0])
    out = _run_fixture_capturing_stdout("side_effect_clone.jac", "f", x)
    assert "snap:" in out, f"deferred print did not run: {out!r}"
    assert "101" not in out, f"deferred print saw the post-mutation value: {out!r}"
    assert "1., 2., 3." in out, f"deferred print lost the snapshot value: {out!r}"


def _run_model_fixture(graphmend: bool) -> tuple[int, list]:
    """Compile the forward-hook fixture, build the model, and drive it through a
    counting backend. Returns (graph_count, captured_log_messages).

    ``torch.compile`` is neutralized so the module-level ``model = torch.compile(
    Net())`` yields the raw ``Net`` (with the GraphMend-injected forward hook
    still attached); we then drive that model object ourselves.
    """
    src = _compile_src("logger_forward_hook.py", graphmend)
    ns: dict = {}
    orig_compile = torch.compile
    torch.compile = lambda *a, **k: a[0] if a else (lambda f: f)
    try:
        exec(compile(src, "logger_forward_hook.py", "exec"), ns)
    finally:
        torch.compile = orig_compile

    messages: list = []

    class _Capture(logging.Handler):
        def emit(self, record: object) -> None:
            messages.append(record.getMessage())  # type: ignore[attr-defined]

    handler = _Capture()
    logging.getLogger("gm_forward_hook").addHandler(handler)
    graphs: list = []

    def backend(gm: object, inputs: object) -> object:
        graphs.append(gm)
        return gm.forward  # type: ignore[attr-defined]

    try:
        torch._dynamo.reset()
        torch.compile(ns["model"], backend=backend)(torch.tensor([1.0, 2.0, 3.0]))
    finally:
        logging.getLogger("gm_forward_hook").removeHandler(handler)
    return len(graphs), messages


def test_logger_forward_hook_defragments_and_preserves_log() -> None:
    """The forward-hook mechanism eliminates the logger break AND emits the log."""
    orig_graphs, orig_msgs = _run_model_fixture(False)
    fixed_graphs, fixed_msgs = _run_model_fixture(True)

    assert orig_graphs >= 2, f"expected a break without GraphMend, got {orig_graphs}"
    assert fixed_graphs == 1, f"expected one graph with GraphMend, got {fixed_graphs}"
    # The log is preserved -- replayed by the injected forward hook after the graph.
    assert "GM-FORWARD-HOOK-LOG" in fixed_msgs, "logger output was lost"
    assert "GM-FORWARD-HOOK-LOG" in orig_msgs


def test_scoped_import_transforms_imported_model(tmp_path: Path) -> None:
    """--graphmend-scope routes an imported model package's .py through GraphMend.

    The model class lives in an imported module with no local torch.compile (the
    wrap is in the entry script) -- it is reached only because its package is in
    the graphmend scope. torch (not in scope) must stay untouched.
    """
    import dis
    import importlib

    from jaclang.jac0core.runtime import JacRuntime as Jac

    pkg = tmp_path / "scopedmodel"
    pkg.mkdir()
    (pkg / "__init__.py").write_text("")
    (pkg / "net.py").write_text(
        "import torch\n"
        "class Net(torch.nn.Module):\n"
        "    def forward(self, x):\n"
        "        x = torch.relu(x)\n"
        "        if x.sum() > 0:\n"
        "            return x * 2.0\n"
        "        else:\n"
        "            return x * 3.0\n"
    )
    prog = Jac.get_program()
    saved_en = prog.graphmend_enabled
    saved_scope = prog.graphmend_scope
    sys.path.insert(0, str(tmp_path))
    try:
        prog.graphmend_enabled = True
        prog.graphmend_scope = ["scopedmodel"]
        sys.modules.pop("scopedmodel", None)
        sys.modules.pop("scopedmodel.net", None)
        net = importlib.import_module("scopedmodel.net")
        names = [
            i.argval
            for i in dis.get_instructions(net.Net.forward.__code__)
            if isinstance(i.argval, str)
        ]
        assert "where" in names, "imported scoped model was not transformed"
        # torch itself (not in scope) must be unaffected
        assert hasattr(torch, "_dynamo")
    finally:
        prog.graphmend_enabled = saved_en
        prog.graphmend_scope = saved_scope
        sys.path.remove(str(tmp_path))
        sys.modules.pop("scopedmodel", None)
        sys.modules.pop("scopedmodel.net", None)


def _run_raising_model_fixture(graphmend: bool) -> tuple[list, object]:
    """Run the raising-forward fixture; return (captured log messages, exc)."""
    src = _compile_src("logger_forward_hook_raises.py", graphmend)
    ns: dict = {}
    orig_compile = torch.compile
    torch.compile = lambda *a, **k: a[0] if a else (lambda f: f)
    try:
        exec(compile(src, "logger_forward_hook_raises.py", "exec"), ns)
    finally:
        torch.compile = orig_compile

    messages: list = []

    class _Capture(logging.Handler):
        def emit(self, record: object) -> None:
            messages.append(record.getMessage())  # type: ignore[attr-defined]

    handler = _Capture()
    logging.getLogger("gm_forward_hook_raises").addHandler(handler)
    caught: object = None
    try:
        torch._dynamo.reset()
        try:
            torch.compile(ns["model"], backend="eager")(torch.tensor([1.0, 2.0]))
        except Exception as exc:  # noqa: BLE001 - the fixture raises on purpose
            caught = exc
    finally:
        logging.getLogger("gm_forward_hook_raises").removeHandler(handler)
    return messages, caught


def test_deferred_logger_flushes_on_exceptional_exit() -> None:
    """[Defer] must not swallow log output when the forward raises.

    The transformed forward buffers the logger call instead of performing it, so
    a plain forward hook (which only runs on a successful return) would drop it.
    GraphMend registers the flush hook with ``always_call=True``; this asserts
    that the log still reaches the handler and the original exception still
    propagates unchanged.
    """
    orig_msgs, orig_exc = _run_raising_model_fixture(False)
    fixed_msgs, fixed_exc = _run_raising_model_fixture(True)

    # Baseline: untransformed code logs, then raises.
    assert "GM-RAISING-FORWARD-LOG" in orig_msgs
    assert isinstance(orig_exc, ValueError) and "GM-BOOM" in str(orig_exc)

    # The exception is preserved in type and message...
    assert isinstance(fixed_exc, ValueError), f"expected ValueError, got {fixed_exc!r}"
    assert "GM-BOOM" in str(fixed_exc)
    # ...and the deferred log is still emitted rather than silently dropped.
    assert "GM-RAISING-FORWARD-LOG" in fixed_msgs, (
        "deferred logger output was lost on the exceptional exit -- the flush "
        "hook must be registered with always_call=True"
    )


def test_flush_hook_registered_with_always_call() -> None:
    """The generated hook registration must pass always_call=True.

    Without it the flush runs only on a successful forward, so a raising forward
    drops every buffered logger call. Asserted on the generated source so the
    guarantee is visible even where torch's hook semantics are not exercised.
    """
    src = _compile_src("logger_forward_hook.py", True)
    assert "register_forward_hook(__jac_log_flush_hook__, always_call=True)" in src


def _run_raising_compiled_fn(graphmend: bool) -> tuple[list, object]:
    """Run the raising @torch.compile fixture; return (printed lines, exception)."""
    import builtins

    src = _compile_src("side_effect_raises.jac", graphmend)
    ns: dict = {}
    printed: list = []
    real_print = builtins.print
    builtins.print = lambda *a, **k: printed.append(" ".join(str(v) for v in a))
    try:
        exec(compile(src, "side_effect_raises.jac", "exec"), ns)
        caught: object = None
        torch._dynamo.reset()
        try:
            ns["f"](torch.tensor([1.0, 2.0]))
        except Exception as exc:  # noqa: BLE001 - the fixture raises on purpose
            caught = exc
    finally:
        builtins.print = real_print
    return printed, caught


def test_deferred_print_flushes_on_exceptional_exit() -> None:
    """The eager boundary guard drains the buffer when the compiled fn raises.

    Deferral moves *when* the print is emitted; an exit that never reaches the
    in-function flush would therefore lose it. The guard sits above
    @torch.compile, so its finally runs on the exceptional path too.
    """
    orig_out, orig_exc = _run_raising_compiled_fn(False)
    fixed_out, fixed_exc = _run_raising_compiled_fn(True)

    # Baseline: the untransformed program prints, then raises.
    assert any("GM-SE-BEFORE-RAISE" in line for line in orig_out)
    assert isinstance(orig_exc, ValueError) and "GM-SE-BOOM" in str(orig_exc)

    # The exception survives unchanged...
    assert isinstance(fixed_exc, ValueError), f"expected ValueError, got {fixed_exc!r}"
    assert "GM-SE-BOOM" in str(fixed_exc)
    # ...and the deferred print is still emitted rather than dropped.
    assert any("GM-SE-BEFORE-RAISE" in line for line in fixed_out), (
        "deferred print was lost on the exceptional exit -- the __jac_se_guard__ "
        "boundary must flush the global buffer in its finally"
    )


def test_se_guard_is_outside_the_compiled_region() -> None:
    """The guard must be prepended, i.e. applied ABOVE @torch.compile.

    Order matters for more than tidiness: inside the compiled region an
    untraceable call in a `finally` makes Dynamo abandon the whole frame (1 FX
    graph becomes 0), so a guard applied below torch.compile would trade the
    graph break being removed for full eager fallback.
    """
    src = _compile_src("side_effect.jac", True)
    assert "@__jac_se_guard__" in src
    assert src.index("@__jac_se_guard__") < src.index("@torch.compile")


def test_se_guard_does_not_split_the_graph() -> None:
    """Adding the boundary guard must not cost a graph break."""
    _assert_defragmented("side_effect.jac", "f", torch.tensor([1.0, 2.0, 3.0]))


def test_trap_lowers_a_real_transformers_validation_guard() -> None:
    """[Trap] fires on genuine upstream model source, not just fixtures.

    transformers' VITS contains a textbook validation guard on the inference
    path -- ``if not (discriminant >= 0).all(): raise RuntimeError(...)`` in
    ``_rational_quadratic_spline`` -- reached with ``reverse=True`` during a
    normal forward. It must lower to a graph-native ``torch._assert_async``.

    Asserted at the transformation level rather than as a break-count row in
    paper_eval: VITS carries ~22 breaks from unrelated causes (dynamic shapes in
    the vocoder), and this guard sits inside a region that is already eager, so
    lowering it does not change the graph count. A registry entry would read
    "22 -> 22, 0% fixed" and misrepresent a transform that applied correctly.

    The paper's own VG model, MoLFormer-XL, cannot serve here: it ships its
    guards as Hub remote code, and all of transformers contains exactly one
    ``torch.equal`` (in a loss function, not a guard).
    """
    transformers = pytest.importorskip("transformers")
    src_path = (
        Path(transformers.__file__).parent / "models" / "vits" / "modeling_vits.py"
    )
    if not src_path.is_file():
        pytest.skip("transformers VITS source not present")

    prog = JacProgram()
    prog.graphmend_scoped_compile = True
    mod = prog.compile(
        file_path=str(src_path),
        options=CompileOptions(graphmend=True, type_check=False),
    )
    pa = mod.gen.py_ast
    src = ast.unparse(pa[0] if isinstance(pa, list) else pa)

    assert "torch._assert_async((discriminant >= 0).all()" in src, (
        "the VITS discriminant guard was not lowered to a graph-native assert"
    )
    # The Python-level `raise` on that path is gone: the check now lives in the
    # graph rather than forcing a data-dependent bool back into the interpreter.
    assert "if not (discriminant >= 0).all():" not in src
