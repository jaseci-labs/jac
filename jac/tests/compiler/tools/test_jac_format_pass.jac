"""Jac format pass tests – migrated from test_jac_format_pass.py.

Tests that the Jac formatter produces correct output: fixture comparisons,
AST preservation, micro suite round-trip, and regression tests.
"""

import os;
import from difflib { unified_diff }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "tools", "fixtures");

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

# Format `source`, require no errors, and require a second format to change nothing.
def fmt_checked(source: str) -> str {
    prog = JacProgram.jac_str_formatter(source_str=source, file_path="<test>.jac");
    assert not prog.errors_had , f"formatter errors: {prog.errors_had}";
    formatted = prog.mod.main.gen.jac or "";
    again = JacProgram.jac_str_formatter(source_str=formatted, file_path="<test>.jac");
    assert not again.errors_had , f"formatter errors on re-format: {again.errors_had}";
    assert formatted == again.mod.main.gen.jac , f"formatting is not idempotent:\n{formatted}";
    return formatted;
}

# Fixtures the formatter must leave byte-for-byte unchanged. connect_op_fmt.jac
# keeps typed connect operators compact, like the traversal edge ops.
glob SELF_FORMATTING_FIXTURES: list[str] = [
         "simple_walk_fmt.jac",
         "tagbreak.jac",
         "connect_op_fmt.jac",
         "has_frmt.jac",
         "import_fmt.jac",
         "archetype_frmt.jac",
         "lambda_whitespace_fmt.jac",
         "implicit_return_fmt.jac",
         "forever_fmt.jac",
         "awaiting_fmt.jac",
         "awaiting_jsx_fmt.jac"
     ];

test "each formatter fixture formats to itself" {
    changed: list[str] = [];
    for name in SELF_FORMATTING_FIXTURES {
        try {
            compare_files(os.path.join(FIXTURES, name));
        } except AssertionError {
            changed.append(name);
        }
    }
    assert not changed , f"fixtures changed by formatting: {changed}";
}

# (case, source, text the output must contain, text it must not contain)
glob SOURCE_CASES: list[tuple[str, str, list[str], list[str]]] = [
         (
             "visit insertion position compact fmt",
             "walker Walk { can step with Root entry { "
             "visit : 0 : [-->]; visit : -1 : [-->] else { disengage; } "
             "visit : 1 + 2 : [-->]; visit [-->]; } }",
             [
                 "visit:0: [-->];",
                 "visit:-1: [-->] else {",
                 "visit:1 + 2: [-->];",
                 "visit [-->];"
             ],
             []
         ),
         (
             "graph filter membership keeps keyword spacing",
             'node Item { has name: str; }\n\nwith entry {\n'
             'items = [root-->[?:Item, name in ("a", "b")]];\n}\n',
             ["name in "],
             []
         ),
         (
             "empty blocks format without inner space",
             'obj Empty {}\n\nobj HasM {\n    def m;\n}\n\nimpl HasM.m {}\n\n'
             'walker W {\n    can go with Root entry {}\n}\n\ndef multi {}\n\n'
             'def branches(x: int) {\n    if x > 0 {} else {}\n    while False {}\n'
             '    for i in range(1) {}\n    try {} except Exception {} finally {}\n}\n\n'
             'test {}\n\nwith entry {}\n',
             [
                 "obj Empty {}",
                 "impl HasM.m {}",
                 "can go with Root entry {}",
                 "def multi {}",
                 "if x > 0 {} else {}",
                 "while False {}",
                 "for i in range(1) {}",
                 "try {} except Exception {} finally {}",
                 "test {}",
                 "with entry {}"
             ],
             ["{ }"]
         ),
         # Inline-only JSX children and a lambda's single-statement `if` stay flat.
         (
             "jsx and lambda inline compact forms stay flat",
             'def:pub app -> JsxElement {\n    has text: str = "";\n\n'
             '    async def add {\n        text = "";\n    }\n\n    return\n'
             '        <div>\n            <input\n                value={text}\n'
             '                onKeyPress={lambda (e: KeyboardEvent) { if e.key == "Enter" { add(); }}}\n'
             '                placeholder="Add a todo..."\n            />\n'
             '            <button onClick={add}>Add</button>\n'
             '            <p>hello ({text})</p>\n        </div>;\n}\n',
             [
                 "<button onClick={add}>Add</button>",
                 "<p>hello ({text})</p>",
                 'lambda (e: KeyboardEvent) { if e.key == "Enter" { add(); }}'
             ],
             []
         ),
         # Statement-form `{...}` slots keep their syntax; the view lowering never leaks.
         (
             "JSX slot statement bodies round-trip through the formatter",
             'def:pub Greeting(name: str) -> JsxElement {\n    return <div>\n'
             '        {if name == "" {\n            <p>anon</p>\n        } else {\n'
             '            <h1>Hello, {name}</h1>\n        }}\n    </div>;\n}\n',
             ["{if name", "} else {"],
             ["__jac_view_kids"]
         ),
         (
             "dynamic JSX tags round-trip through the formatter",
             'def:pub Box(as_: str, children: any = None) -> JsxElement {\n'
             '    return <@as_ class="box">{children}</@as_>;\n}\n\n'
             'def:pub Icon(glyph: type) -> JsxElement {\n'
             '    return <@{glyph} class="icon"/>;\n}\n',
             ["<@as_", "</@as_>", "<@{glyph}"],
             []
         ),
         # A JSX `return` that fits the print width stays on the `return` line.
         (
             "return jsx stays on one line when it fits",
             'def:pub AlertDialog(props: any) -> JsxElement {\n    return\n'
             '        <AlertDialogPrimitive.Root data-slot="alert-dialog" {**props}/>;\n}\n\n'
             'def:pub Greeting -> JsxElement {\n    return\n        <p>Hello</p>;\n}\n',
             [
                 'return <AlertDialogPrimitive.Root data-slot="alert-dialog" {**props}/>;',
                 "return <p>Hello</p>;"
             ],
             []
         ),
         # `by <name>()` and `by <name>(kwargs)` survive the format pass.
         (
             "genai ability empty parens preserves by and parens",
             "def get_emoji(input: str) -> str by llm();\n",
             ["by llm()"],
             []
         ),
         (
             "genai ability with kwargs preserves by and arguments",
             "def get_emoji(input: str) -> str by llm(temperature=0.7, incl_info={\"examples\": emoji_examples});\n",
             ["by llm(", "temperature=0.7", "incl_info="],
             []
         ),
         # Set literals and assign comprehensions space after commas like lists do.
         (
             "set literal spaces after commas like other collections",
             "glob a = {1,2,3};\n",
             ["{1, 2, 3}"],
             []
         ),
         (
             "assign comprehension spaces after commas like filter comprehension",
             "with entry { x = (a)(=foo=1,bar=2); }\n",
             ["=foo=1, bar=2"],
             []
         ),
         # Enum bases space like type annotations and base-class lists.
         (
             "enum base type colon and parens space correctly",
             'enum Category: int { WORK, PERSONAL }\nenum Color(Mixin, Enum) { RED, GREEN }\n',
             ["enum Category: int", "enum Color(Mixin, Enum)"],
             ["Category : int"]
         ),
         (
             "short binary chains stay flat",
             'with entry {\n    x = 1 + 2 + 3;\n    y = x < 10;\n}\n',
             ["x = 1 + 2 + 3;", "y = x < 10;"],
             []
         )
     ];

test "each source case formats to its expected text, idempotently" {
    failed: list[str] = [];
    for (label, source, present, absent) in SOURCE_CASES {
        try {
            formatted = fmt_checked(source);
            missing = [
                s
                for s in present
                if s not in formatted
            ];
            leaked = [
                s
                for s in absent
                if s in formatted
            ];
            assert not missing and not leaked , (
                f"missing {missing}, unexpected {leaked}:\n{formatted}"
            );
        } except AssertionError as err {
            failed.append(f"{label}: {err}");
        }
    }
    assert not failed , "\n".join(failed);
}

# An inline comment after a call argument must not swallow the next argument.
test "inline comment in func call args" {
    formatted = fmt_checked(
        'def foo -> None {\n    x = bar(\n        a[:-4],  # trim suffix\n'
        '        baz(y)\n    );\n}\n'
    );
    lines = formatted.splitlines();
    comment_line = next(
        (
            ln
            for ln in lines
            if "# trim suffix" in ln
        ),
        None
    );
    assert comment_line is not None , "Inline comment was lost";
    assert "baz" not in comment_line , f"Next argument merged into comment line: {comment_line!r}";
    assert any("baz(y)" in ln for ln in lines) , f"Second argument 'baz(y)' was lost:\n{formatted}";
}

# A JSX `return` that does not fit drops the element onto its own line.
test "return jsx breaks when it does not fit" {
    formatted = fmt_checked(
        'def:pub Big(props: any) -> JsxElement {\n'
        '    return <AlertDialogPrimitive.Overlay {**props} '
        'data-slot="alert-dialog-overlay" '
        'className={cn("a-very-long-class-name-string-that-blows-past-print-width", '
        'props["className"])}/>;\n}\n\n'
        'def:pub Tree -> JsxElement {\n'
        '    return <div><span>a</span><span>b</span></div>;\n}\n'
    );
    assert not any(
        ln.strip().startswith("return <") for ln in formatted.splitlines()
    ) , (f"overflowing JSX return must break onto its own line:\n{formatted}");
    assert "<span>a</span>" in formatted and "<span>b</span>" in formatted , formatted;
}

# Only a lambda's single-statement, no-else `if` may stay flat; other `if`s break.
test "if statement outside lambda still breaks" {
    formatted = fmt_checked(
        'def foo -> None {\n    if a { b(); }\n    if c {\n        d();\n        e();\n    }\n'
        '    f = lambda (e: int) { if e > 0 { x = 1; y = 2; } };\n'
        '    g = lambda (e: int) { if e > 0 { x = 1; } else { x = 2; } };\n}\n'
    );
    assert formatted , "formatter produced empty output";
    if_a = next(
        (
            ln
            for ln in formatted.splitlines()
            if ln.strip().startswith("if a {")
        ),
        None
    );
    assert if_a is not None , f"top-level `if a` not found:\n{formatted}";
    assert "b();" not in if_a , f"top-level `if a {{ b(); }}` should have broken:\n{formatted}";
    assert "lambda (e: int) { if e > 0 { x = 1; y = 2; }" not in formatted , formatted;
    assert "lambda (e: int) { if e > 0 { x = 1; } else { x = 2; } }"
        not in formatted , formatted;
}

# A JSX element decides flat or broken separately for its opening tag and its children.
test "jsx attributes and children group independently" {
    formatted = fmt_checked(
        'def app -> JsxElement {\n    return\n        <div>\n'
        '            <h2 style={{color: "#dc2626"}}>Short</h2>\n'
        '            <p style={{color: "#374151", marginBottom: "16px"}}>An unexpected error occurred.</p>\n'
        '            <div\n                class="tweet-header"\n'
        '                style={{"fontWeight": "bold", "marginBottom": "8px"}}\n'
        '            >@{tweet.username}</div>\n        </div>;\n}\n'
    );
    lines = formatted.splitlines();
    # A: fits whole. B: the opening tag fits, the children break. C: the tag breaks too.
    assert '<h2 style={{color: "#dc2626"}}>Short</h2>' in formatted , formatted;
    p_open = '<p style={{color: "#374151", marginBottom: "16px"}}>';
    assert p_open in formatted
        and "An unexpected error occurred." in formatted , formatted;
    assert not any(p_open in ln and "An unexpected" in ln for ln in lines) , formatted;
    assert not any(
        ln.rstrip().endswith(">@{tweet.username}</div>") for ln in lines
    ) , formatted;
    assert "@{tweet.username}" in formatted , formatted;
}

# `by <name>;` keeps both the `by` and the closing semicolon.
test "genai ability bare name preserves by and semicolon" {
    formatted = fmt_checked("def classify(s: str) -> str by llm;\n");
    assert "by llm;" in formatted and formatted.rstrip().endswith(";") , repr(
        formatted
    );
}

# A set literal wider than the print width breaks one element per line.
test "long set literal wraps one element per line like a list" {
    formatted = fmt_checked(
        'glob a = {"alpha","bravo","charlie","delta","echo","foxtrot",'
        '"golf","hotel","india","juliet","kilo","lima"};\n'
    );
    lines = formatted.splitlines();
    assert len(lines) > 3 , f"long set literal must break across lines:\n{formatted}";
    assert not any('"alpha"' in ln and '"bravo"' in ln for ln in lines) , formatted;
}

# Spaces between JSX text and inline elements are significant: short mixed JSX
# stays flat, and long mixed JSX keeps them as `{" "}` markers when it breaks.
test "jsx significant whitespace around inline elements is preserved" {
    short_fmt = fmt_checked(
        'def:pub hud -> JsxElement {\n'
        '    return <div id="hud">score <b>0</b> · <b>0</b> fps</div>;\n}\n'
    );
    assert '<div id="hud">score <b>0</b> · <b>0</b> fps</div>' in short_fmt , short_fmt;
    long_fmt = fmt_checked(
        'def:pub hint -> JsxElement {\n'
        '    return <div id="hint">Click the canvas to capture the mouse · '
        '<b>WASD</b> move and mouse aim · <b>Space</b> fire · <b>Tab</b> release the '
        'cursor</div>;\n}\n'
    );
    assert "\n" in long_fmt.split("return")[1].split(";")[0] , long_fmt;
    assert '{" "}' in long_fmt , long_fmt;
    assert "move ·" in long_fmt
        or 'move ·{" "}' in long_fmt
        or "move\n" not in long_fmt , long_fmt;
}

# Binary, compare and match-or chains break one operand per line, operator first.
test "long plus chain breaks one operand per line" {
    formatted = fmt_checked(
        'def cat(tail: str) -> str {\n    return (\n'
        '        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\n'
        '        + "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"\n'
        '        + "cccccccccccccccccccccccccccccccccccccccccccc"\n'
        '        + tail\n    );\n}\n'
    );
    lines = formatted.splitlines();
    assert all(len(ln) <= 88 for ln in lines) , formatted;
    assert not any('"aaaa' in ln and '"bbbb' in ln for ln in lines) , formatted;
    assert any(ln.lstrip().startswith('+ "bbbb') for ln in lines) , formatted;
    # The parens own the indent, so operands stay at 8 spaces.
    assert any(ln.startswith('        + "bbbb') for ln in lines) , formatted;
}

test "bare chain continuation indents one level" {
    formatted = fmt_checked(
        'with entry {\n    out = "start";\n'
        '    out += "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\n'
        '    + "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"\n'
        '    + "cccccccccccccccccccccccccccccccccccc";\n}\n'
    );
    lines = formatted.splitlines();
    assert any(ln.startswith('        + "bbbb') for ln in lines) , formatted;
    assert not any(ln.startswith('+ "bbbb') for ln in lines) , formatted;
}

test "mixed precedence chain keeps tighter subexpression intact" {
    formatted = fmt_checked(
        'def mix(aaaaaaaaaaaaaaaaaaaaaaaaaaaa: int, bbbbbbbbbbbbbbbbbbbb: int,'
        ' cccccccccccccccccccc: int, dddddddddddddddddddd: int) -> int {\n'
        '    return (\n        aaaaaaaaaaaaaaaaaaaaaaaaaaaa\n'
        '        + bbbbbbbbbbbbbbbbbbbb * cccccccccccccccccccc\n'
        '        + dddddddddddddddddddd\n    );\n}\n'
    );
    lines = formatted.splitlines();
    assert all(len(ln) <= 88 for ln in lines) , formatted;
    assert any(
        "bbbbbbbbbbbbbbbbbbbb * cccccccccccccccccccc" in ln for ln in lines
    ) , formatted;
}

test "long comparison chain breaks one operand per line" {
    formatted = fmt_checked(
        'def cmp(aaaaaaaaaaaaaaa: int, bbbbbbbbbbbbbbb: int,'
        ' ccccccccccccccc: int, ddddddddddddddd: int) -> bool {\n'
        '    return (\n        aaaaaaaaaaaaaaa < bbbbbbbbbbbbbbb < ccccccccccccccc'
        ' < ddddddddddddddd < aaaaaaaaaaaaaaa\n    );\n}\n'
    );
    lines = formatted.splitlines();
    assert all(len(ln) <= 88 for ln in lines) , formatted;
    assert any(ln.lstrip().startswith("< ") for ln in lines) , formatted;
}

test "long match-or pattern breaks one alternative per line" {
    formatted = fmt_checked(
        'def pick(x: str) -> str {\n    match x {\n'
        '        case "aaaaaaaaaaaaaaaaaaaaaaaa" | "bbbbbbbbbbbbbbbbbbbbbbbb"'
        ' | "cccccccccccccccccccccccc" | "dddddddddddddddddddddddd":\n'
        '            return "hit";\n        case _:\n            return "miss";\n    }\n}\n'
    );
    lines = formatted.splitlines();
    assert all(len(ln) <= 88 for ln in lines) , formatted;
    assert not any('"aaaa' in ln and '"bbbb' in ln for ln in lines) , formatted;
}

test "forever keyword preserved not rewritten" {
    path = os.path.join(FIXTURES, "forever_fmt.jac");
    prog = JacProgram.jac_file_formatter(path, auto_lint=True);
    formatted = prog.mod.main.gen.jac;
    assert "forever {" in formatted;
    assert "while" not in formatted;
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
    before_idx: any = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# Comment before" in ln
        ),
        None
    );
    fstring_idx: any = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "function guard()" in ln
        ),
        None
    );
    after_idx: any = next(
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
        "Comment before f-string was displaced after it "
        f"(comment at line {before_idx + 1}, f-string at line {fstring_idx + 1}):\n"
        + formatted
    );
    assert after_idx > fstring_idx , (
        "Comment after f-string was displaced before it "
        f"(comment at line {after_idx + 1}, f-string at line {fstring_idx + 1}):\n"
        + formatted
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
    hash_idx: any = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if "# for client-side routing." in ln
        ),
        None,
    );
    close_p_idx: any = next(
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
        f"line {close_p_idx + 1}:\n"
        + formatted
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
        ["jac", "fmt", path, "--lintfix"], capture_output=True, text=True
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

    # Comments must appear between "obj Ops {" and its closing "}", not at EOF
    na_start: any = next(
        (
            i
            for (i, ln) in enumerate(lines)
            if ln.strip().startswith("obj Ops {")
        ),
        None
    );
    assert na_start is not None , "obj Ops { not found in formatted output";
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
    assert na_end is not None , "closing } for obj block not found in formatted output";
    comment_lines = [
        i
        for (i, ln) in enumerate(lines)
        if "# Comment inside native block" in ln or "# Another comment" in ln
    ];
    assert len(comment_lines) == 2 , f"Expected 2 comments, found {len(comment_lines)}";
    for cl in comment_lines {
        assert na_start < cl < na_end , (
            f"Comment at line {cl + 1} is outside the obj block "
            f"(obj: {na_start + 1}-{na_end + 1}):\n"
            + formatted
        );
    }

    # Idempotency
    prog2 = JacProgram.jac_file_formatter(path);
    formatted2 = prog2.mod.main.gen.jac;
    assert formatted == formatted2 , "Formatting of the obj block is not idempotent";
}

"""Regression (#7495): comment-dense adjacent JSX blocks exercise shared IfBreak
DocIR children; comment placement must stay byte-idempotent across a re-format
with no duplicated or misattributed comments. Loads the fixture via its real
fixtures/ path so the deslop lint rule is excluded and the comments are kept."""
test "comment placement idempotent on comment-dense blocks" {
    path = os.path.join(FIXTURES, "comment_dedup_regression.jac");
    out1 = JacProgram.jac_file_formatter(path, auto_lint=True).mod.main.gen.jac;
    out2 = JacProgram.jac_str_formatter(
        source_str=out1, file_path=path, auto_lint=True
    ).mod.main.gen.jac;
    assert out1 == out2 , (
        "comment placement is not idempotent -- comments duplicated or "
        "misplaced across a re-format:\n"
        + out1
    );
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
