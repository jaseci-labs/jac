"""Retained CPython constants become compiler-owned native values at the boundary."""
import from jaclang.runtime.python.objects {
    PyObj,
    PyNoneType,
    PyEllipsis,
    PyBool,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet
}
import from jaclang.runtime.python.compiler_integer { integer_from_marshal }
import from jaclang.runtime.python.native_services { take_buffer, runtime_failure }
import from c {
    def jacpy_value_kind(handle: u64) -> i64;  def jacpy_truth(handle: u64) -> i64;  def jacpy_marshal(
        handle: u64
    ) -> u64;  def jacpy_utf8(handle: u64) -> u64;  def jacpy_bytes_copy(
        handle: u64
    ) -> u64;  def jacpy_float_value(handle: u64) -> f64;  def jacpy_real(
        handle: u64
    ) -> f64;  def jacpy_imag(handle: u64) -> f64;  def jacpy_sequence(
        handle: u64
    ) -> u64;  def jacpy_sequence_size(handle: u64) -> i64;  def jacpy_sequence_item(
        handle: u64, index: i64
    ) -> u64;  def jacpy_release(handle: u64);
}

def read_constant(handle: u64, depth: int = 0) -> PyObj {
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
        return PyBool(t="bool", val=jacpy_truth(handle) != 0);
    }
    if kind == 3 {
        return integer_from_marshal(take_buffer(jacpy_marshal(handle)));
    }
    if kind == 4 {
        return PyFloat(t="float", val=float(jacpy_float_value(handle)));
    }
    if kind == 5 {
        return PyComplex(
            t="complex", real=float(jacpy_real(handle)), imag=float(jacpy_imag(handle))
        );
    }
    if kind == 6 {
        return PyStr(
            t="str",
            val=bytes(take_buffer(jacpy_utf8(handle))).decode("utf-8", "surrogatepass")
        );
    }
    if kind == 7 {
        return PyBytes(t="bytes", val=take_buffer(jacpy_bytes_copy(handle)));
    }
    if kind == 8 or kind == 9 {
        sequence = jacpy_sequence(handle);
        if sequence == 0 {
            raise runtime_failure();
        }
        items: list[PyObj] = [];
        try {
            for index in range(int(jacpy_sequence_size(sequence))) {
                item = jacpy_sequence_item(sequence, i64(index));
                if item == 0 {
                    raise runtime_failure();
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
