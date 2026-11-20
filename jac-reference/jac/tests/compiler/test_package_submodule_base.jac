"""A package segment of a dotted import resolves to that package.

`import a.b` binds `a`. Resolving the import walked its segments but returned
the *last* one's type, so the bound name `a` was handed the type of `a.b` --
and a package segment was skipped outright, never getting a module type at all.

Either way `a` came out Unknown, so `a.b.C` was unresolvable. As a base class
that is silent: MRO linearization drops any base that is not a class, so the
subclass simply loses every inherited member, and the "has no attribute"
diagnostic then reports a definite negative about members that plainly exist.

Typeshed writes exactly this shape -- `class MIMEBase(email.message.Message)`
and `class TextTestResult(unittest.result.TestResult, ...)`.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="pkgbase.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "members inherited through a package-qualified base stay visible" {
    src = "import from email.mime.multipart { MIMEMultipart }\n"
        + "import from email.mime.text { MIMEText }\n"
        + "def probe -> str {\n"
        + "    msg = MIMEMultipart('alternative');\n"
        + "    msg.attach(MIMEText('hi', 'plain'));\n"
        + "    return msg.as_string();\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"package-qualified base lost its members: {errs}";
}

test "a package segment of a dotted import resolves to the package" {
    src = "import email.message;\n"
        + "def probe(m: email.message.Message) -> str {\n"
        + "    return m.as_string();\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"package segment unresolved: {errs}";
}

test "a namespace package resolves without an __init__" {
    src = "import xml.etree.ElementTree;\n"
        + "def probe(s: str) -> None {\n"
        + "    parsed = xml.etree.ElementTree.fromstring(s);\n"
        + "    assert parsed is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"package segment unresolved: {errs}";
}
