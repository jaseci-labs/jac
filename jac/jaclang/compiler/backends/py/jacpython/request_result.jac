"""Native request results shared by compiler and streaming adapters."""
import from jaclang.compiler.backends.py.jacpython.marshal_writer {
    marshal_output,
    marshal_constant
}
import from jaclang.compiler.frontend.python.ast_nodes { mod }
import from jaclang.compiler.frontend.python.syntax_error { syntax_failure }
import from jaclang.runtime.python.objects { PyObj, PyStr, PyInt, PyNoneType, PyTuple }

obj native_result {
    has packet: marshal_output = marshal_output(),
        tree: mod | None = None,
        runtime_error: bool = False,
        value_handle: u64 = 0,
        eof: bool = False;
}

def error_packet(error: syntax_failure) -> native_result {
    location: list[PyObj] = [
        PyStr(t="str", val=error.kind),
        PyStr(t="str", val=error.msg),
        PyStr(t="str", val=error.filename),
        PyInt(t="int", val=error.lineno),
        PyInt(t="int", val=error.offset),
        PyStr(t="str", val=error.text)
            if error.text is not None
            else PyNoneType(t="none"),
        PyInt(t="int", val=error.end_lineno),
        PyInt(t="int", val=error.end_offset)
    ];
    return native_result(packet=marshal_constant(PyTuple(t="tuple", items=location)));
}
