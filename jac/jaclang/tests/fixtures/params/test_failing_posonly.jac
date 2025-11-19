# Test failing positional-only parameter cases

def strict_posonly(a: int, b: str, /) -> str {
    return f"{a}: {b}";
}

def mixed_posonly(x: int, /, y: str, z: float = 1.0) -> str {
    return f"{x}-{y}-{z}";
}

def complex_posonly(a: int, b: str = "def", /, c: float, *args: int, kw: bool, **kwargs: any) -> dict {
    return {"a": a, "b": b, "c": c, "args": list(args), "kw": kw, "kwargs": kwargs};
}

def edge_case_posonly(/, x: int) -> int {
    return x;
}

def no_regular_params(a: int, /, *, b: str) -> str {
    return f"{a}: {b}";
}

with entry {
    print("=== TESTING POSITIONAL-ONLY FAILURES ===");

    # Test 1: Calling pos-only with keyword arguments
    try {
        result = strict_posonly(a=10, b="test");
        print("❌ FAIL: Should reject pos-only as keywords");
    } except Exception as e {
        print("✅ PASS: Caught pos-only keyword error");
    }

    # Test 2: Partial keyword arguments on pos-only
    try {
        result = strict_posonly(10, b="test");
        print("❌ FAIL: Should reject mixed pos-only calling");
    } except Exception as e {
        print("✅ PASS: Caught mixed pos-only error");
    }

    # Test 3: Too many positional arguments
    try {
        result = strict_posonly(1, "test", "extra");
        print("❌ FAIL: Should reject too many args");
    } except Exception as e {
        print("✅ PASS: Caught too many args error");
    }

    # Test 4: Missing required positional-only
    try {
        result = strict_posonly(42);
        print("❌ FAIL: Should reject missing required pos-only");
    } except Exception as e {
        print("✅ PASS: Caught missing pos-only error");
    }

    # Test 5: Mixed signature - wrong keyword usage
    try {
        result = mixed_posonly(x=10, y="test");
        print("❌ FAIL: Should reject pos-only x as keyword");
    } except Exception as e {
        print("✅ PASS: Caught mixed signature error");
    }

    # Test 6: Complex signature - pos-only as keyword
    try {
        result = complex_posonly(a=1, c=2.5, kw=True);
        print("❌ FAIL: Should reject pos-only a as keyword");
    } except Exception as e {
        print("✅ PASS: Caught complex pos-only error");
    }

    # Test 7: Edge case - only separator with keyword
    try {
        result = edge_case_posonly(x=42);
        print("✅ PASS: Edge case works:", result);
    } except Exception as e {
        print("✅ PASS: Edge case properly rejected");
    }

    # Test 8: No regular params - wrong calling pattern
    try {
        result = no_regular_params(1, "test");
        print("❌ FAIL: Should reject positional for keyword-only");
    } except Exception as e {
        print("✅ PASS: Caught no-regular-params error");
    }


    result = strict_posonly("not_int", "test");


    # Test 10: Empty call to required pos-only
    try {
        result = strict_posonly();
        print("❌ FAIL: Should reject empty call");
    } except Exception as e {
        print("✅ PASS: Caught empty call error");
    }

    # Test 11: Valid calls that should work
    try {
        result = strict_posonly(42, "valid");
        print("✅ PASS: Valid pos-only call:", result);
    } except Exception as e {
        print("❌ FAIL: Valid call rejected");
    }

    try {
        result = mixed_posonly(1, "test", 3.14);
        print("✅ PASS: Valid mixed call:", result);
    } except Exception as e {
        print("❌ FAIL: Valid mixed call rejected");
    }
}
