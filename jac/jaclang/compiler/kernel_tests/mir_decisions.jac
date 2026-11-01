"""The decision step: lowering to MIR assigns every function a representation
or refuses it with a reason, and a refusal reaches every caller."""

def typed_function_stays_native {
    lowered = lower_text(
        "def add(a: int, b: int) -> int {\n    return a + b;\n}\n", "stays_native.jac"
    );
    assert not lowered.mir.demoted , lowered.mir.demoted;
    assert lowered.mir.function(lowered.symbol_of("add")) is not None;
}

def variadic_signature_is_refused {
    lowered = lower_text(
        "def total(*parts: int) -> int {\n    return 0;\n}\n", "variadic.jac"
    );
    reasons = lowered.lowering.refusals.get("total", []);
    assert reasons , "a variadic signature must be refused when it is declared";
    assert reasons[0].name == "variadic or keyword-only parameters";
    assert reasons[0].code == "E5092";
}

def body_refusal_reaches_callers {
    lowered = lower_text(
        "def trim(xs: list[int]) -> int {\n    del xs[0:1];\n    return len(xs);\n}\n"
            + "def outer(xs: list[int]) -> int {\n    return trim(xs) + 1;\n}\n",
        "propagates.jac"
    );
    assert lowered.reason("trim") == "statement 'del of a slice'";
    assert lowered.reason("outer")
        == f"calls {lowered.symbol_of('trim')}, which is not native";
    assert lowered.mir.function(lowered.symbol_of("outer")) is None , (
        "a demoted function leaves no MIR body behind"
    );
}

def mir_decision_cases -> list[KernelCase] {
    return [
        KernelCase(
            "a typed function lowers with no demotion", typed_function_stays_native
        ),
        KernelCase(
            "a variadic signature is refused with its reason",
            variadic_signature_is_refused
        ),
        KernelCase(
            "a body refusal demotes the function and every caller",
            body_refusal_reaches_callers
        )
    ];
}
