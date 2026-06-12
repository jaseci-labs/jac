"""Test closure support in Jac client (cl) codegen.

Closures are a compiler feature (runtime-agnostic), so this checks the
generated JS directly rather than building a full bundle.
"""

import os;
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(os.path.dirname(os.path.dirname(jaclang.__file__))),
         "tests",
         "runtimelib",
         "fixtures"
     );

test "nested function closures compile to JS" {
    fixture = os.path.join(FIXTURES, "test_closures.jac");
    prog = JacProgram();
    mod = prog.compile(fixture);
    js = mod.gen.js;
    assert js.strip() , "Expected JavaScript output for cl closures";

    # Outer functions.
    assert "function make_counter(" in js;
    assert "function create_signal_simple(" in js;
    assert "function make_adder(" in js;
    assert "function create_shared_counter(" in js;

    # Inner (closed-over) functions.
    assert "function increment(" in js;
    assert "function readVal(" in js;
    assert "function writeVal(" in js;
    assert "function get_value(" in js;

    # Closed-over variables are referenced from inner scopes.
    assert "count" in js;
    assert "value" in js;
}
