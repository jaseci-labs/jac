# Exception handling tests for native LLVM IR codegen.

# Test 1: Basic try/except — catch exception, return from handler
def test_basic_try_except() -> int {
    result: int = 0;
    try {
        result = 1;
        raise Exception("test error");
        result = 99;  # Should not execute
    } except Exception {
        result = 2;
    }
    return result;
}

# Test 2: Try without exception — no handler runs
def test_try_no_exception() -> int {
    result: int = 0;
    try {
        result = 42;
    } except Exception {
        result = -1;
    }
    return result;
}

# Test 3: Exception with "as" binding — bind exception message
def test_except_as_binding() -> str {
    msg: str = "none";
    try {
        raise Exception("caught me");
    } except Exception as e {
        msg = e;
    }
    return msg;
}

# Test 4: Try/except with else — else runs only when no exception
def test_try_else_no_exception() -> int {
    result: int = 0;
    try {
        result = 1;
    } except Exception {
        result = -1;
    } else {
        result = result + 10;  # Should run: result becomes 11
    }
    return result;
}

# Test 5: Try/except with else — else skipped when exception occurs
def test_try_else_with_exception() -> int {
    result: int = 0;
    try {
        raise Exception("boom");
    } except Exception {
        result = 5;
    } else {
        result = 99;  # Should NOT run
    }
    return result;
}

# Test 6: Try/except/finally — finally always runs
def test_try_finally() -> int {
    result: int = 0;
    try {
        result = 1;
        raise Exception("err");
    } except Exception {
        result = result + 10;
    } finally {
        result = result + 100;
    }
    return result;  # 1 + 10 + 100 = 111
}

# Test 7: Try/finally without exception
def test_try_finally_no_exception() -> int {
    result: int = 0;
    try {
        result = 5;
    } except Exception {
        result = -1;
    } finally {
        result = result + 100;
    }
    return result;  # 5 + 100 = 105
}

# Test 8: Multiple except handlers — match specific type
def test_multiple_except() -> int {
    result: int = 0;
    try {
        raise ValueError("val error");
    } except TypeError {
        result = 1;
    } except ValueError {
        result = 2;
    } except Exception {
        result = 3;
    }
    return result;  # Should be 2
}

# Test 9: Exception catch-all with Exception base type
def test_catch_all() -> int {
    result: int = 0;
    try {
        raise TypeError("type error");
    } except Exception {
        result = 42;
    }
    return result;
}

# Test 10: Nested try/except — inner exception caught by inner handler
def test_nested_try() -> int {
    result: int = 0;
    try {
        result = 1;
        try {
            raise ValueError("inner");
        } except ValueError {
            result = result + 10;
        }
        result = result + 100;  # Should execute after inner handler
    } except Exception {
        result = -1;
    }
    return result;  # 1 + 10 + 100 = 111
}

# Test 11: Raise from function call form
def test_raise_func_form() -> int {
    result: int = 0;
    try {
        raise RuntimeError("runtime fail");
    } except RuntimeError {
        result = 77;
    }
    return result;
}

# Test 12: Full try/except/else/finally combo
def test_full_combo_no_exc() -> int {
    result: int = 0;
    try {
        result = 1;
    } except Exception {
        result = -1;
    } else {
        result = result + 20;
    } finally {
        result = result + 300;
    }
    return result;  # 1 + 20 + 300 = 321
}
