"""Exception hierarchy primitives: try/except with type hierarchy matching.

Cross-backend equivalence fixture — Python reference + native implementation.
Uses individual test functions (matching the exceptions.na.jac pattern) rather
than dict-returning functions, since exception handling + dict[str, any] has
type constraints in the native backend.
"""

# --- Python reference functions ---

def test_basic_catch_py() -> int {
    # raise ValueError, catch ValueError
    result: int = 0;
    try {
        raise ValueError("test");
    } except ValueError {
        result = 1;
    }
    return result;
}

def test_catch_parent_py() -> int {
    # raise ZeroDivisionError, catch ArithmeticError
    result: int = 0;
    try {
        raise ZeroDivisionError("div");
    } except ArithmeticError {
        result = 1;
    }
    return result;
}

def test_catch_grandparent_py() -> int {
    # raise ZeroDivisionError, catch Exception
    result: int = 0;
    try {
        raise ZeroDivisionError("div");
    } except Exception {
        result = 1;
    }
    return result;
}

def test_catch_wrong_type_py() -> int {
    # raise ValueError, inner catches TypeError -> falls to outer Exception
    result: int = 0;
    try {
        try {
            raise ValueError("val");
        } except TypeError {
            result = 1;
        }
    } except Exception {
        result = 2;
    }
    return result;  # Should be 2 (fell through to outer)
}

def test_multiple_handlers_py() -> int {
    # raise KeyError, try TypeError then LookupError then Exception
    result: int = 0;
    try {
        raise KeyError("k");
    } except TypeError {
        result = 1;
    } except LookupError {
        result = 2;
    } except Exception {
        result = 3;
    }
    return result;  # Should be 2 (LookupError catches KeyError)
}

def test_nested_hierarchy_py() -> int {
    # raise IndexError, catch LookupError
    result: int = 0;
    try {
        raise IndexError("idx");
    } except LookupError {
        result = 1;
    }
    return result;
}

def test_finally_runs_py() -> int {
    # raise ValueError, catch + finally
    result: int = 0;
    try {
        raise ValueError("v");
    } except ValueError {
        result = result + 1;
    } finally {
        result = result + 10;
    }
    return result;  # Should be 11 (1 + 10)
}

def test_no_exception_py() -> int {
    # no raise, try/except/else
    result: int = 0;
    try {
        result = 1;
    } except ValueError {
        result = -1;
    } else {
        result = result + 10;
    }
    return result;  # Should be 11 (1 + 10)
}

def test_exc_as_binding_py() -> int {
    # raise ValueError, catch as e, verify handler ran
    result: int = 0;
    try {
        raise ValueError("test msg");
    } except ValueError as e {
        result = 1;
    }
    return result;
}

# --- Native implementations ---

na {
    def test_basic_catch_na() -> int {
        result: int = 0;
        try {
            raise ValueError("test");
        } except ValueError {
            result = 1;
        }
        return result;
    }

    def test_catch_parent_na() -> int {
        result: int = 0;
        try {
            raise ZeroDivisionError("div");
        } except ArithmeticError {
            result = 1;
        }
        return result;
    }

    def test_catch_grandparent_na() -> int {
        result: int = 0;
        try {
            raise ZeroDivisionError("div");
        } except Exception {
            result = 1;
        }
        return result;
    }

    def test_catch_wrong_type_na() -> int {
        result: int = 0;
        try {
            try {
                raise ValueError("val");
            } except TypeError {
                result = 1;
            }
        } except Exception {
            result = 2;
        }
        return result;
    }

    def test_multiple_handlers_na() -> int {
        result: int = 0;
        try {
            raise KeyError("k");
        } except TypeError {
            result = 1;
        } except LookupError {
            result = 2;
        } except Exception {
            result = 3;
        }
        return result;
    }

    def test_nested_hierarchy_na() -> int {
        result: int = 0;
        try {
            raise IndexError("idx");
        } except LookupError {
            result = 1;
        }
        return result;
    }

    def test_finally_runs_na() -> int {
        result: int = 0;
        try {
            raise ValueError("v");
        } except ValueError {
            result = result + 1;
        } finally {
            result = result + 10;
        }
        return result;
    }

    def test_no_exception_na() -> int {
        result: int = 0;
        try {
            result = 1;
        } except ValueError {
            result = -1;
        } else {
            result = result + 10;
        }
        return result;
    }

    def test_exc_as_binding_na() -> int {
        result: int = 0;
        try {
            raise ValueError("test msg");
        } except ValueError as e {
            result = 1;
        }
        return result;
    }
}
