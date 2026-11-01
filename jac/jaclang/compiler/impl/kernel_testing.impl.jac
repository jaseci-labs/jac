impl kernel_suites -> list[KernelSuite] {
    return [
        KernelSuite(name="type_position", cases=type_position_cases()),
        KernelSuite(name="scopes", cases=scope_cases()),
        KernelSuite(name="context_bindings", cases=context_binding_cases()),
        KernelSuite(name="mir_decisions", cases=mir_decision_cases())
    ];
}

impl find_suite(name: str) -> KernelSuite {
    for suite in kernel_suites() {
        if suite.name == name {
            return suite;
        }
    }
    raise KernelError(f"the kernel holds no test suite named '{name}'");
}

impl run_case(case: KernelCase, scratch: str) -> str {
    os.makedirs(scratch, exist_ok=True);
    scope.scratch = scratch;
    try {
        case.check();
    } except AssertionError as error {
        detail = str(error);
        return "assertion failed: " + detail if detail else "assertion failed";
    } except Exception as error {
        return "raised: " + str(error);
    } finally {
        scope.scratch = "";
        install_host(NeutralHost());
    }
    return "";
}

impl case_scratch -> str {
    if not scope.scratch {
        raise KernelError("a kernel test helper ran outside a kernel test case");
    }
    return scope.scratch;
}
