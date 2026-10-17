"""Retained CPython constants become compiler-owned native values at the boundary."""

def read_constant(handle: ptr[PyObject], depth: int = 0) -> PyObj {
    if depth > 1000 {
        raise RecursionError("maximum recursion depth exceeded during compilation");
    }
    kind = int(jacpy_value_kind(handle));
    if kind == 0 {
        return PyNoneType(t="none");
    }
    if kind == 1 {
        return PyEllipsis(t="ellipsis");
    }
    if kind == 2 {
        return PyBool(t="bool", val=PyObject_IsTrue(handle) != 0);
    }
    if kind == 3 {
        return integer_from_marshal(take_buffer(jacpy_marshal(handle)));
    }
    if kind == 4 {
        return PyFloat(t="float", val=float(jacpy_float_value(handle)));
    }
    if kind == 5 {
        return PyComplex(
            t="complex",
            real=float(PyComplex_RealAsDouble(handle)),
            imag=float(PyComplex_ImagAsDouble(handle))
        );
    }
    if kind == 6 {
        return PyStr(
            t="str",
            val=take_buffer(jacpy_utf8(handle)).decode("utf-8", "surrogatepass")
        );
    }
    if kind == 7 {
        return PyBytes(t="bytes", val=list(read_buffer(handle)));
    }
    if kind == 8 or kind == 9 {
        sequence = PySequence_List(handle);
        if sequence == 0 {
            raise boundary_failure();
        }
        items: list[PyObj] = [];
        try {
            for index in range(int(jacpy_sequence_size(sequence))) {
                item = jacpy_sequence_item(sequence, i64(index));
                if item == 0 {
                    raise boundary_failure();
                }
                try {
                    items.append(read_constant(item, depth + 1));
                } finally {
                    jacpy_release(item);
                }
            }
        } finally {
            jacpy_release(sequence);
        }
        if kind == 8 {
            return PyTuple(t="tuple", items=items);
        }
        mapping: dict[str, PyObj] = {};
        for index in range(len(items)) {
            mapping[str(index)] = items[index];
        }
        return PySet(t="frozenset", frozen=True, items=mapping);
    }
    raise TypeError("Invalid AST constant");
}
