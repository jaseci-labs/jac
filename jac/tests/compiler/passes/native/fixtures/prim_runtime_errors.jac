"""Runtime error hierarchy tests: catch implicit errors by parent type.

Unlike prim_exceptions.jac (explicit raise), these tests trigger ACTUAL runtime
errors (division by zero, index out of bounds, etc.) and verify they're caught
by the correct handler in the exception hierarchy.

Uses individual int-returning test functions (matching the prim_exceptions.jac
pattern) since dict[str, any] has type constraints in the native backend.
"""

# --- Python reference functions ---

def test_divzero_catch_exact_py() -> int {
    # int division by zero caught by ZeroDivisionError
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

def test_divzero_catch_parent_py() -> int {
    # int division by zero caught by ArithmeticError (parent)
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ArithmeticError {
        result = 1;
    }
    return result;
}

def test_divzero_catch_grandparent_py() -> int {
    # int division by zero caught by Exception (grandparent)
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except Exception {
        result = 1;
    }
    return result;
}

def test_divzero_wrong_handler_py() -> int {
    # int division by zero NOT caught by ValueError, falls to outer
    result: int = 0;
    try {
        try {
            x: int = 1 / 0;
        } except ValueError {
            result = 1;
        }
    } except ArithmeticError {
        result = 2;
    }
    return result;  # Should be 2
}

def test_modulo_zero_py() -> int {
    # modulo by zero caught by ArithmeticError
    result: int = 0;
    try {
        x: int = 5 % 0;
    } except ArithmeticError {
        result = 1;
    }
    return result;
}

def test_index_oob_catch_exact_py() -> int {
    # list index out of bounds caught by IndexError
    result: int = 0;
    items: list[int] = [10, 20, 30];
    try {
        x: int = items[99];
    } except IndexError {
        result = 1;
    }
    return result;
}

def test_index_oob_catch_parent_py() -> int {
    # list index out of bounds caught by LookupError (parent)
    result: int = 0;
    items: list[int] = [10, 20, 30];
    try {
        x: int = items[99];
    } except LookupError {
        result = 1;
    }
    return result;
}

def test_index_oob_catch_exception_py() -> int {
    # list index out of bounds caught by Exception (grandparent)
    result: int = 0;
    items: list[int] = [10, 20, 30];
    try {
        x: int = items[99];
    } except Exception {
        result = 1;
    }
    return result;
}

def test_key_error_catch_exact_py() -> int {
    # dict missing key caught by KeyError
    result: int = 0;
    d: dict[str, int] = {"a": 1};
    try {
        x: int = d["z"];
    } except KeyError {
        result = 1;
    }
    return result;
}

def test_key_error_catch_parent_py() -> int {
    # dict missing key caught by LookupError (parent)
    result: int = 0;
    d: dict[str, int] = {"a": 1};
    try {
        x: int = d["z"];
    } except LookupError {
        result = 1;
    }
    return result;
}

def test_multi_handler_runtime_py() -> int {
    # division by zero with multiple handlers
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ValueError {
        result = 1;
    } except ArithmeticError {
        result = 2;
    } except Exception {
        result = 3;
    }
    return result;  # Should be 2 (ArithmeticError catches ZeroDivisionError)
}

def test_runtime_finally_py() -> int {
    # runtime error with finally block
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ZeroDivisionError {
        result = result + 1;
    } finally {
        result = result + 10;
    }
    return result;  # Should be 11
}

# --- Native implementations ---

na {
    def test_divzero_catch_exact_na() -> int {
        result: int = 0;
        try {
            x: int = 1 / 0;
        } except ZeroDivisionError {
            result = 1;
        }
        return result;
    }

    def test_divzero_catch_parent_na() -> int {
        result: int = 0;
        try {
            x: int = 1 / 0;
        } except ArithmeticError {
            result = 1;
        }
        return result;
    }

    def test_divzero_catch_grandparent_na() -> int {
        result: int = 0;
        try {
            x: int = 1 / 0;
        } except Exception {
            result = 1;
        }
        return result;
    }

    def test_divzero_wrong_handler_na() -> int {
        result: int = 0;
        try {
            try {
                x: int = 1 / 0;
            } except ValueError {
                result = 1;
            }
        } except ArithmeticError {
            result = 2;
        }
        return result;
    }

    def test_modulo_zero_na() -> int {
        result: int = 0;
        try {
            x: int = 5 % 0;
        } except ArithmeticError {
            result = 1;
        }
        return result;
    }

    def test_index_oob_catch_exact_na() -> int {
        result: int = 0;
        items: list[int] = [10, 20, 30];
        try {
            x: int = items[99];
        } except IndexError {
            result = 1;
        }
        return result;
    }

    def test_index_oob_catch_parent_na() -> int {
        result: int = 0;
        items: list[int] = [10, 20, 30];
        try {
            x: int = items[99];
        } except LookupError {
            result = 1;
        }
        return result;
    }

    def test_index_oob_catch_exception_na() -> int {
        result: int = 0;
        items: list[int] = [10, 20, 30];
        try {
            x: int = items[99];
        } except Exception {
            result = 1;
        }
        return result;
    }

    def test_key_error_catch_exact_na() -> int {
        result: int = 0;
        d: dict[str, int] = {"a": 1};
        try {
            x: int = d["z"];
        } except KeyError {
            result = 1;
        }
        return result;
    }

    def test_key_error_catch_parent_na() -> int {
        result: int = 0;
        d: dict[str, int] = {"a": 1};
        try {
            x: int = d["z"];
        } except LookupError {
            result = 1;
        }
        return result;
    }

    def test_multi_handler_runtime_na() -> int {
        result: int = 0;
        try {
            x: int = 1 / 0;
        } except ValueError {
            result = 1;
        } except ArithmeticError {
            result = 2;
        } except Exception {
            result = 3;
        }
        return result;
    }

    def test_runtime_finally_na() -> int {
        result: int = 0;
        try {
            x: int = 1 / 0;
        } except ZeroDivisionError {
            result = result + 1;
        } finally {
            result = result + 10;
        }
        return result;
    }
}
