"""A block-bodied lambda sees the narrowing of the variables it captures.

`CFGBuildPass` linked a nested `def` body into the flow at its definition site
(`exit_ability`), so `if b is not None { def g { b.n } }` type-checked. A lambda
with a statement body had no such link: its first statement had no
predecessor, the flow walk stopped there, and the read fell back to the
declared `Box | None` (E1099), while the same body written as a nested `def`
passed. Lambda bodies are now linked like nested functions, and an edge into
a nested lambda body no longer counts as the enclosing statement's exit, so
the statements after a branch that only defines a lambda keep that branch as
a predecessor.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "lambda_captured_narrowing.jac"
     );

"""Type-check the fixture and return the lines its errors point at."""
def error_lines -> list[int] {
    prog = JacProgram();
    prog.compile(file_path=FIXTURE, options=CompileOptions(no_cgen=True));
    return sorted([e.loc.first_line for e in (prog.errors_had or [])]);
}

test "a guarded lambda and a nested def both see the narrowed capture" {
    lines = error_lines();
    assert 12 not in lines , lines;
    assert 22 not in lines , lines;
}

test "an unguarded lambda and the merge after a lambda-only branch still error" {
    lines = error_lines();
    assert 31 in lines , lines;
    assert 41 in lines , lines;
}
