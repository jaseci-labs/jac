"""Runtime error hierarchy tests: catch implicit errors by parent type.

Cross-backend equivalence fixture.
Unlike prim_exceptions.jac (explicit raise), these tests trigger ACTUAL runtime
errors from method calls and verify they're caught by the correct handler in
the exception hierarchy.
"""

def runtime_errors_py() -> dict {
    results: dict = {};

    try {
        x: int = "hello".index("xyz");
    } except ValueError {
        results["str_index_exact"] = "ValueError";
    }

    try {
        x: int = "hello".index("xyz");
    } except Exception {
        results["str_index_parent"] = "Exception";
    }

    handler: str = "none";
    try {
        try {
            x: int = "hello".index("xyz");
        } except TypeError {
            handler = "TypeError";
        }
    } except ValueError {
        handler = "ValueError";
    }
    results["str_index_wrong"] = handler;

    try {
        items: list[int] = [1, 2, 3];
        items.remove(99);
    } except ValueError {
        results["list_remove_exact"] = "ValueError";
    }

    try {
        items2: list[int] = [1, 2, 3];
        items2.remove(99);
    } except Exception {
        results["list_remove_parent"] = "Exception";
    }

    try {
        items3: list[int] = [1, 2, 3];
        x: int = items3.index(99);
    } except ValueError {
        results["list_index_exact"] = "ValueError";
    }

    try {
        d: dict[str, int] = {"a": 1};
        x2: int = d.pop("z");
    } except KeyError {
        results["dict_pop_exact"] = "KeyError";
    }

    try {
        d2: dict[str, int] = {"a": 1};
        x3: int = d2.pop("z");
    } except LookupError {
        results["dict_pop_parent"] = "LookupError";
    }

    try {
        s: set = {1, 2, 3};
        s.remove(99);
    } except KeyError {
        results["set_remove_exact"] = "KeyError";
    }

    try {
        s2: set = {1, 2, 3};
        s2.remove(99);
    } except LookupError {
        results["set_remove_parent"] = "LookupError";
    }

    try {
        s3: set = set();
        s3.pop();
    } except KeyError {
        results["set_pop_empty"] = "KeyError";
    }

    which: str = "none";
    try {
        x4: int = "hello".index("xyz");
    } except TypeError {
        which = "TypeError";
    } except ValueError {
        which = "ValueError";
    } except Exception {
        which = "Exception";
    }
    results["multi_handler"] = which;

    parts: str = "";
    try {
        items4: list[int] = [1, 2, 3];
        items4.remove(99);
    } except ValueError {
        parts = "caught";
    } finally {
        parts = parts + "+finally";
    }
    results["runtime_finally"] = parts;

    return results;
}

cl def runtime_errors_cl() -> dict {
    results: dict = {};

    try {
        x: int = "hello".index("xyz");
    } except ValueError {
        results["str_index_exact"] = "ValueError";
    }

    try {
        x: int = "hello".index("xyz");
    } except Exception {
        results["str_index_parent"] = "Exception";
    }

    handler: str = "none";
    try {
        try {
            x: int = "hello".index("xyz");
        } except TypeError {
            handler = "TypeError";
        }
    } except ValueError {
        handler = "ValueError";
    }
    results["str_index_wrong"] = handler;

    try {
        items: list[int] = [1, 2, 3];
        items.remove(99);
    } except ValueError {
        results["list_remove_exact"] = "ValueError";
    }

    try {
        items2: list[int] = [1, 2, 3];
        items2.remove(99);
    } except Exception {
        results["list_remove_parent"] = "Exception";
    }

    try {
        items3: list[int] = [1, 2, 3];
        x: int = items3.index(99);
    } except ValueError {
        results["list_index_exact"] = "ValueError";
    }

    try {
        d: dict[str, int] = {"a": 1};
        x2: int = d.pop("z");
    } except KeyError {
        results["dict_pop_exact"] = "KeyError";
    }

    try {
        d2: dict[str, int] = {"a": 1};
        x3: int = d2.pop("z");
    } except LookupError {
        results["dict_pop_parent"] = "LookupError";
    }

    try {
        s: set = {1, 2, 3};
        s.remove(99);
    } except KeyError {
        results["set_remove_exact"] = "KeyError";
    }

    try {
        s2: set = {1, 2, 3};
        s2.remove(99);
    } except LookupError {
        results["set_remove_parent"] = "LookupError";
    }

    try {
        s3: set = set();
        s3.pop();
    } except KeyError {
        results["set_pop_empty"] = "KeyError";
    }

    which: str = "none";
    try {
        x4: int = "hello".index("xyz");
    } except TypeError {
        which = "TypeError";
    } except ValueError {
        which = "ValueError";
    } except Exception {
        which = "Exception";
    }
    results["multi_handler"] = which;

    parts: str = "";
    try {
        items4: list[int] = [1, 2, 3];
        items4.remove(99);
    } except ValueError {
        parts = "caught";
    } finally {
        parts = parts + "+finally";
    }
    results["runtime_finally"] = parts;

    return results;
}

def test_divzero_catch_exact_py() -> int {
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ZeroDivisionError {
        result = 1;
    }
    return result;
}

def test_divzero_catch_parent_py() -> int {
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except ArithmeticError {
        result = 1;
    }
    return result;
}

def test_divzero_catch_grandparent_py() -> int {
    result: int = 0;
    try {
        x: int = 1 / 0;
    } except Exception {
        result = 1;
    }
    return result;
}

def test_divzero_wrong_handler_py() -> int {
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

def test_modulo_zero_py() -> int {
    result: int = 0;
    try {
        x: int = 5 % 0;
    } except ArithmeticError {
        result = 1;
    }
    return result;
}

def test_index_oob_catch_exact_py() -> int {
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

def test_runtime_finally_py() -> int {
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
