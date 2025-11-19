# Test failing keyword-only parameter cases

def strict_kwonly(*, x: int, y: str) -> str {
    return f"{x}: {y}";
}

def kwonly_with_defaults(*, req: int, opt: str = "default") -> str {
    return f"{req}-{opt}";
}

def mixed_kwonly(a: int, *, kw1: str, kw2: bool = False) -> dict {
    return {"a": a, "kw1": kw1, "kw2": kw2};
}

def complex_kwonly(pos: int, /, reg: str, *args: float, kw_req: bool, kw_opt: int = 10, **kwargs: any) -> dict {
    return {"pos": pos, "reg": reg, "args": list(args), "kw_req": kw_req, "kw_opt": kw_opt, "kwargs": kwargs};
}

def only_star_separator(*, x: int) -> int {
    return x * 2;
}

def nested_kwonly_issues(*, outer: dict, inner: list = []) -> int {
    return len(outer) + len(inner);
}

with entry {
    print("=== TESTING KEYWORD-ONLY FAILURES ===");

    # Test 1: Calling kw-only with positional arguments
    try {
        result = strict_kwonly(42, "test");
        print("❌ FAIL: Should reject positional for kw-only");
    } except Exception as e {
        print("✅ PASS: Caught kw-only positional error:", type(e).__name__);
    }

    # Test 2: Missing required keyword-only argument
    try {
        result = strict_kwonly(x=42);
        print("❌ FAIL: Should reject missing required kw-only");
    } except Exception as e {
        print("✅ PASS: Caught missing kw-only error:", type(e).__name__);
    }

    # Test 3: Missing required in defaults mix
    try {
        result = kwonly_with_defaults(opt="custom");
        print("❌ FAIL: Should reject missing required kw-only");
    } except Exception as e {
        print("✅ PASS: Caught missing required in defaults:", type(e).__name__);
    }

    # Test 4: Extra unknown keyword arguments (without **kwargs)
    try {
        result = strict_kwonly(x=42, y="test", extra="unknown");
        print("❌ FAIL: Should reject unknown keyword");
    } except Exception as e {
        print("✅ PASS: Caught unknown keyword error:", type(e).__name__);
    }

    # Test 5: Mixed signature - wrong positional count
    try {
        result = mixed_kwonly(1, 2, kw1="test");
        print("❌ FAIL: Should reject too many positional");
    } except Exception as e {
        print("✅ PASS: Caught too many positional error:", type(e).__name__);
    }

    # Test 6: Mixed signature - missing kw-only required
    try {
        result = mixed_kwonly(42);
        print("❌ FAIL: Should reject missing kw-only in mixed");
    } except Exception as e {
        print("✅ PASS: Caught missing kw-only in mixed:", type(e).__name__);
    }

    # Test 7: Complex signature - kw-only as positional
    try {
        result = complex_kwonly(1, "reg", 1.5, True);
        print("❌ FAIL: Should reject kw-only as positional");
    } except Exception as e {
        print("✅ PASS: Caught kw-only as positional error:", type(e).__name__);
    }

    # Test 8: Complex signature - missing required kw-only
    try {
        result = complex_kwonly(1, "reg", 1.5, 2.5);
        print("❌ FAIL: Should reject missing kw-only in complex");
    } except Exception as e {
        print("✅ PASS: Caught missing kw-only in complex:", type(e).__name__);
    }

    # Test 9: Only star separator - positional call
    try {
        result = only_star_separator(42);
        print("❌ FAIL: Should reject positional for star-only");
    } except Exception as e {
        print("✅ PASS: Caught star-only positional error:", type(e).__name__);
    }


    # Test 11: Mutable default issues
    try {
        result1 = nested_kwonly_issues(outer={"a": 1});
        result2 = nested_kwonly_issues(outer={"b": 2});
        print("✅ INFO: Mutable defaults - result1:", result1, "result2:", result2);
    } except Exception as e {
        print("❌ FAIL: Mutable defaults caused error:", type(e).__name__);
    }

    # Test 12: Valid calls that should work
    try {
        result = strict_kwonly(x=42, y="valid");
        print("✅ PASS: Valid kw-only call:", result);
    } except Exception as e {
        print("❌ FAIL: Valid kw-only call rejected:", type(e).__name__);
    }

    try {
        result = kwonly_with_defaults(req=100);
        print("✅ PASS: Valid kw-only with defaults:", result);
    } except Exception as e {
        print("❌ FAIL: Valid defaults call rejected:", type(e).__name__);
    }

    try {
        result = mixed_kwonly(5, kw1="test");
        print("✅ PASS: Valid mixed kw-only:", result);
    } except Exception as e {
        print("❌ FAIL: Valid mixed call rejected:", type(e).__name__);
    }
}

def additional_kwonly_edge_cases() -> None {
    print("\n=== ADDITIONAL KEYWORD-ONLY EDGE CASES ===");

    # Test 14: Keyword argument name conflicts with Python keywords
    def python_keyword_conflicts(*, class_name: str, import_path: str = "default") -> str {
        return f"{class_name}: {import_path}";
    }

    try {
        result = python_keyword_conflicts(class_name="TestClass");
        print("✅ PASS: Python keyword as param name:", result);
    } except Exception as e {
        print("❌ FAIL: Python keyword param failed:", type(e).__name__);
    }

    # Test 15: Very long keyword-only parameter lists
    def many_kwonly_params(
        *,
        p1: int, p2: int, p3: int, p4: int, p5: int,
        p6: str = "d6", p7: str = "d7", p8: str = "d8"
    ) -> dict {
        return {"sum": p1+p2+p3+p4+p5, "strings": [p6, p7, p8]};
    }

    try {
        result = many_kwonly_params(p1=1, p2=2, p3=3, p4=4, p5=5);
        print("✅ PASS: Many kw-only params:", result);
    } except Exception as e {
        print("❌ FAIL: Many kw-only params failed:", type(e).__name__);
    }

    # Test 16: Nested function calls as keyword arguments
    def helper_func() -> str {
        return "helper_result";
    }

    def kwonly_with_function_calls(*, data: str, processed: bool = True) -> str {
        return f"data={data}, processed={processed}";
    }

    try {
        result = kwonly_with_function_calls(data=helper_func(), processed=False);
        print("✅ PASS: Function calls as kw args:", result);
    } except Exception as e {
        print("❌ FAIL: Function calls as kw args failed:", type(e).__name__);
    }

    # Test 17: Empty string and special values
    try {
        result = strict_kwonly(x=0, y="");
        print("✅ PASS: Edge values (0, empty string):", result);
    } except Exception as e {
        print("❌ FAIL: Edge values failed:", type(e).__name__);
    }

    # Test 18: Really test duplicate keyword detection properly
    # Note: This might not be detectable at runtime in some languages
    def test_duplicate_detection() -> None {
        try {
            # This should be a syntax error, but let's see what happens
            call_string = "strict_kwonly(x=42, y='test', x=99)";
            print("INFO: Would test duplicate keywords, but this is syntax-level");
        } except Exception as e {
            print("✅ PASS: Duplicate detection works:", type(e).__name__);
        }
    }

    test_duplicate_detection();
}

with entry {
    additional_kwonly_edge_cases();
}
