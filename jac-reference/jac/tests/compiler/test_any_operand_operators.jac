"""An operator with an Any operand yields Any instead of reporting.

Any absorbs whatever is done to it -- that is the whole point of a gradual
type. Binary dispatch had no short-circuit for it, so `c + xs` tried
`Any.__add__`, failed, then tried the reflected `list.__radd__`, and reported.
It only appeared to work when the other operand happened to define a
reflected method: `c + 1` passed because int has __radd__, while `c + "s"`
and `c + [..]` did not.

Augmented assignment had the same hole guarded separately -- it skipped
Unknown operands but not Any -- so `c += (..)` reported E1011.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="anyop.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "an Any operand absorbs a binary operator" {
    src = "def probe(c: any, xs: list[str], s: str) -> None {\n"
        + "    a = c + xs;\n"
        + "    b = c + s;\n"
        + "    d = xs + c;\n"
        + "    assert a is not None and b is not None and d is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"Any operand rejected by binary operator: {errs}";
}

test "an Any target absorbs an augmented assignment" {
    src = "def probe(c: any) -> None {\n"
        + "    g: any = c;\n"
        + "    g += ('x', 'y');\n"
        + "    assert g is not None;\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"Any target rejected by augmented assignment: {errs}";
}
