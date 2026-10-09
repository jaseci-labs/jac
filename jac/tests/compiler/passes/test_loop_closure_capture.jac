"""E2097 / W2084: a closure created in a loop captures a binding the loop reassigns.

A local first assigned in a loop body is owned by the enclosing function
(Python-like scoping, #7925; a typed declaration is function-owned too,
#8052), so closures created in different iterations share one binding and
every one of them sees the value the final iteration wrote (#8168). The
scoping is intended; the capture is the bug, and it is reported from the
analysis schedule so `jac check` shows it in every codespace.

How it is reported depends on what the code in front of the compiler proves:

- E2097 (error): the closure is kept past its iteration. It is stored in a
  JSX attribute, a container, a field or a subscript that outlives the
  iteration, or it is yielded, with no opaque call in between.
- W2084 (warning): the closure is handed to a callee the compiler cannot see
  into, which may run it before returning or may keep it.
- nothing: the closure runs within its iteration.

The fixtures give each case a uniquely named variable, so a test names the
exact code and variable of every report rather than pinning lines.
"""

import os;
import re;
import subprocess;
import sys;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS, Severity }
import from jaclang.compiler.passes.context { Alert }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "loop_closure_capture"
     ),
     HELD = "E2097",
     PASSED_ON = "W2084";

"""Analyze a fixture the way `jac check` does and return the program."""
def check_fixture(name: str, codespace: str = "") -> JacProgram {
    prog = JacProgram();
    prog.compile(
        os.path.join(FIXTURES, name),
        no_cgen=True,
        options=CompileOptions(default_codespace=codespace)
    );
    return prog;
}

"""The loop-capture diagnostics of a program, errors and warnings, in source order."""
def captures(prog: JacProgram) -> list[Alert] {
    hits = [
        a
        for a in prog.errors_had + prog.warnings_had
        if a.code is not None and a.code.code in (HELD, PASSED_ON)
    ];
    return sorted(
        hits,
        key=lambda (a: Alert) -> tuple[int, int] { return (
            a.loc.first_line,
            a.loc.col_start
        ); }
    );
}

"""The variable a loop-capture message names."""
def captured_name(msg: str) -> str {
    found = re.search(r"'(\w+)'", msg);
    assert found is not None , f"the message must name the captured variable: {msg}";
    return found.group(1);
}

"""Every loop-capture report as (code, variable), in source order."""
def reported(prog: JacProgram) -> list[tuple[str, str]] {
    return [
        (a.code.code, captured_name(str(a.msg)))
        for a in captures(prog)
        if a.code
    ];
}

"""Every error that is not a loop capture, rendered for an assertion message."""
def other_errors(prog: JacProgram) -> list[str] {
    return [
        e.pretty_print()
        for e in prog.errors_had
        if e.code is None or e.code.code != HELD
    ];
}

"""Run `jac check` on a fixture in a fresh process; returns (exit code, output)."""
def jac_check(name: str) -> tuple[int, str] {
    script = (
        "import sys, runpy\n"
        f"sys.path.insert(0, {JAC_ROOT!r})\n"
        f"sys.argv = ['jac', 'check', {os.path.join(FIXTURES, name)!r}]\n"
        "try:\n"
        "    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)\n"
        "except SystemExit as exc:\n"
        "    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)\n"
    );
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=JAC_ROOT,
        capture_output=True,
        text=True,
        timeout=900
    );
    return (proc.returncode, proc.stdout + proc.stderr);
}

glob HELD_NAMES = [
         "forLocal",
         "typedLocal",
         "whileLocal",
         "stepIdx",
         "defLocal",
         "leftPart",
         "rightPart",
         "walrusVal",
         "rowSum",
         "seed",
         "deepVal",
         "runTotal",
         "dictKey",
         "namedVal",
         "yieldVal",
         "facVal",
         "implLocal",
         "methodVal",
         "fieldVal",
         "setVal",
         "literalVal",
         "carriedVal",
         "augVal",
         "extendVal",
         "insertVal",
         "viaVal",
         "freshVal",
         "bumpVal",
         "genVal",
         "asyncVal",
         "hopFieldVal",
         "entryLocal"
     ],
     PASSED_ON_NAMES = [
         "regVal",
         "argVal",
         "kwVal",
         "namedArgVal",
         "propsVal",
         "anyVal",
         "batchVal",
         "resetVal",
         "extractVal",
         "pickVal",
         "targetVal",
         "aliasVal",
         "slotVal",
         "mapOuter",
         "hopVal"
     ];

test "E2097 is an error and W2084 a warning, and both name the binding and the fix" {
    assert HELD in DIAGNOSTICS , "the kept-closure diagnostic is not registered";
    assert PASSED_ON in DIAGNOSTICS , "the passed-on-closure diagnostic is not registered";
    held = DIAGNOSTICS[HELD];
    passed_on = DIAGNOSTICS[PASSED_ON];
    assert held.severity == Severity.ERROR , "a closure the loop keeps is an error";
    assert passed_on.severity == Severity.WARNING , (
        "a closure handed to a callee the compiler cannot see into is a warning: "
        "the code is often correct"
    );
    for info in [held, passed_on] {
        message = info.format_message(name="slotId");
        assert "'slotId'" in message , message;
        assert "final" in message , f"the message must say which value every closure sees: {message}";
        help_text = info.format_help(name="slotId") or "";
        assert "parameter" in help_text , f"the help must state the parameter-binding fix: {help_text}";
    }
    conditional = passed_on.format_message(name="slotId");
    assert " if " in conditional and "callee" in conditional , (
        f"the warning must say it depends on the callee keeping the closure: {conditional}"
    );
    assert " if " not in held.format_message(name="slotId") , (
        "the error states a fact, not a condition"
    );
}

test "for-slot handlers over a loop-body local: an error in the element, a warning through a call (#8168)" {
    prog = check_fixture("client_for_slot.jac");
    assert not other_errors(prog) , "\n".join(other_errors(prog));
    assert reported(prog)
        == [
            (HELD, "slotId"),
            (HELD, "annId"),
            (HELD, "picked"),
            (HELD, "sectionId"),
            (HELD, "namedId"),
            (HELD, "spreadId"),
            (PASSED_ON, "wrappedId"),
            (PASSED_ON, "propsId")
        ] , (
        "a handler stored in a JSX attribute is an error, bare or annotated, "
        "inline, named or spread; one that goes through a call first is a "
        "warning; a lambda-body local, a parameter-bound value, the loop target "
        f"and a combinator callback are silent: {reported(prog)}"
    );
}

test "a loop-capture report anchors the captured name inside the closure" {
    prog = check_fixture("client_for_slot.jac");
    with open(os.path.join(FIXTURES, "client_for_slot.jac")) as fh {
        lines = fh.read().split("\n");
    }
    hits = captures(prog);
    assert len(hits) == 8 , reported(prog);
    for hit in hits {
        name = captured_name(str(hit.msg));
        text = lines[hit.loc.first_line - 1];
        assert text[hit.loc.col_start - 1:].startswith(name) , (
            f"the report for '{name}' must point at the name, got line "
            f"{hit.loc.first_line} col {hit.loc.col_start}: {text}"
        );
        assert re.search(rf"\b{name}\b\s*(:[^=]+)?=[^=]", text) is None , (
            f"the report for '{name}' must point at its use inside the closure, "
            f"not at the assignment: {text}"
        );
    }
}

test "closures the loop keeps are errors in server code" {
    prog = check_fixture("held.jac", codespace="server");
    assert not other_errors(prog) , "\n".join(other_errors(prog));
    assert reported(prog) == [(HELD, name) for name in HELD_NAMES] , (
        f"expected E2097 for exactly {HELD_NAMES}, got {reported(prog)}"
    );
}

test "closures handed to an opaque callee are warnings and never errors" {
    prog = check_fixture("passed_on.jac", codespace="server");
    assert not prog.errors_had , "\n".join(e.pretty_print() for e in prog.errors_had);
    assert reported(prog) == [(PASSED_ON, name) for name in PASSED_ON_NAMES] , (
        f"expected W2084 for exactly {PASSED_ON_NAMES}, got {reported(prog)}"
    );
}

test "the rule is the same when the module prefers the native codespace" {
    prog = check_fixture("native_placed.jac", codespace="native");
    assert reported(prog) == [(HELD, "nativeLocal"), (HELD, "nativeStep")] , [
        e.pretty_print() for e in prog.errors_had
    ];
}

test "closures that cannot observe another iteration stay silent" {
    prog = check_fixture("not_reported.jac", codespace="server");
    assert not prog.errors_had , "\n".join(e.pretty_print() for e in prog.errors_had);
    assert reported(prog) == [] , reported(prog);
}

test "jac check shows the warning and passes, and fails on the error" {
    (rc, out) = jac_check("passed_on.jac");
    assert rc == 0 , f"a W2084 warning must not fail `jac check`:\n{out}";
    assert "warning[W2084]" in out , f"`jac check` must show the warning:\n{out}";
    assert "E2097" not in out , out;

    (rc, out) = jac_check("held.jac");
    assert rc != 0 , f"an E2097 error must fail `jac check`:\n{out}";
    assert "error[E2097]" in out , out;
}

test "an inline jac:ignore suppresses either code like any other diagnostic" {
    src = (
        "def keep(fn: Callable[[], int]) -> int { return fn(); }\n"
        "def build(xs: list[int]) -> list[Callable[[], int]] {\n"
        "    out: list[Callable[[], int]] = [];\n"
        "    for x in xs {\n"
        "        kept = x * 2;\n"
        "        out.append(lambda -> int { return kept; });  # jac:ignore[E2097]\n"
        "        seen = x * 3;\n"
        "        out.append(lambda -> int { return seen; });\n"
        "        quiet = x * 4;\n"
        "        keep(lambda -> int { return quiet; });  # jac:ignore[W2084]\n"
        "        loud = x * 5;\n"
        "        keep(lambda -> int { return loud; });\n"
        "    }\n"
        "    return out;\n"
        "}\n"
    );
    prog = JacProgram();
    prog.compile(
        use_str=src,
        file_path="loop_capture_ignore.jac",
        no_cgen=True,
        options=CompileOptions(default_codespace="server")
    );
    assert reported(prog) == [(HELD, "seen"), (PASSED_ON, "loud")] , reported(prog);
}
