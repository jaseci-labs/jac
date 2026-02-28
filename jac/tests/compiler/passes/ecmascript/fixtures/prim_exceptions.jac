"""Exception hierarchy primitives: try/except with type hierarchy matching.

Cross-backend equivalence fixture — Python reference + client (JS) implementation.
All exceptions are raised explicitly (JS 1/0 yields Infinity, not an error).
"""

def exceptions_py() -> dict {
    results: dict = {};

    # basic_catch: raise ValueError, catch ValueError
    try {
        raise ValueError("test");
    } except ValueError {
        results["basic_catch"] = "caught";
    }

    # catch_parent: raise ZeroDivisionError, catch ArithmeticError
    try {
        raise ZeroDivisionError("div");
    } except ArithmeticError {
        results["catch_parent"] = "caught";
    }

    # catch_grandparent: raise ZeroDivisionError, catch Exception
    try {
        raise ZeroDivisionError("div2");
    } except Exception {
        results["catch_grandparent"] = "caught";
    }

    # catch_wrong_type: raise ValueError, inner catches TypeError -> falls through
    caught_wrong: str = "not caught";
    try {
        try {
            raise ValueError("val");
        } except TypeError {
            caught_wrong = "wrong handler";
        }
    } except Exception {
        caught_wrong = "fell through";
    }
    results["catch_wrong_type"] = caught_wrong;

    # multiple_handlers: raise KeyError, try TypeError then LookupError
    handler_name: str = "none";
    try {
        raise KeyError("k");
    } except TypeError {
        handler_name = "type_error";
    } except LookupError {
        handler_name = "lookup";
    } except Exception {
        handler_name = "exception";
    }
    results["multiple_handlers"] = handler_name;

    # nested_hierarchy: raise IndexError, catch LookupError
    try {
        raise IndexError("idx");
    } except LookupError {
        results["nested_hierarchy"] = "caught";
    }

    # finally_runs: raise ValueError, catch + finally
    parts: str = "";
    try {
        raise ValueError("v");
    } except ValueError {
        parts = "caught";
    } finally {
        parts = parts + "+finally";
    }
    results["finally_runs"] = parts;

    # no_exception: try/except — no raise, handler should not run
    no_exc_result: str = "no handler";
    try {
        x: int = 42;
    } except ValueError {
        no_exc_result = "handler ran";
    }
    results["no_exception"] = no_exc_result;

    # exception_message: raise ValueError("test msg"), catch as e
    try {
        raise ValueError("test msg");
    } except ValueError as e {
        results["exception_message"] = "test msg" in str(e);
    }

    return results;
}

cl def exceptions_cl() -> dict {
    results: dict = {};

    # basic_catch: raise ValueError, catch ValueError
    try {
        raise ValueError("test");
    } except ValueError {
        results["basic_catch"] = "caught";
    }

    # catch_parent: raise ZeroDivisionError, catch ArithmeticError
    try {
        raise ZeroDivisionError("div");
    } except ArithmeticError {
        results["catch_parent"] = "caught";
    }

    # catch_grandparent: raise ZeroDivisionError, catch Exception
    try {
        raise ZeroDivisionError("div2");
    } except Exception {
        results["catch_grandparent"] = "caught";
    }

    # catch_wrong_type: raise ValueError, inner catches TypeError -> falls through
    caught_wrong: str = "not caught";
    try {
        try {
            raise ValueError("val");
        } except TypeError {
            caught_wrong = "wrong handler";
        }
    } except Exception {
        caught_wrong = "fell through";
    }
    results["catch_wrong_type"] = caught_wrong;

    # multiple_handlers: raise KeyError, try TypeError then LookupError
    handler_name: str = "none";
    try {
        raise KeyError("k");
    } except TypeError {
        handler_name = "type_error";
    } except LookupError {
        handler_name = "lookup";
    } except Exception {
        handler_name = "exception";
    }
    results["multiple_handlers"] = handler_name;

    # nested_hierarchy: raise IndexError, catch LookupError
    try {
        raise IndexError("idx");
    } except LookupError {
        results["nested_hierarchy"] = "caught";
    }

    # finally_runs: raise ValueError, catch + finally
    parts: str = "";
    try {
        raise ValueError("v");
    } except ValueError {
        parts = "caught";
    } finally {
        parts = parts + "+finally";
    }
    results["finally_runs"] = parts;

    # no_exception: try/except — no raise, handler should not run
    no_exc_result: str = "no handler";
    try {
        x: int = 42;
    } except ValueError {
        no_exc_result = "handler ran";
    }
    results["no_exception"] = no_exc_result;

    # exception_message: raise ValueError("test msg"), catch as e
    try {
        raise ValueError("test msg");
    } except ValueError as e {
        results["exception_message"] = "test msg" in str(e);
    }

    return results;
}
