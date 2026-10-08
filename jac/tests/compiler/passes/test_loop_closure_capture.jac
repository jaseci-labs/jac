"""E2097: a closure that outlives its loop iteration captures a binding the loop reassigns.

A local first assigned in a loop body is owned by the enclosing function
(Python-like scoping, #7925; a typed declaration is function-owned too,
#8052), so closures created in different iterations share one binding and
every one of them sees the value the final iteration wrote (#8168). The
scoping is intended; the capture is the bug, and it is reported from the
analysis schedule so `jac check` shows it in every codespace.

The fixtures give each case a uniquely named variable, so a test names the
exact set of captures that must be reported rather than pinning lines.
"""

import os;
import re;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS, Severity }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "loop_closure_capture"
     ),
     CODE = "E2097";

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

"""The variable an E2097 message names."""
def captured_name(msg: str) -> str {
    found = re.search(r"'(\w+)'", msg);
    assert found is not None , f"E2097 must name the captured variable: {msg}";
    return found.group(1);
}

"""The captured names E2097 reported, in source order."""
def reported_names(prog: JacProgram) -> list[str] {
    hits = sorted(
        [
            (e.loc.first_line, e.loc.col_start, str(e.msg))
            for e in prog.errors_had
            if e.code is not None and e.code.code == CODE
        ]
    );
    return [captured_name(msg) for (_line, _col, msg) in hits];
}

"""Every diagnostic that is not E2097, rendered for an assertion message."""
def other_errors(prog: JacProgram) -> list[str] {
    return [
        e.pretty_print()
        for e in prog.errors_had
        if e.code is None or e.code.code != CODE
    ];
}

glob REPORTED_SERVER = [
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
         "regVal",
         "namedVal",
         "yieldVal",
         "mapOuter",
         "facVal",
         "implLocal",
         "methodVal",
         "entryLocal"
     ];

test "E2097 is a registered error whose text names the binding and the fix" {
    assert CODE in DIAGNOSTICS , "the loop-capture diagnostic is not registered";
    info = DIAGNOSTICS[CODE];
    assert info.severity == Severity.ERROR , "a shared loop binding is an error, not a warning";
    message = info.format_message(name="slotId");
    assert "'slotId'" in message , message;
    assert "final" in message , f"the message must say which value every closure sees: {message}";
    help_text = info.format_help(name="slotId") or "";
    assert "parameter" in help_text , f"the help must state the parameter-binding fix: {help_text}";
}

test "for-slot handlers over a loop-body local are reported, bare and annotated (#8168)" {
    prog = check_fixture("client_for_slot.jac");
    assert not other_errors(prog) , "\n".join(other_errors(prog));
    assert reported_names(prog) == ["slotId", "annId", "picked", "sectionId"] , (
        "the bare local, the annotated local, the minimal repro and the handler "
        "built inside a .map() callback must each be reported once; a lambda-body "
        "local, a parameter-bound value, the loop target and a combinator "
        f"callback must not: {[e.pretty_print() for e in prog.errors_had]}"
    );
}

test "E2097 anchors the captured name inside the closure" {
    prog = check_fixture("client_for_slot.jac");
    with open(os.path.join(FIXTURES, "client_for_slot.jac")) as fh {
        lines = fh.read().split("\n");
    }
    hits = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == CODE
    ];
    assert len(hits) == 4 , [e.pretty_print() for e in prog.errors_had];
    for e in hits {
        name = captured_name(str(e.msg));
        text = lines[e.loc.first_line - 1];
        assert "lambda" in text and name in text[e.loc.col_start - 1:] , (
            f"E2097 for '{name}' must point at its use inside the handler, got line "
            f"{e.loc.first_line} col {e.loc.col_start}: {text}"
        );
    }
}

test "closures that outlive their iteration are reported in server code" {
    prog = check_fixture("reported.jac", codespace="server");
    assert not other_errors(prog) , "\n".join(other_errors(prog));
    assert reported_names(prog) == REPORTED_SERVER , (
        f"expected exactly {REPORTED_SERVER}, got {reported_names(prog)}"
    );
}

test "the rule is the same when the module prefers the native codespace" {
    prog = check_fixture("native_reported.jac", codespace="native");
    assert reported_names(prog) == ["nativeLocal", "nativeStep"] , (
        [e.pretty_print() for e in prog.errors_had]
    );
}

test "closures that cannot observe another iteration stay silent" {
    prog = check_fixture("not_reported.jac", codespace="server");
    assert not prog.errors_had , "\n".join(e.pretty_print() for e in prog.errors_had);
}

test "an inline jac:ignore suppresses E2097 like any other diagnostic" {
    src = (
        "def build(xs: list[int]) -> list[Callable[[], int]] {\n"
        "    out: list[Callable[[], int]] = [];\n"
        "    for x in xs {\n"
        "        kept = x * 2;\n"
        "        out.append(lambda -> int { return kept; });  # jac:ignore[E2097]\n"
        "        seen = x * 3;\n"
        "        out.append(lambda -> int { return seen; });\n"
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
    assert reported_names(prog) == ["seen"] , [
        e.pretty_print() for e in prog.errors_had
    ];
}
