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
import from jaclang.runtime.python.compiler_integer {
    integer_from_digits,
    integer_decimal,
    integer_from_marshal,
    integer_add,
    integer_negate,
    integer_to_float,
    PyBigInt
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
        PySlice(t="slice", start=py_none(), stop=PyInt(t="int", val=3), step=py_none()),
        integer_from_digits([0, 0, 0, 0, 0, 0, 1024], False),
        integer_from_digits([0, 0, 0, 0, 0, 0, 1024], True),
        integer_from_digits([0, 0, 0, 0, 8], True),
        PyStr(t="str", val="repeat"),
        PyFloat(t="float", val=1.2345678901234567),
        PyFloat(t="float", val=1.2345678901234569),
        PyFloat(t="float", val=0.0)
    ];
    return marshal_constant(PyTuple(t="tuple", items=values));
}

def sample_code -> PyCode {
    return PyCode(
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
}

def:pub code_packet -> marshal_output {
    return marshal_constant(sample_code());
}

def:pub nested_code_packet -> marshal_output {
    return marshal_constant(PyTuple(t="tuple", items=[sample_code(), sample_code()]));
}

def:pub integer_arithmetic_packet -> marshal_output {
    one = PyInt(t="int", val=1);
    large = integer_from_digits([0, 0, 0, 0, 0, 0, 1024], False);
    halfway = integer_add(large, integer_from_digits([0, 0, 0, 4], False));
    values: list[PyObj] = [
        integer_add(PyInt(t="int", val=9223372036854775807), one),
        integer_negate(PyInt(t="int", val=-9223372036854775807 - 1)),
        integer_add(large, integer_negate(large)),
        integer_add(large, one, True),
        integer_add(integer_negate(large), one),
        PyFloat(t="float", val=integer_to_float(halfway)),
        PyFloat(t="float", val=integer_to_float(integer_add(halfway, one)))
    ];
    return marshal_constant(PyTuple(t="tuple", items=values));
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

def:pub integer_probe -> int {
    value = integer_from_digits([0, 0, 0, 0, 0, 0, 1024], True);
    if not isinstance(value, PyBigInt) {
        return 1;
    }
    if integer_decimal(value) != "-1267650600228229401496703205376" {
        return 2;
    }
    small = integer_from_digits([0, 0], True);
    if not isinstance(small, PyInt) or small.val != 0 {
        return 3;
    }
    decoded = integer_from_marshal([233, 255, 255, 255, 255]);
    if not isinstance(decoded, PyInt) or decoded.val != -1 {
        return 4;
    }
    decoded = integer_from_marshal(
        [108, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4]
    );
    if not isinstance(decoded, PyBigInt)
        or integer_decimal(decoded) != "1267650600228229401496703205376" {
        return 5;
    }
    try {
        integer_from_marshal([108, 1, 0, 0, 0, 255, 255]);
    } except ValueError {
        return 0;
    }
    return 6;
}

def:pub packet_size(value: marshal_output) -> int {
    return len(value.data) if not value.error else -1;
}

def:pub packet_byte(value: marshal_output, index: int) -> int {
    return value.data[index];
}
