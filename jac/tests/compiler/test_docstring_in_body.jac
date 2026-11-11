"""A docstring inside a body: one E0111 when it runs into the next line (#10692)."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob VIRTUAL_PATH: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "fixtures", "_docstring_inline.jac"
     ),
     RETURN_HINT: str = "so it is the body's return value";

def compile_source(source: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=VIRTUAL_PATH, use_str=source, options=CompileOptions(no_cgen=True)
    );
    return prog;
}

def errors_of(prog: JacProgram) -> list[tuple[str, int]] {
    return [
        (alrt.code.code, alrt.loc.first_line)
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
}

def warning_codes_of(prog: JacProgram) -> list[str] {
    return [
        alrt.code.code
        for alrt in prog.warnings_had
        if alrt.code is not None
    ];
}

def hint_of(prog: JacProgram, code: str) -> str {
    for alrt in prog.errors_had + prog.warnings_had {
        if alrt.code is not None and alrt.code.code == code {
            return alrt.help_text or "";
        }
    }
    return f"no {code}";
}

def in_function(body: str) -> str {
    return f"def f(x: int) -> None {{\n    {body}\n}}\n";
}

test "a docstring with no ';' is one E0111, whatever the next line is" {
    for next_line in [
        "y = x * 2;",
        "if x > 0 {\n        print(x);\n    }",
        "if x > 0 {\n        print(x);\n    } else {\n        print(0);\n    }",
        "(a, b) = (x, 2);",
        "-x;",
        "[x, 1];",
        "[0];",
        "print(x);",
        "for i in range(x) {\n        print(i);\n    }",
        "return;"
    ] {
        prog = compile_source(in_function('"""Doc."""\n    ' + next_line));
        got = errors_of(prog);
        assert got == [("E0111", 2)] , f"{next_line!r}: {got}";
        assert "W0060" not in warning_codes_of(prog) , next_line;
    }
}

test "E0111 is reported in every kind of body" {
    if_x = "\n    if x > 0 {\n        print(x);\n    }";
    bodies = {
        "method": 'obj Calc {\n    has n: int = 0;\n\n    def double -> int {\n        """Doc."""\n        if self.n > 0 {\n            return self.n * 2;\n        }\n        return 0;\n    }\n}\n',
        "walker ability": 'walker W {\n    can go with Root entry {\n        """Doc."""\n        if True {\n            print(1);\n        }\n    }\n}\n',
        "with entry": 'with entry {\n    """Doc."""\n    if 1 > 0 {\n        print(1);\n    }\n}\n',
        "impl": 'obj A {\n    def m -> int;\n}\n\nimpl A.m -> int {\n    """Doc."""\n    if True {\n        return 1;\n    }\n    return 0;\n}\n',
        "lambda": 'with entry {\n    g = lambda (x: int) -> int {\n        """Doc."""\n        if x > 0 {\n            return x;\n        }\n        return 0;\n    };\n    print(g(1));\n}\n',
        "nested def": 'def outer(x: int) -> int {\n    def inner(y: int) -> int {\n        """Doc."""\n        if y > 0 {\n            return y;\n        }\n        return 0;\n    }\n    return inner(x);\n}\n',
        "client component": 'def:pub App() -> JsxElement {\n    """Doc."""\n    if True {\n        print(1);\n    }\n    return <div>hi</div>;\n}\n',
        "single-quoted": in_function('"Doc."' + if_x),
        "raw prefix": in_function('r"""Doc."""' + if_x),
        "two strings": in_function('"""Doc."""\n    """More."""' + if_x),
        "a comment after": in_function('"""Doc."""  # a note\n    # another' + if_x),
        "a lambda in a wrapped ternary": 'def label(x: int) -> str {\n    "positive"\n    if (lambda (y: int) -> bool {\n        """Doc."""\n        if y > 0 {\n            return True;\n        }\n        return False;\n    })(x)\n    else "other"\n}\n'
    };
    for (kind, source) in bodies.items() {
        got = errors_of(compile_source(source));
        assert [code for (code, _) in got] == ["E0111"] , f"{kind}: {got}";
    }
}

test "nested wrapped ternaries are checked once per level" {
    ternaries = "0";
    statements = "0";
    for _ in range(40) {
        ternaries = f'(lambda {{ "yes"\n if True\n else {ternaries} }})';
        statements = f'(lambda {{ "Doc."\n if (lambda {{ {statements} }})() {{ print(1); }} return 0; }})';
    }
    assert errors_of(compile_source(f"with entry {{\n    f = {ternaries};\n}}\n"))
        == [];
    got = errors_of(compile_source(f"with entry {{\n    f = {statements};\n}}\n"));
    assert [code for (code, _) in got] == ["E0111"] * 40 , got;
}

test "a string that is a statement, a docstring target or an expression is not E0111" {
    sources = {
        "with ';'": in_function('"""Doc.""";\n    print(x);'),
        "before a nested def": 'def outer -> int {\n    """Doc."""\n    def inner -> int {\n        return 1;\n    }\n    return inner();\n}\n',
        "a wrapped ternary": 'def label(x: int) -> str {\n    "positive"\n    if x > 0\n    else "non-positive"\n}\n',
        "a wrapped ternary in a lambda": 'with entry {\n    pick = lambda (name: str) { "/usr/bin/g++"\n        if name == "g++"\n        else None; };\n    print(pick("g++"));\n}\n',
        "a wrapped concatenation": 'def f(x: int) -> str {\n    "total: "\n    + str(x)\n}\n',
        "a method call": 'def f(x: int) -> str {\n    ", "\n    .join([str(x), "a"])\n}\n',
        "an implicit return": 'def name -> str {\n    "Bob"\n}\n',
        "a # comment": in_function("# Doc.\n    print(x);")
    };
    for (kind, source) in sources.items() {
        prog = compile_source(source);
        assert errors_of(prog) == [] , f"{kind}: {errors_of(prog)}";
        if kind == "with ';'" {
            assert "W0060" in warning_codes_of(prog);
        }
    }
}

test "a body that is only a docstring says the string is returned" {
    only_doc = '"""Doc."""';
    assert RETURN_HINT in hint_of(compile_source(in_function(only_doc)), "E1002");
    assert RETURN_HINT
        in hint_of(compile_source('def f(x: int) {\n    """Doc."""\n}\n'), "E1003");
    assert RETURN_HINT
        in hint_of(
            compile_source(
                'obj A {\n    def m -> None;\n}\n\nimpl A.m -> None {\n    """Doc."""\n}\n'
            ),
            "E1002"
        );
    assert RETURN_HINT
        in hint_of(
            compile_source(
                'walker W {\n    can go with Root entry {\n        """Doc."""\n    }\n}\n'
            ),
            "W2014"
        );
    assert RETURN_HINT
        not in hint_of(compile_source(in_function('print(x);\n    "done"')), "E1002");
    assert errors_of(compile_source('def f(x: int) -> str {\n    """Doc."""\n}\n'))
        == [];
}
