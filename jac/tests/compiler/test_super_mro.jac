"""`super` resolves against the whole MRO, not just the first base.

`super.member` was typed as the class at mro[1] -- the first base only. Under
multiple inheritance the member usually lives further along, so the lookup
reported "has no attribute" for a member that is plainly inherited, or matched
a same-named method on the wrong class and complained about its parameters.

Both shapes showed up in real code: langserve's JacLangServer(JacProgram,
LanguageServer) calling super.shutdown(), and llvm's
SwitchInstr(PredictableInstr, Terminator) calling super.init -- where
PredictableInstr declares no init, so the real C3 next-with-init is
Terminator's three-parameter one, not Instruction's five.
"""

import from jaclang.compiler.session.session { JacProgram }
import from jaclang.compiler.session.options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="supermro.jac", use_str=src, options=CompileOptions(no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "super reaches a member declared on a later base" {
    src = "obj A { def hello -> str { return 'a'; } }\n"
        + "obj B { def bye -> str { return 'b'; } }\n"
        + "obj C(A, B) { def bye -> str { return super.bye(); } }\n";
    errs = check_src(src);
    assert not errs , f"super missed a later base: {errs}";
}

test "super init picks the next class that declares it" {
    src = "class P {\n"
        + "    def init(self: P, x: int, y: int, z: int, w: int) -> None {\n"
        + "        self.x = x;\n"
        + "    }\n"
        + "}\n"
        + "class Q(P) {\n"
        + "    def init(self: Q, p: int, q: int, r: int) -> None {\n"
        + "        super.init(p, q, r, 0);\n"
        + "    }\n"
        + "}\n"
        + "class R(P) {}\n"
        + "class S(R, Q) {\n"
        + "    def init(self: S) -> None {\n"
        + "        super.init(1, 2, 3);\n"
        + "    }\n"
        + "}\n";
    errs = check_src(src);
    assert not errs , f"super init resolved to the wrong class: {errs}";
}
