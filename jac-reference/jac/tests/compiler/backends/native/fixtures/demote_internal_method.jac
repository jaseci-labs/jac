"""A method call into a jaclang-internal module, verdict-bound or refused.

`CodeGenTarget` lives in `compiler/frontend/codeinfo.jac`, a jaclang-internal module
no seal closure admits, and `doc_ir`'s accessor is one of its thirteen
recorded seams. A consumer method reading it is the methods-side twin of
the free-function trust hole: if the consumer's emission ever ran ahead of
the callee module's verdict, the accessor's rename-and-pop would leave a
dangling declaration in the linked unit. The suite compiles this as a
native root and asserts the unit resolves every symbol it declares -- the
consumer either learns the verdict and demotes honestly, or the module
never joins and the call refuses by name; neither may dangle.
"""

import from jaclang.compiler.frontend.codeinfo { CodeGenTarget }

obj InternalProbe {
    has hits: int = 0;

    def read_docir(t: CodeGenTarget) -> int {
        d = t.doc_ir;
        self.hits += 1;
        return 1 if d is not None else 0;
    }
}

def probe_ok(n: int) -> int {
    return n * 2;
}
