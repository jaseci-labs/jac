"""Uncaught exception reporting for callbacks and top-level scripts."""

import from engine.src.ffi.libc { write }
import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_to_table_id
}
import from engine.src.runtime.jsobject { js_object_get }
import from engine.src.runtime.jsstring { str_intern, str_from_id }

def:priv _uncaught_stderr_writeln(msg: str) {
    s: str = msg + "\n";
    write(2, s, len(s));
}

"""Format and print an uncaught exception value to stderr (Node/Bun style)."""
def:pub print_uncaught(exc: JSValue) {
    if jsv_is_object_cell(exc) {
        stack_val: JSValue = js_object_get(exc, str_intern("__errorStackData__"));
        if not jsv_is_string_cell(stack_val) {
            # A user-set own "stack" data property (accessor setter) takes precedence.
            stack_val = js_object_get(exc, str_intern("stack"));
        }
        if jsv_is_string_cell(stack_val) {
            _uncaught_stderr_writeln(
                "Uncaught " + str_from_id(jsv_to_table_id(stack_val))
            );
        } else {
            name_val: JSValue = js_object_get(exc, str_intern("name"));
            msg_val: JSValue = js_object_get(exc, str_intern("message"));
            n: str = str_from_id(jsv_to_table_id(name_val))
                if jsv_is_string_cell(name_val)
                else "Error";
            m: str = str_from_id(jsv_to_table_id(msg_val))
                if jsv_is_string_cell(msg_val)
                else "";
            if m == "" {
                _uncaught_stderr_writeln("Uncaught " + n);
            } else {
                _uncaught_stderr_writeln("Uncaught " + n + ": " + m);
            }
        }
    } elif jsv_is_string_cell(exc) {
        _uncaught_stderr_writeln("Uncaught " + str_from_id(jsv_to_table_id(exc)));
    } elif jsv_is_undefined(exc) {
        _uncaught_stderr_writeln("Uncaught undefined");
    } else {
        _uncaught_stderr_writeln("Uncaught exception");
    }
}

"""Report an exception from an async callback (timer/fs/net). Does not clear VM state."""
def:pub report_callback_exception(exc: JSValue) {
    print_uncaught(exc);
}

"""The reason of a rejection as Node prints it: the stack when there is one,
else "Name: message", else the string form."""
def:pub format_rejection_reason(reason: JSValue) -> str {
    if jsv_is_object_cell(reason) {
        stack_val: JSValue = js_object_get(reason, str_intern("__errorStackData__"));
        if not jsv_is_string_cell(stack_val) {
            stack_val = js_object_get(reason, str_intern("stack"));
        }
        if jsv_is_string_cell(stack_val) {
            return str_from_id(jsv_to_table_id(stack_val));
        }
        name_val: JSValue = js_object_get(reason, str_intern("name"));
        msg_val: JSValue = js_object_get(reason, str_intern("message"));
        n: str = str_from_id(jsv_to_table_id(name_val))
            if jsv_is_string_cell(name_val)
            else "";
        m: str = str_from_id(jsv_to_table_id(msg_val))
            if jsv_is_string_cell(msg_val)
            else "";
        if n != "" and m != "" {
            return n + ": " + m;
        }
        if n != "" {
            return n;
        }
        if m != "" {
            return m;
        }
        return "[object Object]";
    }
    if jsv_is_string_cell(reason) {
        return str_from_id(jsv_to_table_id(reason));
    }
    if jsv_is_undefined(reason) {
        return "undefined";
    }
    return "(unknown rejection)";
}

"""--unhandled-rejections=warn / warn-with-error-code: Node's warning instead of
a fatal error."""
def:pub print_unhandled_rejection_warning(
    reason: JSValue, pid: int, rejection_id: int
) {
    tag: str = "(node:" + str(pid) + ") UnhandledPromiseRejectionWarning: ";
    _uncaught_stderr_writeln(tag + format_rejection_reason(reason));
    _uncaught_stderr_writeln(
        tag
            + "Unhandled promise rejection. This error originated either by throwing inside of an async function without a catch block, or by rejecting a promise which was not handled with .catch(). To terminate the process on unhandled promise rejection, use the CLI flag `--unhandled-rejections=strict`. (rejection id: "
            + str(rejection_id)
            + ")"
    );
}

"""
Print an unhandled promise rejection to stderr:
  Uncaught (in promise) TypeError: bad type
      at doIt (file.js:1)
      at Object.<anonymous> (file.js:2)

For non-Error rejections falls back to a plain string representation. Node and
bun both report unhandled rejections on stderr (and exit 1 when no listener
handles them — see vm_handle_unhandled_rejection).
"""
def:pub print_unhandled_rejection(reason: JSValue) -> None {
    if jsv_is_object_cell(reason) {
        stack_val: JSValue = js_object_get(reason, str_intern("__errorStackData__"));
        if not jsv_is_string_cell(stack_val) {
            stack_val = js_object_get(reason, str_intern("stack"));
        }
        if jsv_is_string_cell(stack_val) {
            _uncaught_stderr_writeln(
                "Uncaught (in promise) " + str_from_id(jsv_to_table_id(stack_val))
            );
            return;
        }
        # Object without a stack — try name/message
        name_val: JSValue = js_object_get(reason, str_intern("name"));
        msg_val: JSValue = js_object_get(reason, str_intern("message"));
        n: str = str_from_id(jsv_to_table_id(name_val))
            if jsv_is_string_cell(name_val)
            else "";
        m: str = str_from_id(jsv_to_table_id(msg_val))
            if jsv_is_string_cell(msg_val)
            else "";
        if n != "" and m != "" {
            _uncaught_stderr_writeln("Uncaught (in promise) " + n + ": " + m);
            return;
        }
        if n != "" {
            _uncaught_stderr_writeln("Uncaught (in promise) " + n);
            return;
        }
        if m != "" {
            _uncaught_stderr_writeln("Uncaught (in promise) " + m);
            return;
        }
        _uncaught_stderr_writeln("Uncaught (in promise) [object Object]");
    } elif jsv_is_string_cell(reason) {
        _uncaught_stderr_writeln(
            "Uncaught (in promise) " + str_from_id(jsv_to_table_id(reason))
        );
    } elif jsv_is_undefined(reason) {
        _uncaught_stderr_writeln("Uncaught (in promise) undefined");
    } else {
        _uncaught_stderr_writeln("Uncaught (in promise) (unknown rejection)");
    }
}
