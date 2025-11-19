# Test failing variable arguments cases (*args, **kwargs)

def simple_args_only(*args: int) -> int {
    return sum(args);
}

def simple_kwargs_only(**kwargs: str) -> int {
    return len(kwargs);
}

def args_with_required(req: str, *args: int) -> str {
    return f"{req}: {sum(args)}";
}

def kwargs_with_required(req: int, **kwargs: str) -> dict {
    return {"req": req, "kwargs": kwargs};
}

def full_varargs_signature(
    pos: int,
    /,
    reg: str,
    def_param: float = 1.0,
    *args: int,
    kw_req: bool,
    kw_opt: str = "default",
    **kwargs: any
) -> dict {
    return {
        "pos": pos, "reg": reg, "def_param": def_param,
        "args": list(args), "kw_req": kw_req, "kw_opt": kw_opt, "kwargs": kwargs
    };
}

def conflicting_names(name: str, *args: str, name_kw: str, **kwargs: str) -> dict {
    return {"name": name, "args": list(args), "name_kw": name_kw, "kwargs": kwargs};
}

def type_sensitive_varargs(*args: int, **kwargs: int) -> dict {
    return {"args_sum": sum(args), "kwargs_sum": sum(kwargs.values())};
}

def edge_case_empty_varargs(required: str, *args: float, **kwargs: bool) -> str {
    return f"{required}: args={len(args)}, kwargs={len(kwargs)}";
}

def double_star_issues(**kwargs: dict) -> int {
    total = 0;
    for (k, v) in kwargs.items() {
        if isinstance(v, dict) {
            total += len(v);
        } else {
            total += 1;
        }
    }
    return total;
}

def additional_varargs_edge_cases() -> None {
    print("\n=== ADDITIONAL VARARGS EDGE CASES ===");

    # Test 16: Empty containers passed to varargs
    def test_empty_containers(*args: list, **kwargs: dict) -> dict {
        return {"args_count": len(args), "kwargs_count": len(kwargs)};
    }

    try {
        result = test_empty_containers([], {}, third_arg=[]);
        print("✅ PASS: Empty containers:", result);
    } except Exception as e {
        print("❌ FAIL: Empty containers failed");
    }

    # Test 17: Nested data structures
    def complex_data_varargs(*args: dict, **kwargs: list) -> dict {
        return {"total_keys": sum(args), "total_items": len(kwargs)};
    }

    try {
        result = complex_data_varargs(
            12,
            16,
            list1=[1, 2, 3],
            list2=[4, 5]
        );
        print("✅ PASS: Complex data structures:", result);
    } except Exception as e {
        print("❌ FAIL: Complex data structures failed");
    }

    # Test 18: Special character handling in kwargs keys
    def special_chars_kwargs(**kwargs: str) -> dict {
        return {"keys": list(kwargs.keys()), "count": len(kwargs)};
    }

    try {
        # Note: Most of these won't work as valid identifiers, but let's test what we can
        result = special_chars_kwargs(normal="value", with_underscore="test");
        print("✅ PASS: Special chars in kwargs:", result);
    } except Exception as e {
        print("❌ FAIL: Special chars failed");
    }

    # Test 19: Very large argument counts
    def stress_test_args(*args: int) -> dict {
        return {"count": len(args), "sum": sum(args), "avg": sum(args)/len(args) if args else 0};
    }

    try {
        large_args = list(range(100));  # 100 arguments
        result = stress_test_args(*large_args);
        print("✅ PASS: Large arg count:", f"count={result['count']}, avg={result['avg']}");
    } except Exception as e {
        print("❌ FAIL: Large arg count failed");
    }

    # Test 20: Mixing unpacking with explicit args
    def mixed_unpacking_test(first: str, *args: int, last: str, **kwargs: bool) -> dict {
        _sum = sum(args);
        _kwargs_true_count = 0;
        for v in kwargs.values() {
            if v {
                _kwargs_true_count += 1;
            }
        }
        return {
            "first": first,
            "args_sum": _sum,
            "last": last,
            "kwargs_true_count": _kwargs_true_count
        };
    }

    try {
        numbers = [10, 20, 30];
        flags = {"debug": True, "verbose": False, "strict": True};
        result = mixed_unpacking_test("start", *numbers, last="end", **flags);
        print("✅ PASS: Mixed unpacking:", result);
    } except Exception as e {
        print("❌ FAIL: Mixed unpacking failed");
    }

    # Test 21: Recursive function with varargs
    def recursive_varargs(depth: int, *args: str, **kwargs: int) -> dict {
        if depth <= 0 or not args {
            return {"depth": depth, "args": list(args), "kwargs": kwargs};
        }

        new_args = args[1:];  # Remove first arg
        new_kwargs = {k: v+1 for (k, v) in kwargs.items()};  # Increment all values

        return recursive_varargs(depth-1, *new_args, **new_kwargs);
    }

    try {
        result = recursive_varargs(3, "a", "b", "c", "d", x=1, y=2);
        print("✅ PASS: Recursive varargs:", result);
    } except Exception as e {
        print("❌ FAIL: Recursive varargs failed");
    }
}

with entry {
    print("=== TESTING VARIABLE ARGUMENTS FAILURES ===");

    # Test 1: Wrong types in *args (if type checking enabled)
    try {
        result = simple_args_only(1, 2, "not_int", 4);
        print("❌ FAIL: Should catch mixed types in *args");
    } except Exception as e {
        print("✅ PASS: Caught *args type error");
    }

    # Test 2: Wrong types in **kwargs (if type checking enabled)
    try {
        result = simple_kwargs_only(12,a="string", b=123, c="string");
        print("❌ FAIL: Should catch mixed types in **kwargs");
    } except Exception as e {
        print("✅ PASS: Caught **kwargs type error");
    }

    # Test 3: Missing required before *args
    try {
        result = args_with_required(1, 2, 3, apple=90);
    } except Exception as e {
        print("✅ PASS: Caught required param type error");
    }

    # Test 4: Missing required before **kwargs
    try {
        result = kwargs_with_required(name="test", value="data");
        print("❌ FAIL: Should catch wrong types for required");
    } except Exception as e {
        print("✅ PASS: Caught required before kwargs error");
    }

    # Test 5: Complex signature - pos-only passed as keyword
    try {
        result = full_varargs_signature(
            pos=1, reg="test", kw_req=True
        );
        print("❌ FAIL: Should reject pos-only as keyword in varargs");
    } except Exception as e {
        print("✅ PASS: Caught pos-only in varargs error");
    }

    # Test 6: Complex signature - missing required kw-only
    try {
        result = full_varargs_signature(1, "test", 2.0, 10, 20);
        print("❌ FAIL: Should reject missing kw-only in varargs");
    } except Exception as e {
        print("✅ PASS: Caught missing kw-only in varargs");
    }

    # Test 7: Name conflicts between params and kwargs
    try {
        result = conflicting_names("test", "arg1", name_kw="kw_test", name="conflict");
        print("❌ FAIL: Should catch parameter name conflicts");
    } except Exception as e {
        print("✅ PASS: Caught name conflict error");
    }

    # Test 8: Type-sensitive varargs with wrong types
    try {
        result = type_sensitive_varargs(1, 2, 3, a="not_int", b=4.5);
        print("❌ FAIL: Should catch type mismatch in kwargs");
    } except Exception as e {
        print("✅ PASS: Caught varargs type sensitivity error");
    }


    # Test 9: Double unpacking issues
    try {
        data = {"a": {"nested": "dict"}, "b": "simple"};
        result = double_star_issues(**data);
        print("✅ INFO: Double star result:", result);
    } except Exception as e {
        print("✅ PASS: Caught double star error");
    }

    # Test 10: Empty varargs but required params missing
    try {
        result = edge_case_empty_varargs();
        print("❌ FAIL: Should catch missing required with empty varargs");
    } except Exception as e {
        print("✅ PASS: Caught missing required in empty varargs");
    }


    # Test 11: Keyword argument conflicts with *args collection
    try {
        items = [1, 2, 3];
        result = args_with_required("test", *items, args="conflict");
        print("❌ FAIL: Should catch args name conflict");
    } except Exception as e {
        print("✅ PASS: Caught args conflict error");
    }

    # Test 12: **kwargs conflicts with explicit keywords
    try {
        extra_data = {"kw_req": True, "extra": "data"};
        result = full_varargs_signature(1, "test", kw_req=False, **extra_data);
        print("❌ FAIL: Should catch kwargs conflict with explicit");
    } except Exception as e {
        print("✅ PASS: Caught kwargs explicit conflict");
    }

    # Test 13: Valid calls that should work
    try {
        result = simple_args_only(1, 2, 3, 4, 5);
        print("✅ PASS: Valid *args call:", result);
    } except Exception as e {
        print("❌ FAIL: Valid *args call rejected");
    }

    try {
        result = simple_kwargs_only(a="test", b="data", c="more");
        print("✅ PASS: Valid **kwargs call:", result);
    } except Exception as e {
        print("❌ FAIL: Valid **kwargs call rejected");
    }

    try {
        result = full_varargs_signature(
            1,                    # pos (pos-only)
            "regular",           # reg
            2.5,                 # def_param
            10, 20, 30,          # *args
            kw_req=True,         # kw_req (required kw-only)
            kw_opt="custom",     # kw_opt (optional kw-only)
            extra="data",        # **kwargs
            more="info"
        );
        print("✅ PASS: Valid complex varargs call keys:", list(result.keys()));
    } except Exception as e {
        print("❌ FAIL: Valid complex varargs rejected");
    }

    additional_varargs_edge_cases();
}
