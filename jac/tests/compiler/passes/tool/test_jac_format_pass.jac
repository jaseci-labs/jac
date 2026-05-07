"""Jac format pass tests – migrated from test_jac_format_pass.py.

Tests that the Jac formatter produces correct output: fixture comparisons,
AST preservation, micro suite round-trip, and regression tests.
"""

import ast as ast3;
import os;
import from difflib { unified_diff }
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.helpers { add_line_numbers }
import from jaclang.jac0core.program { JacProgram }
glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "tool", "fixtures"
     );

def compare_files(
    original_file: str, formatted_file: str | None = None, auto_lint: bool = False
) {
    try {
        with open(original_file) as file {
            original_file_content = file.read();
        }
        if formatted_file is None {
            prog = JacProgram.jac_file_formatter(original_file, auto_lint=auto_lint);
            formatted_content = prog.mod.main.gen.jac;
        } else {
            with open(formatted_file) as file {
                formatted_content = file.read();
            }
        }
        diff = "\n".join(
            unified_diff(
                original_file_content.splitlines(),
                formatted_content.splitlines(),
                fromfile="original",
                tofile="formatted" if formatted_file is None else formatted_file,
            )
        );
        if diff {
            print(f"Differences found in comparison:\n{diff}");
            raise AssertionError("Files differ after formatting.");
        }
    } except FileNotFoundError {
        print(f"File not found: {original_file} or {formatted_file}");
        raise;
    } except Exception as e {
        print(f"Error comparing files: {e}");
        raise;
    }
}

def micro_suite_test(filename: str, auto_lint: bool = False) {
    code_gen_pure = JacProgram().compile(filename);
    format_prog = JacProgram.jac_file_formatter(filename, auto_lint=auto_lint);
    code_gen_format = format_prog.mod.main.gen.jac;
    code_gen_jac = JacProgram().compile(use_str=code_gen_format, file_path=filename);
    if "circle_clean_tests.jac" in filename {
        tokens = code_gen_format.split();
        num_test = 0;
        for i in range(len(tokens)) {
            if tokens[i] == "test" {
                num_test += 1;
                assert tokens[i + 1] == "{";
            }
        }
        assert num_test == 3;
        return;
    }
    before = "";
    after = "";
    try {
        before = ast3.dump(code_gen_pure.gen.py_ast[0], indent=2);
        after = ast3.dump(code_gen_jac.gen.py_ast[0], indent=2);
        assert isinstance(code_gen_pure, uni.Module)
        and isinstance(code_gen_jac, uni.Module) , "Parsed objects are not modules.";
        diff = "\n".join(unified_diff(before.splitlines(), after.splitlines()));
        assert not diff , "AST structures differ after formatting.";
    } except Exception as e {
        print(f"Error in {filename}: {e}");
        print(add_line_numbers(code_gen_pure.source.code));
        print("\n+++++++++++++++++++++++++++++++++++++++\n");
        print(add_line_numbers(code_gen_format));
        print("\n+++++++++++++++++++++++++++++++++++++++\n");
        if before and after {
            print("\n".join(unified_diff(before.splitlines(), after.splitlines())));
        }
        raise e;
    }
}

test "simple walk fmt" {
    compare_files(os.path.join(FIXTURES, "simple_walk_fmt.jac"));
}

test "tagbreak" {
    compare_files(os.path.join(FIXTURES, "tagbreak.jac"));
}

test "has fmt" {
    compare_files(os.path.join(FIXTURES, "has_frmt.jac"));
}

test "import fmt" {
    compare_files(os.path.join(FIXTURES, "import_fmt.jac"));
}

test "archetype" {
    compare_files(os.path.join(FIXTURES, "archetype_frmt.jac"));
}

test "lambda whitespace fmt" {
    compare_files(os.path.join(FIXTURES, "lambda_whitespace_fmt.jac"));
}

test "fstring comment not injected" {
    path = os.path.join(FIXTURES, "fstring_comment.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;
    lines = formatted.splitlines();

    # Check 1: Module-level comment must not end up inside an f-string
    assert "# Standalone comment" in formatted , "Module comment was lost";
    in_fstring = False;
    for line in lines {
        stripped = line.strip();
        if 'f"' in stripped or "f'" in stripped {
            in_fstring = True;
        }
        if in_fstring and "# Standalone comment" in line {
            raise AssertionError(
                "Comment was injected inside an f-string:\n" + formatted
            );
        }
        if in_fstring and '";' in stripped {
            in_fstring = False;
        }
    }

    # Check 2: Body-level comments must stay next to their statements
    before_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# Comment before" in ln
        ),
        None
    );
    fstring_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "function guard()" in ln
        ),
        None
    );
    after_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# Comment after" in ln
        ),
        None
    );
    assert before_idx is not None , "'# Comment before' was lost";
    assert fstring_idx is not None , "f-string statement was lost";
    assert after_idx is not None , "'# Comment after' was lost";
    assert before_idx < fstring_idx , (
        f"Comment before f-string was displaced after it "
        f"(comment at line {before_idx + 1}, f-string at line {fstring_idx + 1}):\n" + formatted
    );
    assert after_idx > fstring_idx , (
        f"Comment after f-string was displaced before it "
        f"(comment at line {after_idx + 1}, f-string at line {fstring_idx + 1}):\n" + formatted
    );

    # Check 3: Idempotency
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted2 = prog2.mod.main.gen.jac;
    assert formatted == formatted2 , "Formatting is not idempotent";
}

test "jsx hash text preserved" {
    path = os.path.join(FIXTURES, "jsx_hash_text.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;

    assert "# for client-side routing." in formatted , (
        "Hash-prefixed JSX text was lost:\n" + formatted
    );

    lines = formatted.splitlines();
    hash_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# for client-side routing." in ln
        ),
        None,
    );
    close_p_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "</p>" in ln
        ),
        None,
    );
    assert hash_idx is not None and close_p_idx is not None , (
        "Could not find hash text or </p> in formatted output:\n" + formatted
    );
    assert hash_idx < close_p_idx , (
        f"Hash text at line {hash_idx + 1} should be before </p> at "
        f"line {close_p_idx + 1}:\n" + formatted
    );

    # Idempotency
    prog2 = JacProgram.jac_file_formatter(path, auto_lint=True);
    assert formatted == prog2.mod.main.gen.jac , "Formatting is not idempotent";
}

"""Test that Unicode characters survive jac format --lintfix on Windows."""
test "unicode encoding write roundtrip" {
    import subprocess;

    path = os.path.join(FIXTURES, "unicode_encoding.jac");

    result = subprocess.run(
        ["jac", "format", path, "--lintfix"], capture_output=True, text=True
    );
    assert result.returncode == 0 , f"jac format failed: {result.stderr}";

    with open(path, 'r', encoding='utf-8') as f {
        content = f.read();
    }
    for char in ['●', '✅', '🚀', 'සාර්ථකයි', 'வெற்றி'] {
        assert char in content , f"Unicode char '{char}' lost after jac format";
    }
}

test "native block comments stay in place" {
    path = os.path.join(FIXTURES, "native_block_comment.jac");
    prog = JacProgram.jac_file_formatter(path);
    formatted = prog.mod.main.gen.jac;
    lines = formatted.splitlines();

    # Comments must appear between "na {" and its closing "}", not at end of file
    na_start = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if ln.strip().startswith("na {")
        ),
        None
    );
    assert na_start is not None , "na { not found in formatted output";
    # Find the matching closing brace at the same or lesser indentation
    na_indent = len(lines[na_start]) - len(lines[na_start].lstrip());
    na_end: int | None = None;
    for i in range(len(lines) - 1, na_start, -1) {
        if lines[i].strip() == "}"
        and (len(lines[i]) - len(lines[i].lstrip())) <= na_indent {
            na_end = i;
            break;
        }
    }
    assert na_end is not None , "closing } for na block not found in formatted output";
    comment_lines = [
        i
        for (i, ln) in enumerate(lines)
        if "# Comment inside native block" in ln or "# Another comment" in ln
    ];
    assert len(comment_lines) == 2 , f"Expected 2 comments, found {len(comment_lines)}";
    for cl in comment_lines {
        assert na_start < cl < na_end , (
            f"Comment at line {cl + 1} is outside the na block "
            f"(na: {na_start + 1}-{na_end + 1}):\n" + formatted
        );
    }

    # Idempotency
    prog2 = JacProgram.jac_file_formatter(path);
    formatted2 = prog2.mod.main.gen.jac;
    assert formatted == formatted2 , "Formatting of na {} block is not idempotent";
}

"""Regression: inline comment after a func-call argument swallowed the next
argument because the soft line break after the comma collapsed to a space."""
test "inline comment in func call args" {
    source = (
        'def foo -> None {\n'
        '    x = bar(\n'
        '        a[:-4],  # trim suffix\n'
        '        baz(y)\n'
        '    );\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    formatted = prog.mod.main.gen.jac;
    lines = formatted.splitlines();

    # The inline comment must NOT swallow the next argument
    comment_line = next(
        (
            ln
            for ln in lines
            if "# trim suffix" in ln
        ),
        None
    );
    assert comment_line is not None , "Inline comment was lost";
    assert "baz" not in comment_line , (
        "Next argument merged into comment line: " + repr(comment_line)
    );

    # baz(y) must appear on its own line
    baz_line = next(
        (
            ln
            for ln in lines
            if "baz(y)" in ln
        ),
        None
    );
    assert baz_line is not None , ("Second argument 'baz(y)' was lost:\n" + formatted);

    # Idempotency
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert formatted == prog2.mod.main.gen.jac , "Formatting is not idempotent";
}

"""Regression: JSX elements with only inline children (text/expression) and
lambda bodies with a single-statement `if` should stay flat when they fit
within the print width. Previously, both paths used `hard_line()` in their
DocIR generation which forced a break unconditionally, producing jarring
vertical expansion on compact JSX like `<button>Add</button>` and on
event-handler lambdas like `lambda e: T { if cond { stmt; } }`."""
test "jsx and lambda inline compact forms stay flat" {
    source = (
        'cl def:pub app -> JsxElement {\n'
        '    has text: str = "";\n'
        '\n'
        '    async def add {\n'
        '        text = "";\n'
        '    }\n'
        '\n'
        '    return\n'
        '        <div>\n'
        '            <input\n'
        '                value={text}\n'
        '                onKeyPress={lambda e: KeyboardEvent { if e.key == "Enter" { add(); }}}\n'
        '                placeholder="Add a todo..."\n'
        '            />\n'
        '            <button onClick={add}>Add</button>\n'
        '            <p>hello ({text})</p>\n'
        '        </div>;\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac;

    # JSX elements whose only children are text / expressions must stay on
    # one line when they fit. These exact single-line forms must survive.
    button_form = "<button onClick={add}>Add</button>";
    assert button_form in formatted , (
        "inline <button>Add</button> was split across lines:\n" + str(formatted)
    );
    p_form = "<p>hello ({text})</p>";
    assert p_form in formatted , (
        "inline <p>hello ({text})</p> was split across lines:\n" + str(formatted)
    );

    # A single-statement `if` inside a lambda body must stay flat.
    lambda_form = 'lambda e: KeyboardEvent { if e.key == "Enter" { add(); }}';
    assert lambda_form in formatted , (
        "lambda-nested `if { stmt; }` was expanded to multiple lines:\n" + str(
            formatted
        )
    );

    # Idempotency: formatting the formatted output must be a no-op.
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert not prog2.errors_had;
    assert formatted == prog2.mod.main.gen.jac , (
        "JSX/lambda inline formatting is not idempotent"
    );
}

"""Regression: top-level and multi-statement `if` blocks must still break —
the flat-capable rule is strictly scoped to single-statement, no-else `if`
statements whose direct parent is a `LambdaExpr`. Anywhere else, the
original hard-line layout must apply."""
test "if statement outside lambda still breaks" {
    source = (
        'def foo -> None {\n'
        '    if a { b(); }\n'
        '    if c {\n'
        '        d();\n'
        '        e();\n'
        '    }\n'
        '    f = lambda e: int { if e > 0 { x = 1; y = 2; } };\n'
        '    g = lambda e: int { if e > 0 { x = 1; } else { x = 2; } };\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted: str = prog.mod.main.gen.jac or "";
    assert formatted , "formatter produced empty output";
    lines = formatted.splitlines();

    # Top-level `if a { b(); }` must break — the opening brace and `b();`
    # must be on different lines.
    if_a_idx = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if ln.strip().startswith("if a {")
        ),
        None
    );
    assert if_a_idx is not None , f"top-level `if a` not found:\n{formatted}";
    assert "b();" not in lines[if_a_idx] , (
        f"top-level `if a {{ b(); }}` should have broken across lines:\n{formatted}"
    );

    # Multi-statement `if` inside lambda should NOT stay flat.
    assert "lambda e: int { if e > 0 { x = 1; y = 2; }" not in formatted , (
        f"multi-statement lambda `if` must fall back to hard-line layout:\n{formatted}"
    );

    # Lambda `if` with else should NOT stay flat.
    assert ("lambda e: int { if e > 0 { x = 1; } else { x = 2; } }") not in formatted , (
        f"lambda `if`/`else` must fall back to hard-line layout:\n{formatted}"
    );
}

"""Regression: JSX elements make two independent flat/break decisions —
one for the opening tag (attributes) and one for the children. There are
three buckets this test locks in:

    bucket A (fully inline): total flat form fits in the print width,
             so the whole element stays on one line.
    bucket B (opening tag inline, children broken): total doesn't fit
             but opening tag alone does, so the opening tag stays flat
             while the children indent onto their own lines.
    bucket C (fully broken): the opening tag itself doesn't fit, so
             attributes break one-per-line, `break_contiguous` forces
             the children to also break (no children inlined onto the
             same line as the closing `>` of the opening tag)."""
test "jsx attributes and children group independently" {
    source = (
        'cl def app -> JsxElement {\n'
        '    return\n'
        '        <div>\n'
        '            <h2 style={{color: "#dc2626"}}>Short</h2>\n'
        '            <p style={{color: "#374151", marginBottom: "16px"}}>An unexpected error occurred.</p>\n'
        '            <div\n'
        '                class="tweet-header"\n'
        '                style={{"fontWeight": "bold", "marginBottom": "8px"}}\n'
        '            >@{tweet.username}</div>\n'
        '        </div>;\n'
        '}\n'
    );
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac;

    # Bucket A: short h2 fits flat in total.
    bucket_a = '<h2 style={{color: "#dc2626"}}>Short</h2>';
    assert bucket_a in formatted , (
        "bucket A: short JSX element did not stay fully inline:\n" + str(formatted)
    );

    # Bucket B: opening tag of <p> fits inline even though total doesn't.
    # The opening tag must be on one line; the child text must be on an
    # indented line on its own; the closing tag on its own line.
    bucket_b_open = '<p style={{color: "#374151", marginBottom: "16px"}}>';
    assert bucket_b_open in formatted , (
        "bucket B: <p> opening tag was broken even though it fits:\n" + str(formatted)
    );
    assert "An unexpected error occurred." in formatted;
    # Child must NOT be glued to the opening `>` — confirm by checking the
    # child text is not on the same line as `<p style=...>`.
    for ln in formatted.splitlines() {
        if bucket_b_open in ln {
            assert "An unexpected" not in ln , (
                "bucket B: children were inlined on the opening-tag line "
                "instead of breaking:\n" + str(formatted)
            );
        }
    }

    # Bucket C: the tweet-header <div> has two attributes that together
    # push the opening tag past the print width, so attributes must break
    # one-per-line. `break_contiguous=True` on the children group then
    # forces the children onto their own indented line — the @{...} text
    # must NOT be inlined on the same line as the closing `>` of the
    # broken opening tag.
    for ln in formatted.splitlines() {
        # The closing `>` of the broken opening tag sits on its own line
        # (just whitespace + `>`) after a multi-line attribute list.
        if ln.strip() == ">" {
            continue;
        }
        assert not (ln.rstrip().endswith(">@{tweet.username}</div>")) , (
            "bucket C: children were inlined on the closing `>` of a "
            "multi-line opening tag:\n" + str(formatted)
        );
    }
    # Positive assertion: bucket C children land on their own line.
    assert "@{tweet.username}" in formatted;

    # Idempotency: all three shapes must round-trip.
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert not prog2.errors_had;
    assert formatted == prog2.mod.main.gen.jac , (
        "JSX attribute/children grouping is not idempotent"
    );
}

"""Regression: formatter must preserve `by <name>;` (bare genai ability
without parentheses) — previously both `by` and `;` were stripped."""
test "genai ability bare name preserves by and semicolon" {
    source = "def classify(s: str) -> str by llm;\n";
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac;
    assert "by" in formatted , (
        f"`by` keyword was stripped from genai ability:\n{repr(formatted)}"
    );
    assert formatted.rstrip().endswith(";") , (
        f"semicolon was stripped from genai ability:\n{repr(formatted)}"
    );
    assert "by llm;" in formatted , (
        f"expected `by llm;` in formatted output, got:\n{repr(formatted)}"
    );
    # Idempotency
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert formatted == prog2.mod.main.gen.jac , "genai bare-name formatting is not idempotent";
}

"""Regression: formatter must preserve `by <name>()` (genai ability with
empty parentheses) — both `by` and `()` must survive the format pass."""
test "genai ability empty parens preserves by and parens" {
    source = "def get_emoji(input: str) -> str by llm();\n";
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac;
    assert "by llm()" in formatted , (
        f"expected `by llm()` in formatted output, got:\n{repr(formatted)}"
    );
    # Idempotency
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert formatted == prog2.mod.main.gen.jac , "genai empty-parens formatting is not idempotent";
}

"""Regression: formatter must preserve `by <name>(kwargs)` (genai ability
with keyword arguments) — the full argument list must survive the format pass."""
test "genai ability with kwargs preserves by and arguments" {
    source = "def get_emoji(input: str) -> str by llm(temperature=0.7, incl_info={\"examples\": emoji_examples});\n";
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac;
    assert "by llm(" in formatted , (
        f"expected `by llm(` in formatted output, got:\n{repr(formatted)}"
    );
    assert "temperature=0.7" in formatted , (
        f"expected `temperature=0.7` in formatted output, got:\n{repr(formatted)}"
    );
    assert "incl_info=" in formatted , (
        f"expected `incl_info=` in formatted output, got:\n{repr(formatted)}"
    );
    # Idempotency
    prog2 = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert formatted == prog2.mod.main.gen.jac , "genai kwargs formatting is not idempotent";
}

"""Regression: jac_str_formatter must populate errors_had on syntax error
so that the LSP returns the original source instead of an empty string."""
test "syntax error preserves original source" {
    bad_source = "obj Foo { has x: int = ; }";  # invalid syntax
    prog = JacProgram.jac_str_formatter(source_str=bad_source, file_path="<test>.jac");
    # Must report errors
    assert len(prog.errors_had) > 0 , (
        "jac_str_formatter must populate errors_had on syntax error"
    );
    # gen.jac will be empty since no format passes ran
    gen_output = prog.mod.main.gen.jac;
    # Simulate the LSP formatted_jac() logic:
    # return formatted if no errors, else return original source
    result = gen_output if not prog.errors_had else bad_source;
    assert result == bad_source , (
        "Formatter must return original source on syntax error, " f"got: {repr(result)}"
    );
}
