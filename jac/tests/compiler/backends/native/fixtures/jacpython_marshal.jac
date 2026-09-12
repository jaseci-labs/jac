import from jaclang.compiler.backends.py.jacpython.marshal_writer {
    marshal_constant,
    marshal_output
}
import from jaclang.runtime.python.objects {
    PyCode,
    PyObj,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PyBool,
    PySet,
    PySlice,
    py_none
}

def:pub probe_packet -> marshal_output {
    same = PyStr(t="str", val="repeat");
    values: list[PyObj] = [
        py_none(),
        PyBool(t="bool", val=True),
        PyInt(t="int", val=0),
        PyInt(t="int", val=-1),
        PyInt(t="int", val=-9223372036854775807 - 1),
        PyInt(t="int", val=9223372036854775807),
        PyFloat(t="float", val=-0.0),
        PyFloat(t="float", val=1.2345678901234567),
        PyComplex(t="complex", real=1.5, imag=-2.5),
        PyStr(t="str", val="\x00á中"),
        PyBytes(t="bytes", val=[0, 255, 128]),
        same,
        same,
        PySet(t="frozenset", items={"a": PyInt(t="int", val=7)}, frozen=True),
        PySlice(t="slice", start=py_none(), stop=PyInt(t="int", val=3), step=py_none())
    ];
    return marshal_constant(PyTuple(t="tuple", items=values));
}

def:pub code_packet -> marshal_output {
    code = PyCode(
        t="code",
        argcount=0,
        posonlyargcount=0,
        kwonlyargcount=0,
        stacksize=1,
        flags=0,
        co_code=[128, 0, 94, 3, 35, 0],
        consts=[PyInt(t="int", val=1)],
        names=[],
        varnames=[],
        cellvars=[],
        freevars=[],
        filename="probe.py",
        name="<module>",
        qualname="<module>",
        firstlineno=1,
        linetable=[],
        exceptiontable=[]
    );
    return marshal_constant(code);
}

def:pub diagnostic_probe -> int {
    import from jaclang.compiler.frontend.python.syntax_error {
        syntax_failure,
        split_source_lines,
        source_character_column
    }
    lines = split_source_lines("á\r\n中\rx\ny");
    if len(lines) != 4
        or lines[0] != "á\r\n"
        or lines[1] != "中\r"
        or lines[2] != "x\n"
        or lines[3] != "y" {
        return 1;
    }
    if source_character_column("á中x", 1) != 0
        or source_character_column("á中x", 2) != 1
        or source_character_column("á中x", 4) != 1
        or source_character_column("á中x", 5) != 2 {
        return 2;
    }
    try {
        raise syntax_failure(
            "invalid input",
            filename="probe.py",
            lineno=2,
            offset=3,
            end_lineno=2,
            end_offset=4,
            kind="IndentationError"
        );
    } except syntax_failure as error {
        if error.msg != "invalid input"
            or error.filename != "probe.py"
            or error.lineno != 2
            or error.offset != 3
            or error.end_offset != 4
            or error.kind != "IndentationError" {
            return 3;
        }
        return 0;
    }
    return 4;
}

def:pub packet_size(value: marshal_output) -> int {
    return len(value.data) if not value.error else -1;
}

def:pub packet_byte(value: marshal_output, index: int) -> int {
    return value.data[index];
}
