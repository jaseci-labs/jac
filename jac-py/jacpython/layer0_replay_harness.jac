# Layer 0/1 host-replay harness (TODO.md Layer 0/1, jac-py/PLAN.md §6.6).
# Test-free module: regression tests in layer0_replay.jac; P3 ratchet in
# layer0_replay_p3_gate.jac. Import this, not layer0_replay, when you need a
# clean ceval slate.
import from objects { PyObj, PyStr, PyError, is_error }
import from pyc_first { unmarshal, exec_code, exec_module, to_host, build_copy_module }

::py::
import ast
import marshal


def _l0_harvest(source):
    """Extract (expr_src, expected_src) pairs from assertEqual/assertEquals calls."""
    pairs = []
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return pairs
    for node in ast.walk(tree):
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr in ("assertEqual", "assertEquals")
            and len(node.args) >= 2
        ):
            a = ast.get_source_segment(source, node.args[0])
            b = ast.get_source_segment(source, node.args[1])
            if a is not None and b is not None:
                pairs.append((a, b))
    return pairs


def _l0_is_selfcontained(expr_src):
    """A replayable expression evaluates on the host with no test-local state."""
    try:
        eval(expr_src, {"__builtins__": __builtins__}, {})
        return True
    except BaseException:
        return False


def _l0_expected(expr_src):
    return eval(expr_src, {"__builtins__": __builtins__}, {})


def _l0_compile_eval(expr_src):
    # Eval-mode code object ends in RETURN_VALUE, so jacpython's ceval yields the
    # expression value directly -- no module-globals plumbing needed.
    return marshal.dumps(compile(expr_src, "<layer0>", "eval"))


def _l0_host_equal(a, b):
    try:
        # Two NaNs are a conformance MATCH (both sides computed NaN); `nan == nan`
        # is False, which would otherwise flag a correct jacpython result.
        if a != a and b != b:
            return True
        return bool(a == b)
    except BaseException:
        return False


# ---- Layer 1: statement-shaped (exec-mode) replay --------------------------
# Layer 0 replays self-contained *expressions*. Layer 1 lifts that to whole test
# *methods*: run a method's self-contained setup statements (a generator def, a
# few binds) in BOTH host CPython and jacpython, then evaluate each `self.assert*`
# argument against that shared, stateful namespace on both sides and diff. This
# is what exercises generator FUNCTIONS (def+yield, .send/.throw/.close, yield
# from) -- none of which fit Layer 0's single-expression eval -- against the real
# corpus, and threads generator state across a method's asserts exactly as
# CPython does when it runs the method once.
_L1_CHECKS = {
    "assertEqual", "assertNotEqual", "assertTrue", "assertFalse",
    "assertIs", "assertIsNot", "assertIsNone", "assertIsNotNone",
    "assertGreater", "assertLess", "assertGreaterEqual", "assertLessEqual",
}


def _stmt_scope_nodes(stmt):
    # ast.walk(stmt) minus nested function/class subtrees: names bound in an
    # inner scope (e.g. a method parameter named `self`) are not fixture-state
    # references of the enclosing test method.
    stack = list(ast.iter_child_nodes(stmt))
    while stack:
        n = stack.pop()
        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            continue
        yield n
        stack.extend(ast.iter_child_nodes(n))


def _dedent_segment(seg, base_col):
    # ast.get_source_segment keeps ABSOLUTE indentation on continuation lines
    # while the first line loses its own indent (base_col). Every non-blank
    # continuation line therefore carries >= base_col leading columns: strip
    # exactly base_col so the block's RELATIVE shape survives. (Stripping a
    # min-delta would no-op whenever sibling clauses sit at base_col, e.g.
    # try/except/else.) Single-line segments pass through.
    lines = seg.split("\n")
    if len(lines) < 2 or base_col <= 0:
        return seg
    fixed = [lines[0]] + [
        l[base_col:] if len(l) >= base_col and l[:base_col].strip() == "" else l
        for l in lines[1:]
    ]
    return "\n".join(fixed)


def _l1_flatten_seq(stmts):
    """Flatten a statement sequence, expanding Try blocks into their inner
    statements (body, handlers, orelse, finally) so nested self.assert* checks
    are harvested as checks instead of being silently swallowed by the
    whole-block drop rule (HARNESS B). Control flow itself stays in setup:
    non-assert statements keep their source shape and still execute there;
    only the checks are lifted out. Recurses through nested Try blocks."""
    out = []
    for s in stmts:
        if isinstance(s, ast.Try):
            out.extend(_l1_flatten_seq(s.body))
            for h in s.handlers:
                out.extend(_l1_flatten_seq(h.body))
            out.extend(_l1_flatten_seq(s.orelse))
            out.extend(_l1_flatten_seq(s.finalbody))
        else:
            out.append(s)
    return out


def _l1_harvest_methods(source):
    """Split each `test_*` method into (name, setup_src, checks).

    setup_src is the dedented block of the method's non-assert statements;
    checks is a list of (assert_name, [arg_src, ...]). A method is dropped here
    (never reported) if any setup statement touches `self` (fixture state this
    layer can't reproduce) or the body uses constructs this layer doesn't model
    (with/try/assertRaises); those are counted as skipped by the caller when the
    host self-containment probe also declines them.
    """
    out = []
    try:
        tree = ast.parse(source)
    except SyntaxError:
        return out
    import textwrap
    for node in ast.walk(tree):
        if not (isinstance(node, ast.FunctionDef) and node.name.startswith("test")):
            continue
        setup_stmts, checks, ok = [], [], True
        for stmt in _l1_flatten_seq(node.body):
            # A `self.assertX(...)` check statement.
            if (
                isinstance(stmt, ast.Expr)
                and isinstance(stmt.value, ast.Call)
                and isinstance(stmt.value.func, ast.Attribute)
                and isinstance(stmt.value.func.value, ast.Name)
                and stmt.value.func.value.id == "self"
                and stmt.value.func.attr in _L1_CHECKS
            ):
                args = [ast.get_source_segment(source, a) for a in stmt.value.args]
                if any(a is None for a in args):
                    ok = False
                    break
                checks.append((stmt.value.func.attr, args))
                continue
            # A `with self.assertRaises(E): body` raises-check. Stored as
            # ("assertRaises", [exc_src, body_src]); body_src is a dedented
            # statement block whose execution must raise a matching exception.
            if (
                isinstance(stmt, ast.With)
                and len(stmt.items) == 1
                and isinstance(stmt.items[0].context_expr, ast.Call)
                and isinstance(stmt.items[0].context_expr.func, ast.Attribute)
                and isinstance(stmt.items[0].context_expr.func.value, ast.Name)
                and stmt.items[0].context_expr.func.value.id == "self"
                and stmt.items[0].context_expr.func.attr == "assertRaises"
                and len(stmt.items[0].context_expr.args) >= 1
            ):
                exc_src = ast.get_source_segment(
                    source, stmt.items[0].context_expr.args[0]
                )
                body_nodes = list(stmt.body)
                body_segs = [ast.get_source_segment(source, s) for s in body_nodes]
                if exc_src is None or any(s is None for s in body_segs) or any(
                    isinstance(n, ast.Name) and n.id == "self"
                    for s in stmt.body for n in _stmt_scope_nodes(s)
                ):
                    ok = False
                    break
                body_fixed = "\n".join(
                    _dedent_segment(seg, node.col_offset)
                    for node, seg in zip(body_nodes, body_segs)
                )
                checks.append(("assertRaises", [exc_src, textwrap.dedent(body_fixed)]))
                continue
            # A bare docstring/expression constant is inert setup.
            if isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Constant):
                continue
            # Anything referencing `self` (or an unharvestable segment) is out.
            # The walk skips nested def/class subtrees: a method parameter named
            # `self` inside a locally-defined class/function is its own scope,
            # not fixture state (the host replayability probe still guards the
            # remainder). Only Load-scope references at statement scope count.
            if any(
                isinstance(n, ast.Name) and n.id == "self"
                for n in _stmt_scope_nodes(stmt)
            ):
                ok = False
                break
            seg = ast.get_source_segment(source, stmt)
            if seg is None:
                ok = False
                break
            setup_stmts.append(_dedent_segment(seg, stmt.col_offset))
        if not ok or not checks:
            continue
        setup_src = textwrap.dedent("\n".join(setup_stmts)) if setup_stmts else ""
        out.append((node.name, setup_src, checks))
    return out


def _l1_host_setup(setup_src):
    import copy
    ns = {"__name__": "__main__", "__builtins__": __builtins__, "copy": copy}
    if setup_src:
        exec(compile(setup_src, "<layer1>", "exec"), ns)
    return ns


def _l1_host_eval_in(ns, expr_src):
    return eval(compile(expr_src, "<layer1>", "eval"), ns)


def _l1_host_raises(ns, body_src):
    """Execute a statement block; return the raised exception's type name, or
    None if it completed without raising."""
    try:
        exec(compile(body_src, "<layer1>", "exec"), ns)
        return None
    except BaseException as e:
        return type(e).__name__


def _l1_raise_match(jac_name, host_name):
    """Conformance for a raises-check: jacpython must raise the same concrete
    exception type CPython did (both non-empty and equal)."""
    return bool(host_name is not None and jac_name != "" and jac_name == host_name)


def _l1_host_replayable(setup_src, checks):
    """True iff the method runs end-to-end on the HOST with no fixture state --
    setup execs, every assert argument evaluates, and every raises-check body
    actually raises its expected type. Filters out methods that need imports/
    state we don't carry, so they're honestly counted as skipped rather than
    charged against jacpython as failures."""
    try:
        ns = _l1_host_setup(setup_src)
        for name, args in checks:
            if name == "assertRaises":
                _l1_host_eval_in(ns, args[0])  # expected-exc name must resolve
                if _l1_host_raises(ns, args[1]) is None:
                    return False
                continue
            for arg_src in args:
                _l1_host_eval_in(ns, arg_src)
        return True
    except BaseException:
        return False


def _l1_compile_setup(setup_src):
    return marshal.dumps(compile(setup_src or "pass", "<layer1>", "exec"))
::py::



# The two-dimensional ledger TODO.md Layer 1 calls for, seeded at Layer 0:
# passed/failed are real conformance; skipped is the honest scaffolding count
# (asserts that need fixture state this layer can't carry).
obj ReplayResult {
    has passed: int = 0,
        failed: int = 0,
        skipped: int = 0,
        errored: int = 0,
        failures: list[str] = [],
        errors: list[str] = [];
}

# jacpython raised while replaying (marshal/ceval gap)
# Replay one self-contained expression through the jacpython object core + ceval
# and diff against the host's own evaluation. Returns True on match. Guarded:
# a marshal-reader desync or an unsupported opcode is a tool gap to be counted,
# never a crash that aborts the whole file's measurement.
def replay_expr(expr_src: str) -> bool {
    try {
        co: PyObj = unmarshal(_l0_compile_eval(expr_src) as list[int]);
        got: PyObj = exec_code(co, [], {});
        return _l0_host_equal(to_host(got), _l0_expected(expr_src)) as bool;
    } except Exception as e {
        return False;
    }
}

# Replay `expr_src` in jacpython and diff against host(`expected_src`).
# Returns 1 (match), 0 (mismatch), or -1 (jacpython raised -- a real gap).
def _replay_pair(expr_src: str, expected_src: str) -> int {
    try {
        got: PyObj = exec_code(
            unmarshal(_l0_compile_eval(expr_src) as list[int]), [], {}
        );
        expected = _l0_expected(expected_src);
        if _l0_host_equal(to_host(got), expected) as bool {
            return 1;
        }
        return 0;
    } except Exception as e {
        return -1;
    }
}

# Drive a whole test-file source string: harvest its assertEqual pairs, replay
# every self-contained one, tally the rest as scaffolding-skips. The errored
# count is the honest "tool gap discovered here" signal (PLAN.md item #6).
def layer0_replay_source(source: str) -> ReplayResult {
    result = ReplayResult();
    pairs = _l0_harvest(source);
    for pair in pairs {
        expr_src: str = pair[0] as str;
        expected_src: str = pair[1] as str;
        if not (
            (_l0_is_selfcontained(expr_src) as bool)
            and (_l0_is_selfcontained(expected_src) as bool)
        ) {
            result.skipped = result.skipped + 1;
            continue;
        }
        verdict = _replay_pair(expr_src, expected_src);
        if verdict == 1 {
            result.passed = result.passed + 1;
        } elif verdict == 0 {
            result.failed = result.failed + 1;
            result.failures.append(expr_src);
        } else {
            result.errored = result.errored + 1;
            result.errors.append(expr_src);
        }
    }
    return result;
}

# ---- Layer 1 driver (jac side) --------------------------------------------

# Run a method's setup in jacpython, returning the resulting module namespace.
# `copy` is seeded with the native copy shim (matching the host setup) so a
# `copy.copy(gen)` check raises CPython's TypeError natively rather than draining
# the generator to a host list; a setup that binds `copy` itself takes precedence.
def layer1_run_setup(setup_src: str) -> dict[str, PyObj] {
    ns: dict[str, PyObj] = {"__name__": PyStr(t="str", val="__main__")};
    # Strict: a setup that raises must surface here, so the caller counts the
    # method as ERRORED — replaying asserts against a partial namespace yields
    # misleading FAILED verdicts (HARNESS A). exec_module discards the outcome.
    outcome = exec_code(unmarshal(_l1_compile_setup(setup_src) as list[int]), [], ns);
    if is_error(outcome) {
        raise RuntimeError((outcome as PyError).exception.message);
    }
    if not ("copy" in ns) {
        ns["copy"] = build_copy_module();
    }
    return ns;
}

# Evaluate `expr_src` (eval-mode) against a jacpython namespace, so names bound
# by the setup (generators, locals) resolve. Eval-mode code ends in RETURN_VALUE.
def layer1_eval_in(ns: dict[str, PyObj], expr_src: str) -> PyObj {
    return exec_code(unmarshal(_l0_compile_eval(expr_src) as list[int]), [], ns);
}

# Execute a statement block (exec-mode) against a jacpython namespace and report
# the type name of a raised exception, or "" if it completed without raising --
# the jac side of an assertRaises check. run_frame surfaces an uncaught raise as
# its return value, so an error result IS jacpython's raise.
def _l1_jac_raise_name(ns: dict[str, PyObj], body_src: str) -> str {
    outcome = exec_code(unmarshal(_l1_compile_setup(body_src) as list[int]), [], ns);
    if is_error(outcome) {
        return (outcome as PyError).exception.type_name;
    }
    return "";
}

# Replay one harvested method: build the jacpython and host namespaces once, then
# evaluate every assert argument against both in source order (so shared
# generator state advances identically) and diff each. Returns 1 (all match),
# 0 (a real divergence), or -1 (jacpython raised -- a ceval/marshal gap).
def _l1_replay_method(setup_src: str, checks: any) -> int {
    try {
        ns_jac = layer1_run_setup(setup_src);
        ns_host = _l1_host_setup(setup_src);
        for chk in checks {
            if (chk[0] as str) == "assertRaises" {
                # jacpython and CPython must raise the same exception type when
                # the check body runs against the shared namespace.
                jac_name = _l1_jac_raise_name(ns_jac, chk[1][1] as str);
                host_name = _l1_host_raises(ns_host, chk[1][1]);
                if not (_l1_raise_match(jac_name, host_name) as bool) {
                    return 0;
                }
                continue;
            }
            for arg_src in chk[1] {
                jac_got: PyObj = layer1_eval_in(ns_jac, arg_src as str);
                host_exp = _l1_host_eval_in(ns_host, arg_src);
                if not (_l0_host_equal(to_host(jac_got), host_exp) as bool) {
                    return 0;
                }
            }
        }
        return 1;
    } except Exception as e {
        return -1;
    }
}

# Drive a whole test-file source through Layer 1: harvest replayable methods,
# probe each for host self-containment (fixture-free), and replay the rest.
def layer1_replay_source(source: str) -> ReplayResult {
    result = ReplayResult();
    methods = _l1_harvest_methods(source);
    for method in methods {
        setup_src: str = method[1] as str;
        checks = method[2];
        if not (_l1_host_replayable(setup_src, checks) as bool) {
            result.skipped = result.skipped + 1;
            continue;
        }
        verdict = _l1_replay_method(setup_src, checks);
        if verdict == 1 {
            result.passed = result.passed + 1;
        } elif verdict == 0 {
            result.failed = result.failed + 1;
            result.failures.append(method[0] as str);
        } else {
            result.errored = result.errored + 1;
            result.errors.append(method[0] as str);
        }
    }
    return result;
}
