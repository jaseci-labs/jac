"""Console builtin sub-dispatcher (extracted from call_native)."""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_CONSOLE_LOG,
    NATIVE_KIND_CONSOLE_INFO,
    NATIVE_KIND_CONSOLE_DEBUG,
    NATIVE_KIND_CONSOLE_ERROR,
    NATIVE_KIND_CONSOLE_WARN,
    NATIVE_KIND_CONSOLE_DIR,
    NATIVE_KIND_CONSOLE_ASSERT,
    NATIVE_KIND_CONSOLE_COUNT,
    NATIVE_KIND_CONSOLE_COUNT_RESET,
    NATIVE_KIND_CONSOLE_TIME,
    NATIVE_KIND_CONSOLE_TIME_END,
    NATIVE_KIND_CONSOLE_TIME_LOG,
    NATIVE_KIND_CONSOLE_GROUP,
    NATIVE_KIND_CONSOLE_GROUP_COLLAPSED,
    NATIVE_KIND_CONSOLE_GROUP_END,
    NATIVE_KIND_CONSOLE_TABLE
}
import from engine.src.builtins.console {
    js_console_log,
    js_console_info,
    js_console_debug,
    js_console_error,
    js_console_warn,
    js_console_dir,
    js_console_assert,
    js_console_count,
    js_console_countReset,
    js_console_time,
    js_console_timeEnd,
    js_console_timeLog,
    js_console_group,
    js_console_groupCollapsed,
    js_console_groupEnd,
    js_console_table
}

"""Dispatch console.* native kinds. Returns js_undefined() if kind is not a console op."""
def:pub dispatch_console(kind: int, args: list[JSValue]) -> JSValue {
    if kind == NATIVE_KIND_CONSOLE_LOG {
        return js_console_log(args);
    } elif kind == NATIVE_KIND_CONSOLE_INFO {
        return js_console_info(args);
    } elif kind == NATIVE_KIND_CONSOLE_DEBUG {
        return js_console_debug(args);
    } elif kind == NATIVE_KIND_CONSOLE_ERROR {
        return js_console_error(args);
    } elif kind == NATIVE_KIND_CONSOLE_WARN {
        return js_console_warn(args);
    } elif kind == NATIVE_KIND_CONSOLE_DIR {
        return js_console_dir(args);
    } elif kind == NATIVE_KIND_CONSOLE_ASSERT {
        return js_console_assert(args);
    } elif kind == NATIVE_KIND_CONSOLE_COUNT {
        return js_console_count(args);
    } elif kind == NATIVE_KIND_CONSOLE_COUNT_RESET {
        return js_console_countReset(args);
    } elif kind == NATIVE_KIND_CONSOLE_TIME {
        return js_console_time(args);
    } elif kind == NATIVE_KIND_CONSOLE_TIME_END {
        return js_console_timeEnd(args);
    } elif kind == NATIVE_KIND_CONSOLE_TIME_LOG {
        return js_console_timeLog(args);
    } elif kind == NATIVE_KIND_CONSOLE_GROUP {
        return js_console_group(args);
    } elif kind == NATIVE_KIND_CONSOLE_GROUP_COLLAPSED {
        return js_console_groupCollapsed(args);
    } elif kind == NATIVE_KIND_CONSOLE_GROUP_END {
        return js_console_groupEnd(args);
    } elif kind == NATIVE_KIND_CONSOLE_TABLE {
        return js_console_table(args);
    }
    return js_undefined();
}

def:pub is_console_kind(kind: int) -> bool {
    if kind == NATIVE_KIND_CONSOLE_LOG {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_INFO {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_DEBUG {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_ERROR {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_WARN {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_DIR {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_ASSERT {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_COUNT {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_COUNT_RESET {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_TIME {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_TIME_END {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_TIME_LOG {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_GROUP {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_GROUP_COLLAPSED {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_GROUP_END {
        return True;
    }
    if kind == NATIVE_KIND_CONSOLE_TABLE {
        return True;
    }
    return False;
}
