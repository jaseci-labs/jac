"""Runtime error hierarchy tests: catch implicit errors by parent type.

Unlike prim_exceptions.jac (explicit raise), these tests trigger ACTUAL runtime
errors from method calls and verify they're caught by the correct handler in
the exception hierarchy.

Note: JS 1/0 yields Infinity (not an error), so we test operations that DO
throw: str.index, list.remove, list.index, dict.pop, set.remove, set.pop.
"""

def runtime_errors_py() -> dict {
    results: dict = {};

    # str_index_exact: str.index not found caught by ValueError
    try {
        x: int = "hello".index("xyz");
    } except ValueError {
        results["str_index_exact"] = "ValueError";
    }

    # str_index_parent: str.index not found caught by Exception (parent)
    try {
        x: int = "hello".index("xyz");
    } except Exception {
        results["str_index_parent"] = "Exception";
    }

    # str_index_wrong: str.index not found NOT caught by TypeError
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

    # list_remove_exact: list.remove not found caught by ValueError
    try {
        items: list[int] = [1, 2, 3];
        items.remove(99);
    } except ValueError {
        results["list_remove_exact"] = "ValueError";
    }

    # list_remove_parent: list.remove not found caught by Exception
    try {
        items2: list[int] = [1, 2, 3];
        items2.remove(99);
    } except Exception {
        results["list_remove_parent"] = "Exception";
    }

    # list_index_exact: list.index not found caught by ValueError
    try {
        items3: list[int] = [1, 2, 3];
        x: int = items3.index(99);
    } except ValueError {
        results["list_index_exact"] = "ValueError";
    }

    # dict_pop_exact: dict.pop missing key caught by KeyError
    try {
        d: dict[str, int] = {"a": 1};
        x2: int = d.pop("z");
    } except KeyError {
        results["dict_pop_exact"] = "KeyError";
    }

    # dict_pop_parent: dict.pop missing key caught by LookupError
    try {
        d2: dict[str, int] = {"a": 1};
        x3: int = d2.pop("z");
    } except LookupError {
        results["dict_pop_parent"] = "LookupError";
    }

    # set_remove_exact: set.remove missing element caught by KeyError
    try {
        s: set = {1, 2, 3};
        s.remove(99);
    } except KeyError {
        results["set_remove_exact"] = "KeyError";
    }

    # set_remove_parent: set.remove caught by LookupError
    try {
        s2: set = {1, 2, 3};
        s2.remove(99);
    } except LookupError {
        results["set_remove_parent"] = "LookupError";
    }

    # set_pop_empty: set.pop on empty set caught by KeyError
    try {
        s3: set = set();
        s3.pop();
    } except KeyError {
        results["set_pop_empty"] = "KeyError";
    }

    # multi_handler: str.index with multiple handlers
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

    # runtime_finally: runtime error with finally block
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

    # str_index_exact: str.index not found caught by ValueError
    try {
        x: int = "hello".index("xyz");
    } except ValueError {
        results["str_index_exact"] = "ValueError";
    }

    # str_index_parent: str.index not found caught by Exception (parent)
    try {
        x: int = "hello".index("xyz");
    } except Exception {
        results["str_index_parent"] = "Exception";
    }

    # str_index_wrong: str.index not found NOT caught by TypeError
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

    # list_remove_exact: list.remove not found caught by ValueError
    try {
        items: list[int] = [1, 2, 3];
        items.remove(99);
    } except ValueError {
        results["list_remove_exact"] = "ValueError";
    }

    # list_remove_parent: list.remove not found caught by Exception
    try {
        items2: list[int] = [1, 2, 3];
        items2.remove(99);
    } except Exception {
        results["list_remove_parent"] = "Exception";
    }

    # list_index_exact: list.index not found caught by ValueError
    try {
        items3: list[int] = [1, 2, 3];
        x: int = items3.index(99);
    } except ValueError {
        results["list_index_exact"] = "ValueError";
    }

    # dict_pop_exact: dict.pop missing key caught by KeyError
    try {
        d: dict[str, int] = {"a": 1};
        x2: int = d.pop("z");
    } except KeyError {
        results["dict_pop_exact"] = "KeyError";
    }

    # dict_pop_parent: dict.pop missing key caught by LookupError
    try {
        d2: dict[str, int] = {"a": 1};
        x3: int = d2.pop("z");
    } except LookupError {
        results["dict_pop_parent"] = "LookupError";
    }

    # set_remove_exact: set.remove missing element caught by KeyError
    try {
        s: set = {1, 2, 3};
        s.remove(99);
    } except KeyError {
        results["set_remove_exact"] = "KeyError";
    }

    # set_remove_parent: set.remove caught by LookupError
    try {
        s2: set = {1, 2, 3};
        s2.remove(99);
    } except LookupError {
        results["set_remove_parent"] = "LookupError";
    }

    # set_pop_empty: set.pop on empty set caught by KeyError
    try {
        s3: set = set();
        s3.pop();
    } except KeyError {
        results["set_pop_empty"] = "KeyError";
    }

    # multi_handler: str.index with multiple handlers
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

    # runtime_finally: runtime error with finally block
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
