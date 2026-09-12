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

def:pub packet_size(value: marshal_output) -> int {
    return len(value.data) if not value.error else -1;
}

def:pub packet_byte(value: marshal_output, index: int) -> int {
    return value.data[index];
}
