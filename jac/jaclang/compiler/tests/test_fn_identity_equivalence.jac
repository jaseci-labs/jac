"""One function object has one identity when it is read as a value.

The server lane pins the expected values and the native lane must agree with it.
"""

glob EXPECTED: dict[str, any] = {
         "two_reads_equal": True,
         "two_reads_not_differ": True,
         "other_function_differs": True,
         "reads_still_call": 7,
         "factory_values_differ": True,
         "factory_value_equals_itself": True,
         "registered_found": 1,
         "each_pass_consistent": 2,
         "each_pass_new_function": True
     };

test "function values compare by the function object they read" {
    got = run_py_fixture("fn_identity", "fn_identity_py");
    assert got == EXPECTED , f"server lane: {got}";
}

test "native function values compare as the server's do" {
    run_with_both(
        "fn_identity.jac",
        "fn_identity_py",
        "fn_identity_cl",
        "fn_identity_na",
        require=["cl", "na"]
    );
}
