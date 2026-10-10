"""Closures created in a loop body keep the loop's own names per pass.

A name whose every assignment is inside a loop is shared between a closure
created in the loop body and the rest of the function only while that pass
lasts; once the pass ends the closure keeps its own copy. The server lane pins
the expected values and the client and native lanes must agree with it.
"""

import from jaclang.compiler.tests.xbackend_equiv { run_with_both, run_py_fixture }

glob EXPECTED: dict[str, any] = {
         "target": [1, 2, 3],
         "body_local": [10, 20, 30],
         "typed_local": [100, 200, 300],
         "counted": [0, 1, 2],
         "while_local": [0, 2, 4],
         "while_shared": [3, 3, 3],
         "same_pass_write": [101, 102],
         "closure_write": [11, 21, 13, 3],
         "write_in_pass": [101, 102],
         "nested": [11, 12, 21, 22],
         "outer_pass": [7, 8],
         "shared_flag": [True, True, True],
         "outside_closure": [1, 2, 3, 3],
         "inside_closure": [1, 2, 3],
         "break": [1, 2, 2],
         "continue": [1, 2, 3],
         "nested_def": [7, 14],
         "unpacked": [12, 34],
         "comprehension": [2, 4, 6],
         "after_loop": [2, 4, 6, 6]
     };

test "closures created in a loop body keep each pass's loop-local names" {
    got = run_py_fixture("loop_closures", "loop_closures_py");
    mismatched = {
        key: (got.get(key), want)
        for (key, want) in EXPECTED.items()
        if got.get(key) != want
    };
    assert not mismatched , f"(got, expected) per case: {mismatched}";
}

test "client and native lanes give loop closures the same bindings as the server" {
    run_with_both(
        "loop_closures.jac",
        "loop_closures_py",
        "loop_closures_cl",
        "loop_closures_na",
        require=["cl", "na"]
    );
}
