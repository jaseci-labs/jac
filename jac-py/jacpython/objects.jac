# jacpython object core -- the na-clean leaf (jac-py/PLAN.md §5, §4 module note).
#
# This module is the acyclic base of the runtime: the PyObj hierarchy's DATA
# types and their value/container slots, plus pure helpers. It has NO imports,
# NO host calls, and NO eval -- so it is native-compilable (T7). The callable/
# heap/proxy types (PyFunction/PyClass/PyUserObj/PyHostProxy) live in the ceval
# module and OVERRIDE these slots via cross-module inheritance; the marshal
# reader and ceval import FROM here. Jac forbids import cycles, so anything that
# reaches the host or re-enters the interpreter must stay out of this file.
#
# Behavior dispatches through virtual slot methods (CPython's tp_*/nb_*/sq_*/mp_*
# tables as overridable methods -> na vtable, no function-pointer indirection).
# The `t` tag is a tp_name label (isinstance / exception matching), NOT a
# behavior selector -- selection is virtual dispatch on the receiver.
# CPython Py_LT..Py_GE richcompare op kinds (shared by abstract_protocol and
# every tp_richcompare implementation).
glob Py_LT: int = 0,
     Py_LE: int = 1,
     Py_EQ: int = 2,
     Py_NE: int = 3,
     Py_GT: int = 4,
     Py_GE: int = 5;

# Reflected comparison kind: < <-> >, <= <-> >=, ==/!= are self-reflected.
glob _PY_SWAPPED_OP: list[int] = [4, 5, 2, 3, 0, 1];

obj PyObj {
    has t: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython ``object_richcompare``: == and != are identity tests. A
        # non-identical operand yields PY_NOT_IMPLEMENTED so the caller
        # (PyObject_RichCompare / user_compare) runs its own identity fallback
        # after trying any overridden reflected slot; ordering is unsupported.
        # NEVER compare type tags here -- two distinct instances of the same
        # type would otherwise compare equal.
        if kind == 2 {
            return PyBool(t="bool", val=self is other);
        }
        if kind == 3 {
            return PyBool(t="bool", val=self is not other);
        }
        return PY_NOT_IMPLEMENTED;
    }

    def mp_subscript(index: PyObj) -> PyObj {
        return py_error("TypeError", "object is not subscriptable");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        return py_error("TypeError", "object does not support item assignment");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        return py_error("TypeError", "object does not support item deletion");
    }

    def tp_iter -> PyObj {
        return py_error("TypeError", "object is not iterable");
    }

    def tp_bool -> bool {
        return True;
    }

    def tp_getattro(name: str) -> PyObj {
        return py_error("AttributeError", name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error("TypeError", "object is not callable");
    }

    # Canonical dict/set key string (the internal hash-key protocol). Encodes a
    # VALUE into a type-prefixed, collision-safe string so the backing Jac dict
    # keys on value-equality with Python's numeric collapse (see PyInt/PyFloat).
    # The empty string is the "unhashable" sentinel (na-clean: no exceptions in
    # this leaf) -- callers turn it into a TypeError. Real keys are never empty
    # (every hashable type emits a non-empty prefix).
    def tp_hashkey -> str {
        return "";
    }

    # __index__: the PyInt to use when this object is a sequence index / slice
    # bound. int is itself; bool coerces; a builtin-int subclass (a PyUserObj
    # boxing an int, e.g. re._constants._NamedIntConstant) unwraps to its base.
    # Everything else is not an integer index.
    def to_index -> PyObj {
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }
}

obj PyInt(PyObj) {
    has val: int;

    def to_index -> PyObj {
        return self;
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if other.t != "int" {
            return py_error("TypeError", "unsupported operand types");
        }
        b = (other as PyInt).val;
        a = self.val;
        if kind == 0 {
            return PyInt(t="int", val=a + b);
        }
        if kind == 5 {
            return PyInt(t="int", val=a * b);
        }
        if kind == 6 {
            if b == 0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyInt(t="int", val=a % b);
        }
        if kind == 10 {
            return PyInt(t="int", val=a - b);
        }
        if kind == 1 {
            return PyInt(t="int", val=a & b);
        }
        if kind == 2 {
            if b == 0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyInt(t="int", val=a // b);
        }
        if kind == 7 {
            return PyInt(t="int", val=a | b);
        }
        # NB_TRUE_DIVIDE (11): int / int is always float, even when it divides
        # evenly (6 / 2 == 3.0, not 3). NB_XOR is a separate oparg (12).
        if kind == 11 {
            if b == 0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=float(a) / float(b));
        }
        if kind == 12 {
            return PyInt(t="int", val=a ^ b);
        }
        if kind == 3 {
            if b < 0 {
                return py_error("ValueError", "negative shift count");
            }
            return PyInt(t="int", val=a << b);
        }
        if kind == 9 {
            if b < 0 {
                return py_error("ValueError", "negative shift count");
            }
            return PyInt(t="int", val=a >> b);
        }
        if kind == 8 {
            # int ** negative -> float (2 ** -1 == 0.5); 0 ** negative raises.
            if b < 0 {
                if a == 0 {
                    return py_error(
                        "ZeroDivisionError", "0.0 cannot be raised to a negative power"
                    );
                }
                return PyFloat(t="float", val=float(a) ** float(b));
            }
            return PyInt(t="int", val=a ** b);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # int vs int/bool: exact integer comparison (bool is an int subclass,
        # so `1 == True` and `0 < False` compare by numeric value).
        if other.t == "int" or other.t == "bool" {
            a = self.val;
            b = 0;
            if other.t == "int" {
                b = (other as PyInt).val;
            } elif (other as PyBool).val {
                b = 1;
            }
            return _bool_from_cmp(_cmp3(a, b), kind);
        }
        # int-on-left vs float-on-right: CPython returns NotImplemented from
        # int.__cmp__ and runs the reflected float comparison. py_compare has no
        # NotImplemented plumbing, so promote self to float and reuse PyFloat's
        # coercion + NaN rules directly (the reflected result is identical).
        if other.t == "float" {
            return PyFloat(t="float", val=float(self.val)).tp_richcompare(kind, other);
        }
        # Non-numeric right operand: identity-tag (in)equality only.
        if kind == 2 {
            return PyBool(t="bool", val=False);
        }
        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_bool -> bool {
        return self.val != 0;
    }
    # Shared numeric namespace so `hash(1) == hash(1.0) == hash(True)` and all
    # three key the same dict/set slot (PyBool and integral PyFloat emit "n:" too).
    def tp_hashkey -> str {
        return "n:" + str(self.val);
    }
    # int is its own real part / numerator; imag is 0, denominator is 1.
    def tp_getattro(name: str) -> PyObj {
        if name == "real" or name == "numerator" {
            return PyInt(t="int", val=self.val);
        }
        if name == "imag" {
            return PyInt(t="int", val=0);
        }
        if name == "denominator" {
            return PyInt(t="int", val=1);
        }
        return py_error("AttributeError", name);
    }
}

obj PyStr(PyObj) {
    has val: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "str" {
            return PyStr(t="str", val=self.val + (other as PyStr).val);
        }
        if kind == 6 {
            return str_mod_format(self.val, other);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if other.t != "str" {
            if kind == 2 {
                return PyBool(t="bool", val=False);
            }
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        a = self.val;
        b = (other as PyStr).val;
        return _bool_from_cmp(_cmp3_str(a, b), kind);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            return PyStr(t="str", val=_slice_str(self.val, index as PySlice));
        }
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "string indices must be integers or slices");
        }
        i = (idx as PyInt).val;
        text = self.val;
        if i < 0 {
            i = len(text) + i;
        }
        if i >= 0 and i < len(text) {
            return PyStr(t="str", val=text[i]);
        }
        return py_error("IndexError", "string index out of range");
    }

    def tp_iter -> PyObj {
        chars: list[PyObj] = [];
        for ch in self.val {
            chars.append(PyStr(t="str", val=ch));
        }
        return PyIter(t="iter", items=chars, index=0);
    }

    def tp_bool -> bool {
        return len(self.val) != 0;
    }
    # "s:" keeps strings disjoint from the numeric namespace (the string "n:5"
    # hashes to "s:n:5", never colliding with int 5's "n:5").
    def tp_hashkey -> str {
        return "s:" + self.val;
    }
}

obj PyBytes(PyObj) {
    has val: list[int];

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            return PyBytes(t="bytes", val=_slice_ints(self.val, index as PySlice));
        }
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "bytes indices must be integers or slices");
        }
        i = (idx as PyInt).val;
        vals = self.val;
        if i < 0 {
            i = len(vals) + i;
        }
        if i >= 0 and i < len(vals) {
            return PyInt(t="int", val=vals[i]);
        }
        return py_error("IndexError", "index out of range");
    }

    def tp_bool -> bool {
        return len(self.val) != 0;
    }

    def tp_hashkey -> str {
        key = "b:";
        for v in self.val {
            key = key + str(v) + ",";
        }
        return key;
    }
}

obj PyFloat(PyObj) {
    has val: float;
    # Numeric coercion: float ops accept int/bool operands and promote to float
    # (CPython nb_float coercion). Returns True in the first slot iff `other` is a
    # numeric the float protocol can absorb; the coerced value lands in `out`.
    def _coerce(other: PyObj) -> tuple[bool, float] {
        if other.t == "float" {
            return (True, (other as PyFloat).val);
        }
        if other.t == "int" {
            return (True, float((other as PyInt).val));
        }
        if other.t == "bool" {
            if (other as PyBool).val {
                return (True, 1.0);
            }
            return (True, 0.0);
        }
        return (False, 0.0);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        (ok, b) = self._coerce(other);
        if not ok {
            return py_error("TypeError", "unsupported operand types");
        }
        a = self.val;
        if kind == 0 {
            return PyFloat(t="float", val=a + b);
        }
        if kind == 5 {
            return PyFloat(t="float", val=a * b);
        }
        if kind == 10 {
            return PyFloat(t="float", val=a - b);
        }
        if kind == 11 {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a / b);
        }
        if kind == 6 {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a % b);
        }
        if kind == 2 {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a // b);
        }
        if kind == 8 {
            return PyFloat(t="float", val=a ** b);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        (ok, b) = self._coerce(other);
        if not ok {
            if kind == 2 {
                return PyBool(t="bool", val=False);
            }
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        a = self.val;
        # NaN comparisons: every operator but != is False, != is True. The
        # underlying float operators already encode this, so no special-casing.
        if kind == 0 {
            return PyBool(t="bool", val=a < b);
        }
        if kind == 1 {
            return PyBool(t="bool", val=a <= b);
        }
        if kind == 2 {
            return PyBool(t="bool", val=a == b);
        }
        if kind == 3 {
            return PyBool(t="bool", val=a != b);
        }
        if kind == 4 {
            return PyBool(t="bool", val=a > b);
        }
        if kind == 5 {
            return PyBool(t="bool", val=a >= b);
        }
        return PyBool(t="bool", val=False);
    }

    def tp_bool -> bool {
        return self.val != 0.0;
    }
    # Integral floats collapse into the shared "n:" namespace (1.0 keys with
    # int 1); non-integral floats live in "f:". inf/nan are detected without
    # float("inf") parsing (na-safe): v != v is nan, v*0.0 != 0.0 is +/-inf.
    # NB: all nan collapse to one key (value-based), unlike CPython's per-object
    # nan keys -- an accepted edge divergence given the leaf has no key identity.
    def tp_hashkey -> str {
        v = self.val;
        if v != v {
            return "f:nan";
        }
        if v * 0.0 != 0.0 {
            return "f:" + str(v);
        }
        iv = int(v);
        if float(iv) == v {
            return "n:" + str(iv);
        }
        return "f:" + str(v);
    }
}

obj PyBool(PyObj) {
    has val: bool;

    def tp_bool -> bool {
        return self.val;
    }
    # bool is an int subclass: True indexes as 1, False as 0.
    def to_index -> PyObj {
        if self.val {
            return PyInt(t="int", val=1);
        }
        return PyInt(t="int", val=0);
    }
    # bool is an int subclass: True keys as int 1, False as int 0.
    def tp_hashkey -> str {
        if self.val {
            return "n:1";
        }
        return "n:0";
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # bool is an int subclass: ``True == 1`` mirrors ``1 == True``.
        if other.t == "int" or other.t == "bool" {
            a = 0;
            if self.val {
                a = 1;
            }
            b = 0;
            if other.t == "int" {
                b = (other as PyInt).val;
            } elif (other as PyBool).val {
                b = 1;
            }
            return _bool_from_cmp(_cmp3(a, b), kind);
        }
        if kind == 2 {
            return PyBool(t="bool", val=False);
        }
        if kind == 3 {
            return PyBool(t="bool", val=True);
        }
        return PY_NOT_IMPLEMENTED;
    }
    # bool is an int subclass: real/numerator are int 0 or 1 (not bool), imag 0.
    def tp_getattro(name: str) -> PyObj {
        v = 0;
        if self.val {
            v = 1;
        }
        if name == "real" or name == "numerator" {
            return PyInt(t="int", val=v);
        }
        if name == "imag" {
            return PyInt(t="int", val=0);
        }
        if name == "denominator" {
            return PyInt(t="int", val=1);
        }
        return py_error("AttributeError", name);
    }
}

obj PyNoneType(PyObj) {
    def tp_bool -> bool {
        return False;
    }

    def tp_hashkey -> str {
        return "none";
    }
}

obj PyComplex(PyObj) {
    has real: float,
        imag: float;
}

obj PySlice(PyObj) {
    has start: PyObj,
        stop: PyObj,
        step: PyObj;
}

obj PyTuple(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "tuple" {
            return PyTuple(
                t="tuple", items=concat_items(self.items, (other as PyTuple).items)
            );
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            return PyTuple(t="tuple", items=_slice_objs(self.items, index as PySlice));
        }
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "tuple indices must be integers or slices");
        }
        i = (idx as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            return self.items[i];
        }
        return py_error("IndexError", "tuple index out of range");
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
    # Recursive, length-framed so ("a","b") and ("a","b","") stay distinct.
    # An unhashable element (empty sub-key) makes the whole tuple unhashable.
    def tp_hashkey -> str {
        key = "t:";
        for item in self.items {
            sub = item.tp_hashkey();
            if sub == "" {
                return "";
            }
            key = key + str(len(sub)) + ":" + sub;
        }
        return key;
    }
}

obj PyList(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == 0 and other.t == "list" {
            return PyList(
                t="list", items=concat_items(self.items, (other as PyList).items)
            );
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def mp_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            return PyList(t="list", items=_slice_objs(self.items, index as PySlice));
        }
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "list indices must be integers or slices");
        }
        i = (idx as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            return self.items[i];
        }
        return py_error("IndexError", "list index out of range");
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "list indices must be integers");
        }
        i = (idx as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            self.items[i] = value;
            return py_none();
        }
        return py_error("IndexError", "list assignment index out of range");
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            # del lst[a:b:c] -- rebuild the list without the sliced positions
            # (re._constants does `del OPCODES[-2:]`).
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            b = slice_indices(index as PySlice, len(self.items));
            si = b[0];
            stop = b[1];
            step = b[2];
            drop: dict[int, bool] = {};
            if step > 0 {
                while si < stop {
                    drop[si] = True;
                    si = si + step;
                }
            } else {
                while si > stop {
                    drop[si] = True;
                    si = si + step;
                }
            }
            kept: list[PyObj] = [];
            k = 0;
            while k < len(self.items) {
                if not (k in drop) {
                    kept.append(self.items[k]);
                }
                k = k + 1;
            }
            self.items = kept;
            return py_none();
        }
        idx = index.to_index();
        if is_error(idx) {
            return py_error("TypeError", "list indices must be integers");
        }
        i = (idx as PyInt).val;
        if i < 0 {
            i = len(self.items) + i;
        }
        if i >= 0 and i < len(self.items) {
            _py_container_del(self.items, i);
            return py_none();
        }
        return py_error("IndexError", "list assignment index out of range");
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

# PyCode -- jacpython's direct code-object carrier (PLAN.md P0.1 contract).
#
# Pinned to CPython 3.14.6 (CURRENT.md). The native compiler assembles PyCode
# in-process; marshal is test-oracle transport only.
#
# Bytecode layout:
#   - co_code is a list of 16-bit code units (opcode, oparg pairs).
#   - Jump and exception-handler offsets are measured in code units, not bytes.
#   - EXTENDED_ARG (opcode_meta.OP_EXTENDED_ARG) prefixes fold high oparg bits
#     into the following real instruction.
#   - Instructions with inline caches are followed by OP_CACHE padding; width is
#     2 + opcode_cache_count(op) code units (see opcode_meta.jac).
#
# Locals-plus (merged fast locals layout, CPython 3.11+):
#   [varnames][non-argument cellvars][freevars]
#   Argument cells live only in varnames; resolve_cell() in pyc_first maps a
#   merged LOAD_FAST/_DEREF index to the correct PyCell.
#
# Exception table (co.exceptiontable):
#   Varint-encoded entries: start*2, length*2, target*2, depth<<1|lasti per
#   read_varint()/find_handler() in pyc_first.jac.
#
# Ownership: argcount/posonlyargcount/kwonlyargcount, stacksize, flags,
# co_code, consts (recursive PyCode allowed), names, var/cell/free names,
# filename/name/qualname, firstlineno, linetable, exceptiontable.
obj PyCode(PyObj) {
    has argcount: int,
        posonlyargcount: int,
        kwonlyargcount: int,
        stacksize: int,
        flags: int,
        co_code: list[int],
        consts: list[PyObj],
        names: list[str],
        varnames: list[str],
        cellvars: list[str],
        freevars: list[str],
        filename: str,
        name: str,
        qualname: str,
        firstlineno: int,
        linetable: list[int],
        exceptiontable: list[int];

    # Each nested PyCode in a const table must stay distinct (deco vs f). The
    # default PyObj hashkey is "" and would incorrectly dedupe all code objects.
    def tp_hashkey -> str {
        result = (
            "code:"
            + self.name
            + ":"
            + self.qualname
            + ":"
            + str(self.firstlineno)
            + ":"
            + str(len(self.co_code))
        );
        ci = 0;
        while ci < len(self.co_code) {
            result = result + ":" + str(self.co_code[ci]);
            ci = ci + 1;
        }
        return result;
    }

    # Expose the CPython-visible co_* attribute surface so introspection
    # (inspect, dis, f.__code__.co_name, gen.gi_frame-style access) works.
    # Field names differ from the public names (argcount -> co_argcount etc.).
    def tp_getattro(name: str) -> PyObj {
        if name == "co_argcount" {
            return PyInt(t="int", val=self.argcount);
        }
        if name == "co_posonlyargcount" {
            return PyInt(t="int", val=self.posonlyargcount);
        }
        if name == "co_kwonlyargcount" {
            return PyInt(t="int", val=self.kwonlyargcount);
        }
        if name == "co_stacksize" {
            return PyInt(t="int", val=self.stacksize);
        }
        if name == "co_flags" {
            return PyInt(t="int", val=self.flags);
        }
        if name == "co_name" {
            return PyStr(t="str", val=self.name);
        }
        if name == "co_qualname" {
            return PyStr(t="str", val=self.qualname);
        }
        if name == "co_filename" {
            return PyStr(t="str", val=self.filename);
        }
        if name == "co_firstlineno" {
            return PyInt(t="int", val=self.firstlineno);
        }
        if name == "co_names" or name == "co_varnames" or name == "co_cellvars"
            or name == "co_freevars" {
            items: list[PyObj] = [];
            src_names: list[str] = [];
            if name == "co_names" {
                src_names = self.names;
            } elif name == "co_varnames" {
                src_names = self.varnames;
            } elif name == "co_cellvars" {
                src_names = self.cellvars;
            } else {
                src_names = self.freevars;
            }
            for n in src_names {
                items.append(PyStr(t="str", val=n));
            }
            return PyTuple(t="tuple", items=items);
        }
        if name == "co_consts" {
            return PyTuple(t="tuple", items=self.consts);
        }
        if name == "co_code" {
            return PyBytes(t="bytes", val=self.co_code);
        }
        return py_error("AttributeError", "'code' object has no attribute '" + name + "'");
    }
}

obj PyCell(PyObj) {
    has val: PyObj;
}

# Backing slot for the hash-key protocol: the original key object is kept next
# to its value so keys()/iteration/repr/KeyError return real keys, never the
# internal hashkey string. A plain obj (not a PyObj) -- pure storage.
obj DictEntry {
    has key: PyObj,
        value: PyObj;
}

# Native, size-guarded dict iterator (mode = keys|values|items). Holds the dict
# it came from plus the version stamp at creation; the eval loop (FOR_ITER) and
# next() consult `snap_version` against `d.version` and raise RuntimeError on a
# structural change mid-iteration. `keys` is the hashkey list snapshotted at
# creation so iteration order is stable even as the backing map churns.
obj PyDictIter(PyObj) {
    has d: PyDict,
        keys: list[str],
        index: int,
        snap_version: int,
        mode: str;

    # True when the dict mutated since this iterator was created.
    def dictiter_stale -> bool {
        return self.d.version != self.snap_version;
    }
}

obj PyDict(PyObj) {
    # Keyed on tp_hashkey() (value-equality with numeric collapse), not on the
    # raw string. Jac dict insertion order is preserved, matching CPython.
    has items: dict[str, DictEntry],
        # Bumped on every structural mutation (set/overwrite/delete). A dict
        # iterator snapshots it and raises RuntimeError when it changes mid-loop
        # -- catching both size change AND net-zero delete+reinsert, matching
        # CPython's "dictionary changed size during iteration".
        version: int = 0;

    def tp_iter -> PyObj {
        return self.dict_iter("keys");
    }

    # A native, size-guarded iterator over this dict. mode = keys|values|items.
    def dict_iter(mode: str) -> PyDictIter {
        keys: list[str] = [];
        for hk in self.items {
            keys.append(hk);
        }
        return PyDictIter(
            t="dictiter",
            d=self,
            keys=keys,
            index=0,
            snap_version=self.version,
            mode=mode
        );
    }

    def mp_subscript(index: PyObj) -> PyObj {
        hk = index.tp_hashkey();
        if hk == "" {
            return py_error("TypeError", "unhashable type");
        }
        if hk in self.items {
            return self.items[hk].value;
        }
        return py_error("KeyError", dict_key_repr(index));
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hk = index.tp_hashkey();
        if hk == "" {
            return py_error("TypeError", "unhashable type");
        }
        if hk in self.items {
            # Overwrite value, keep the FIRST key object + slot position (CPython
            # semantics). Rebuild the entry rather than writing a nested obj field
            # in place (na external-field-write header hazard on the leaf). A plain
            # value overwrite leaves the key set unchanged, so it does NOT bump
            # version -- `for k in d: d[k] = ...` is legal in CPython (size guard).
            self.items[hk] = DictEntry(key=self.items[hk].key, value=value);
        } else {
            self.items[hk] = DictEntry(key=index, value=value);
            self.version = self.version + 1;
        }
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        hk = index.tp_hashkey();
        if hk == "" {
            return py_error("TypeError", "unhashable type");
        }
        if hk in self.items {
            _py_container_del(self.items, hk);
            self.version = self.version + 1;
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }

    # Public helpers so bootstrap/ceval code never touches the raw entry map.
    def dict_set(keyobj: PyObj, value: PyObj) -> PyObj {
        return self.mp_ass_subscript(keyobj, value);
    }

    def dict_contains(keyobj: PyObj) -> bool {
        hk = keyobj.tp_hashkey();
        if hk == "" {
            return False;
        }
        return hk in self.items;
    }

    def dict_keys -> list[PyObj] {
        out: list[PyObj] = [];
        for hk in self.items {
            out.append(self.items[hk].key);
        }
        return out;
    }

    def dict_values -> list[PyObj] {
        out: list[PyObj] = [];
        for hk in self.items {
            out.append(self.items[hk].value);
        }
        return out;
    }

    # Values re-keyed by their string key (only entries whose key is a PyStr).
    # For the inherently str-keyed consumers: kwdefaults, %(name) mapping format.
    def dict_str_map -> dict[str, PyObj] {
        out: dict[str, PyObj] = {};
        for hk in self.items {
            `entry = self.items[hk];
            if `entry.key.t == "str" {
                out[expect_str(`entry.key)] = `entry.value;
            }
        }
        return out;
    }

    # NOTE: dict host-method attr access (get/keys/values/items) is deliberately
    # NOT here -- it required a host_getattr call, which would make this na-clean
    # leaf depend on the host bridge (an import cycle) for a bootstrap-only,
    # untested convenience. If needed it belongs in the ceval/bootstrap layer.
    def tp_getattro(name: str) -> PyObj {
        hk = "s:" + name;
        if hk in self.items {
            return self.items[hk].value;
        }
        return py_error("AttributeError", name);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

# Native set / frozenset -- one type, `frozen` selects mutability + hashability.
# Backed by the hash-key protocol (hashkey -> member obj), so membership and set
# algebra are value-based with the same numeric collapse as PyDict.
obj PySet(PyObj) {
    has items: dict[str, PyObj],
        frozen: bool = False;

    def set_contains(member: PyObj) -> bool {
        found = _set_contains_elem(self, member);
        if is_error(found) {
            return False;
        }
        if isinstance(found, PyBool) {
            return (found as PyBool).val;
        }
        return True;
    }

    # Membership with element ``==`` (propagates comparison errors).
    def set_lookup(member: PyObj) -> PyObj {
        return _set_contains_elem(self, member);
    }

    def set_add(member: PyObj) -> PyObj {
        hk = member.tp_hashkey();
        if hk == "" {
            return py_error("TypeError", "unhashable type");
        }
        # First occurrence wins: {1, 1.0, True} keeps the int 1 it saw first
        # (CPython set-literal insertion order). Overwriting would keep the last.
        if not (hk in self.items) {
            self.items[hk] = member;
        }
        return py_none();
    }

    # Remove and return an arbitrary member (the first in iteration order, which
    # is deterministic here). Empty set -> KeyError, matching CPython's set.pop().
    def set_pop -> PyObj {
        for hk in self.items {
            member = self.items[hk];
            _py_container_del(self.items, hk);
            return member;
        }
        return py_error("KeyError", "pop from an empty set");
    }

    def set_discard(member: PyObj) -> PyObj {
        hk = member.tp_hashkey();
        if hk == "" {
            return py_error("TypeError", "unhashable type");
        }
        if hk in self.items {
            _py_container_del(self.items, hk);
        }
        return py_none();
    }

    def set_clear -> PyObj {
        self.items = {};
        return py_none();
    }

    def set_copy -> PyObj {
        copy_items: dict[str, PyObj] = {};
        for hk in self.items {
            copy_items[hk] = self.items[hk];
        }
        return PySet(t=self.t, items=copy_items, frozen=self.frozen);
    }

    def set_members -> list[PyObj] {
        out: list[PyObj] = [];
        for hk in self.items {
            out.append(self.items[hk]);
        }
        return out;
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.set_members(), index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }

    # Only frozensets are hashable (mutable set -> "" unhashable). The digest is
    # order-independent: member subkeys are sorted (manual insertion sort, na-
    # clean) so frozenset({1,2}) and frozenset({2,1}) share one key.
    def tp_hashkey -> str {
        if not self.frozen {
            return "";
        }
        keys: list[str] = [];
        for hk in self.items {
            keys.append(hk);
        }
        i = 1;
        while i < len(keys) {
            cur = keys[i];
            j = i - 1;
            while j >= 0 and keys[j] > cur {
                keys[j + 1] = keys[j];
                j = j - 1;
            }
            keys[j + 1] = cur;
            i = i + 1;
        }
        result = "fs:" + str(len(keys));
        for k in keys {
            result = result + ":" + str(len(k)) + ":" + k;
        }
        return result;
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if not isinstance(other, PySet) {
            return py_error("TypeError", "unsupported operand types");
        }
        o = other as PySet;
        result_items: dict[str, PyObj] = {};
        if kind == 7 {
            # union
            for hk in self.items {
                result_items[hk] = self.items[hk];
            }
            for hk in o.items {
                result_items[hk] = o.items[hk];
            }
        } elif kind == 1 {
            # intersection
            for hk in self.items {
                if hk in o.items {
                    result_items[hk] = self.items[hk];
                }
            }
        } elif kind == 10 {
            # difference
            for hk in self.items {
                if not (hk in o.items) {
                    result_items[hk] = self.items[hk];
                }
            }
        } elif kind == 12 {
            # symmetric difference
            for hk in self.items {
                if not (hk in o.items) {
                    result_items[hk] = self.items[hk];
                }
            }
            for hk in o.items {
                if not (hk in self.items) {
                    result_items[hk] = o.items[hk];
                }
            }
        } else {
            return py_error("TypeError", "unsupported operand types");
        }
        # Result type follows the left operand (frozenset|set -> frozenset).
        return PySet(t=self.t, items=result_items, frozen=self.frozen);
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if not isinstance(other, PySet) {
            if kind == 2 {
                return PyBool(t="bool", val=False);
            }
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PY_NOT_IMPLEMENTED;
        }
        return _pyset_richcompare_na(kind, self, other as PySet);
    }
}

# Shared set/set richcompare (na-clean). ``setobject.set_richcompare`` and ceval
# ``py_compare`` both route here; keeps one implementation for subset algebra.
# Truth of a comparison/protocol result: errors are silently false, none and
# zero are false, everything else is true.
def _object_is_true(res: PyObj) -> bool {
    if is_error(res) {
        return False;
    }
    if isinstance(res, PyBool) {
        return (res as PyBool).val;
    }
    if res.t == "none" {
        return False;
    }
    if res.t == "int" {
        return (res as PyInt).val != 0;
    }
    return True;
}

# Tri-state truth of a comparison result: 1 true, 0 false, -1 error
# (matches the C API convention; shared by dict/list/set membership and
# PyObject_RichCompareBool).
def _richcompare_to_bool(res: PyObj) -> int {
    if is_error(res) {
        return -1;
    }
    if _object_is_true(res) {
        return 1;
    }
    return 0;
}

# Three-way integer compare (-1 / 0 / +1). Only for NaN-free values:
# float richcompare keeps its direct-operator ladder because every IEEE
# comparison against NaN is false, which a three-way fold would misreport.
def _cmp3(a: int, b: int) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

# Three-way lexicographic string compare (-1 / 0 / +1).
def _cmp3_str(a: str, b: str) -> int {
    if a < b {
        return -1;
    }
    if a > b {
        return 1;
    }
    return 0;
}

# Map a three-way cmp plus a Py_LT..Py_GE op to its PyBool result. One
# implementation replaces the op->bool ladder copy-pasted across the numeric,
# str, bytes, list, tuple, and set comparators.
def _bool_from_cmp(cmp: int, op: int) -> PyObj {
    if op == Py_LT {
        return PyBool(t="bool", val=cmp < 0);
    }
    if op == Py_LE {
        return PyBool(t="bool", val=cmp <= 0);
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=cmp == 0);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=cmp != 0);
    }
    if op == Py_GT {
        return PyBool(t="bool", val=cmp > 0);
    }
    if op == Py_GE {
        return PyBool(t="bool", val=cmp >= 0);
    }
    return PyBool(t="bool", val=False);
}

# Two's-complement wrap of an unsigned 64-bit accumulator to signed.
def _signed_hash(acc: int) -> int {
    if acc >= 0x8000000000000000 {
        return acc - 0x10000000000000000;
    }
    return acc;
}

# Tri-state ``==`` for set membership (1 true, 0 false, -1 error).
def _obj_eq_bool(a: PyObj, b: PyObj) -> int {
    if a is b {
        return 1;
    }
    res = a.tp_richcompare(2, b);
    if is_error(res) {
        return -1;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return _richcompare_to_bool(res);
    }
    res = b.tp_richcompare(2, a);
    if is_error(res) {
        return -1;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return _richcompare_to_bool(res);
    }
    return 0;
}

def _set_contains_elem(so: PySet, key: PyObj) -> PyObj {
    hk = key.tp_hashkey();
    if hk == "" {
        return PyBool(t="bool", val=False);
    }
    if hk in so.items {
        stored = so.items[hk];
        cmp = _obj_eq_bool(key, stored);
        if cmp < 0 {
            return py_error("TypeError", "comparison failed");
        }
        if cmp != 0 {
            return PyBool(t="bool", val=True);
        }
    }
    for hk2 in so.items {
        stored = so.items[hk2];
        if key is stored {
            return PyBool(t="bool", val=True);
        }
        cmp = _obj_eq_bool(key, stored);
        if cmp < 0 {
            return py_error("TypeError", "comparison failed");
        }
        if cmp != 0 {
            return PyBool(t="bool", val=True);
        }
    }
    return PyBool(t="bool", val=False);
}

def _pyset_richcompare_na(op: int, v: PySet, w: PySet) -> PyObj {
    vlen = len(v.items);
    wlen = len(w.items);
    v_sub = True;
    for hk in v.items {
        elem = v.items[hk];
        found = _set_contains_elem(w, elem);
        if is_error(found) {
            return found;
        }
        if not (found as PyBool).val {
            v_sub = False;
        }
    }
    w_sub = True;
    for hk in w.items {
        elem = w.items[hk];
        found = _set_contains_elem(v, elem);
        if is_error(found) {
            return found;
        }
        if not (found as PyBool).val {
            w_sub = False;
        }
    }
    eq = v_sub and w_sub;
    # Subset algebra folds onto the shared op->bool map: equal sets compare
    # three-way-equal, a proper subset is "less", a proper superset "greater".
    cmp = 0;
    if not eq {
        if v_sub {
            cmp = -1;
        } else {
            cmp = 1;
        }
    }
    return _bool_from_cmp(cmp, op);
}

obj PyExceptionType(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Exception(*args): keep the FULL args tuple (BaseException.args), not just
        # the first, so `e.args`, str(e), and repr(e) round-trip faithfully. The
        # single-arg `message` shortcut stays for the common one-string case.
        message = "";
        if len(args) == 1 {
            message = expect_str(args[0]);
        }
        exc_args: list[PyObj] = [];
        exc_args.extend(args);
        return PyException(
            t="exception", type_name=self.name, message=message, args=exc_args
        );
    }
}

obj PyException(PyObj) {
    has type_name: str,
        message: str,
        # BaseException.args: the full constructor argument tuple. VM-raised
        # errors (py_error) leave this empty and carry `message` instead; to_host
        # falls back to [message] when args is empty (see host_exception).
        args: list[PyObj] = [],
        raw: any = None,
        # Explicit chaining: `raise X from Y` records Y here so e.__cause__ reads
        # it back (None when raised without a `from`).
        cause: any = None,
        # StopIteration payload: `return x` in a generator surfaces as
        # StopIteration(x); .send()/next() carry the value here.
        value: any = None;

    # Attribute reads on a caught exception. `args` is served natively as a real
    # tuple; a user-exception instance (kept in `raw`) delegates to its own
    # attributes; the standard exception-chaining dunders default to None. Any
    # host-only attribute is left to the ceval's to_host bridge (host_getattr on a
    # real host exception), which this leaf can't reach.
    def tp_getattro(name: str) -> PyObj {
        if name == "args" {
            items: list[PyObj] = [];
            items.extend(self.args);
            return PyTuple(t="tuple", items=items);
        }
        if name == "value" {
            if self.value is not None {
                return self.value as PyObj;
            }
            return py_none();
        }
        if self.raw is not None {
            r = (self.raw as PyObj).tp_getattro(name);
            if not is_error(r) {
                return r;
            }
        }
        if name == "__cause__" {
            if self.cause is not None {
                return self.cause as PyObj;
            }
            return py_none();
        }
        if name == "__context__"
            or name == "__traceback__"
            or name == "__suppress_context__" {
            return py_none();
        }
        return py_error("AttributeError", name);
    }
}

obj PyError(PyObj) {
    has exception: PyException,
        lasti: int = -1;
}

# Native richcompare deferral sentinel (CPython ``NotImplemented`` for builtin slots).
obj PyNotImplementedSentinel(PyObj) {
    has _marker: bool = True;
}

glob PY_NOT_IMPLEMENTED: PyNotImplementedSentinel = PyNotImplementedSentinel(
         t="notimplemented"
     );

obj PyIter(PyObj) {
    has items: list[PyObj],
        index: int;

    # Iterators are their own iterable (CPython tp_iter returns self), so a
    # native iterator works with GET_ITER / for-in instead of raising.
    def tp_iter -> PyObj {
        return self;
    }
}

obj PyHandler(PyObj) {
    has start: int,
        end: int,
        target: int,
        depth: int,
        lasti: bool;
}

# ---------------- pure helpers (na-clean: isinstance/as, no MatchArch) ----------------
def bytes_value(o: PyObj) -> list[int] {
    if isinstance(o, PyBytes) {
        return (o as PyBytes).val;
    }
    return [];
}

def tuple_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyTuple) {
        return (o as PyTuple).items;
    }
    return [];
}

def str_value(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

def str_values(o: PyObj) -> list[str] {
    result: list[str] = [];
    for it in tuple_value(o) {
        result.append(str_value(it));
    }
    return result;
}

def int_values(o: PyObj) -> list[int] {
    result: list[int] = [];
    for it in tuple_value(o) {
        if isinstance(it, PyInt) {
            result.append((it as PyInt).val);
        }
    }
    return result;
}

def expect_int(o: PyObj) -> int {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

def expect_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    return "";
}

# CPython ``PyUnicode_Repr`` escaping for a single codepoint (non-printable).
def _repr_hex2(n: int) -> str {
    return "0123456789abcdef"[n];
}

def _repr_unicode_escape(cp: int) -> str {
    if cp < 256 {
        return ("\\x" + _repr_hex2((cp >> 4) & 15) + _repr_hex2(cp & 15));
    }
    if cp <= 0xFFFF {
        out = "\\u";
        shift = 12;
        while shift >= 0 {
            out = out + _repr_hex2((cp >> shift) & 15);
            shift = shift - 4;
        }
        return out;
    }
    out = "\\U";
    shift = 28;
    while shift >= 0 {
        out = out + _repr_hex2((cp >> shift) & 15);
        shift = shift - 4;
    }
    return out;
}

def _repr_unicode_char(ch: str, quote: int) -> str {
    if ch == "\\" {
        return "\\\\";
    }
    if quote == 39 and ch == "'" {
        return "\\'";
    }
    if quote == 34 and ch == "\"" {
        return "\\\"";
    }
    if ch == "\t" {
        return "\\t";
    }
    if ch == "\n" {
        return "\\n";
    }
    if ch == "\r" {
        return "\\r";
    }
    if ch.isprintable() {
        return ch;
    }
    return _repr_unicode_escape(ord(ch));
}

# CPython ``unicode_repr`` (smart quotes + escapes). Shared by ``str_repr`` and
# ``dict_key_repr`` so KeyError / ``%r`` match container repr paths.
def str_repr_text(val: str) -> str {
    if len(val) == 0 {
        return "''";
    }
    squotes = 0;
    dquotes = 0;
    i = 0;
    while i < len(val) {
        if val[i] == "'" {
            squotes = squotes + 1;
        } elif val[i] == "\"" {
            dquotes = dquotes + 1;
        }
        i = i + 1;
    }
    quote = 39;
    if squotes > 0 and dquotes == 0 {
        quote = 34;
    }
    out = "";
    if quote == 39 {
        out = "'";
    } else {
        out = "\"";
    }
    i = 0;
    while i < len(val) {
        out = out + _repr_unicode_char(val[i], quote);
        i = i + 1;
    }
    if quote == 39 {
        out = out + "'";
    } else {
        out = out + "\"";
    }
    return out;
}

# Best-effort repr of a missing dict key for KeyError messages: str keys are
# quoted, ints show their value, other keys fall back to their hashkey.
def dict_key_repr(index: PyObj) -> str {
    if isinstance(index, PyStr) {
        return str_repr_text((index as PyStr).val);
    }
    if isinstance(index, PyInt) {
        return str((index as PyInt).val);
    }
    return index.tp_hashkey();
}

def expect_float(o: PyObj) -> float {
    if isinstance(o, PyFloat) {
        return (o as PyFloat).val;
    }
    return 0.0;
}

def expect_bool(o: PyObj) -> bool {
    if isinstance(o, PyBool) {
        return (o as PyBool).val;
    }
    return False;
}

def list_value(o: PyObj) -> list[PyObj] {
    if isinstance(o, PyList) {
        return (o as PyList).items;
    }
    return [];
}

def concat_items(left: list[PyObj], right: list[PyObj]) -> list[PyObj] {
    result: list[PyObj] = [];
    result.extend(left);
    result.extend(right);
    return result;
}

def find_name(names: list[str], name: str) -> int {
    i = 0;
    while i < len(names) {
        if names[i] == name {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def py_none -> PyObj {
    return PyNoneType(t="none");
}

def py_error(type_name: str, message: str) -> PyObj {
    return PyError(
        t="error",
        exception=PyException(t="exception", type_name=type_name, message=message),
    );
}

def py_exception_type(name: str) -> PyObj {
    return PyExceptionType(t="exception_type", name=name);
}

def is_error(value: PyObj) -> bool {
    return value.t == "error";
}

# ---------------- slicing (CPython PySlice_AdjustIndices) ----------------
# CPython raises ValueError("slice step cannot be zero") before any stepping
# loop runs; without this guard a zero-step slice never terminates.
def _zero_step_error(sl: PySlice) -> PyObj {
    if isinstance(sl.step, PyNoneType) {
        return py_none();
    }
    step = sl.step;
    if isinstance(step, PyBool) {
        # bool is an int subclass: True steps forward.
        if (step as PyBool).val {
            return py_none();
        }
        return py_error("ValueError", "slice step cannot be zero");
    }
    if isinstance(step, PyInt) and (step as PyInt).val == 0 {
        return py_error("ValueError", "slice step cannot be zero");
    }
    return py_none();
}

def _adjust_index(i: int, length: int, neg: bool) -> int {
    if i < 0 {
        i = i + length;
        if i < 0 {
            if neg {
                i = -1;
            } else {
                i = 0;
            }
        }
    } elif i >= length {
        if neg {
            i = length - 1;
        } else {
            i = length;
        }
    }
    return i;
}

# Resolve a PySlice against a sequence of `length` into concrete
# [start, stop, step], applying CPython's negative-index and clamping rules.
def slice_indices(sl: PySlice, length: int) -> list[int] {
    step = 1;
    if not isinstance(sl.step, PyNoneType) {
        step = expect_int(sl.step);
    }
    neg = step < 0;
    start = 0;
    if isinstance(sl.start, PyNoneType) {
        if neg {
            start = length - 1;
        } else {
            start = 0;
        }
    } else {
        start = _adjust_index(expect_int(sl.start), length, neg);
    }
    stop = 0;
    if isinstance(sl.stop, PyNoneType) {
        if neg {
            stop = -1;
        } else {
            stop = length;
        }
    } else {
        stop = _adjust_index(expect_int(sl.stop), length, neg);
    }
    return [start, stop, step];
}

def _slice_objs(items: list[PyObj], sl: PySlice) -> list[PyObj] {
    b = slice_indices(sl, len(items));
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[PyObj] = [];
    if step > 0 {
        while i < stop {
            out.append(items[i]);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(items[i]);
            i = i + step;
        }
    }
    return out;
}

def _slice_ints(vals: list[int], sl: PySlice) -> list[int] {
    b = slice_indices(sl, len(vals));
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[int] = [];
    if step > 0 {
        while i < stop {
            out.append(vals[i]);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(vals[i]);
            i = i + step;
        }
    }
    return out;
}

def _slice_str(s: str, sl: PySlice) -> str {
    b = slice_indices(sl, len(s));
    i = b[0];
    stop = b[1];
    step = b[2];
    out = "";
    if step > 0 {
        while i < stop {
            out = out + s[i];
            i = i + step;
        }
    } else {
        while i > stop {
            out = out + s[i];
            i = i + step;
        }
    }
    return out;
}

# ---------------- str %-format (CPython PyUnicode_Format subset) ----------------
# na-clean: integer bases are built from digit tables (no host str()/hex()); the
# only intrinsic used is chr() for %c (primitives_native). Covers conversions
# d i u o x X c s r %; flags - + space 0 #; field width; precision; and both the
# tuple/single-value and %(key) mapping argument conventions.
def _digit_val(c: str) -> int {
    digits = "0123456789";
    j = 0;
    while j < 10 {
        if digits[j] == c {
            return j;
        }
        j = j + 1;
    }
    return -1;
}

def _is_digit(c: str) -> bool {
    return _digit_val(c) >= 0;
}

def _uint_to_str(n: int, base: int, digits: str) -> str {
    if n == 0 {
        return "0";
    }
    out = "";
    while n > 0 {
        out = digits[n % base] + out;
        n = n // base;
    }
    return out;
}

# Conversion flags packed into a bitmask: - + space 0 #.
glob F_MINUS: int = 1,
     F_PLUS: int = 2,
     F_SPACE: int = 4,
     F_ZERO: int = 8,
     F_HASH: int = 16;

def _fmt_int(
    val: int, base: int, digits: str, prefix: str, flags: int, prec: int, width: int
) -> str {
    neg = val < 0;
    mag = val;
    if neg {
        mag = -val;
    }
    body = _uint_to_str(mag, base, digits);
    if prec >= 0 {
        while len(body) < prec {
            body = "0" + body;
        }
    }
    sign = "";
    if neg {
        sign = "-";
    } elif (flags & F_PLUS) != 0 {
        sign = "+";
    } elif (flags & F_SPACE) != 0 {
        sign = " ";
    }
    pfx = "";
    if (flags & F_HASH) != 0 and mag != 0 {
        pfx = prefix;
    }
    # zero-fill goes between the sign/prefix and the digits, and only when there
    # is no explicit precision and the field is right-justified.
    if (flags & F_ZERO) != 0 and (flags & F_MINUS) == 0 and prec < 0 {
        total = len(sign) + len(pfx) + len(body);
        while total < width {
            body = "0" + body;
            total = total + 1;
        }
    }
    return sign + pfx + body;
}

def _int_of(o: PyObj) -> int {
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return 1;
        }
        return 0;
    }
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    return 0;
}

def _is_intlike(o: PyObj) -> bool {
    return isinstance(o, PyInt) or isinstance(o, PyBool);
}

def _pyobj_str(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    if isinstance(o, PyBool) {
        if (o as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(o, PyInt) {
        return _fmt_int((o as PyInt).val, 10, "0123456789", "", 0, -1, 0);
    }
    if isinstance(o, PyNoneType) {
        return "None";
    }
    return "<object>";
}

def _pyobj_repr(o: PyObj) -> str {
    if isinstance(o, PyStr) {
        return str_repr_text((o as PyStr).val);
    }
    return _pyobj_str(o);
}

def _pad_spaces(s: str, width: int, left: bool) -> str {
    while len(s) < width {
        if left {
            s = s + " ";
        } else {
            s = " " + s;
        }
    }
    return s;
}

def _trunc(s: str, prec: int) -> str {
    if prec < 0 or len(s) <= prec {
        return s;
    }
    out = "";
    i = 0;
    while i < prec {
        out = out + s[i];
        i = i + 1;
    }
    return out;
}

def str_mod_format(fmt: str, args: PyObj) -> PyObj {
    argv: list[PyObj] = [];
    mapping = False;
    if isinstance(args, PyTuple) {
        argv = (args as PyTuple).items;
    } elif isinstance(args, PyDict) {
        mapping = True;
    } else {
        argv.append(args);
    }
    ai = 0;
    out = "";
    n = len(fmt);
    i = 0;
    while i < n {
        c = fmt[i];
        if c != "%" {
            out = out + c;
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        if fmt[i] == "%" {
            out = out + "%";
            i = i + 1;
            continue;
        }
        key = "";
        haskey = False;
        if fmt[i] == "(" {
            i = i + 1;
            while i < n and fmt[i] != ")" {
                key = key + fmt[i];
                i = i + 1;
            }
            if i >= n {
                return py_error("ValueError", "incomplete format key");
            }
            i = i + 1;
            haskey = True;
        }
        flags = 0;
        while i < n {
            f = fmt[i];
            if f == "-" {
                flags = flags | F_MINUS;
                i = i + 1;
            } elif f == "+" {
                flags = flags | F_PLUS;
                i = i + 1;
            } elif f == " " {
                flags = flags | F_SPACE;
                i = i + 1;
            } elif f == "0" {
                flags = flags | F_ZERO;
                i = i + 1;
            } elif f == "#" {
                flags = flags | F_HASH;
                i = i + 1;
            } else {
                break;
            }
        }
        fminus = (flags & F_MINUS) != 0;
        width = 0;
        while i < n and _is_digit(fmt[i]) {
            width = width * 10 + _digit_val(fmt[i]);
            i = i + 1;
        }
        prec = -1;
        if i < n and fmt[i] == "." {
            i = i + 1;
            prec = 0;
            while i < n and _is_digit(fmt[i]) {
                prec = prec * 10 + _digit_val(fmt[i]);
                i = i + 1;
            }
        }
        while i < n and (fmt[i] == "l" or fmt[i] == "h" or fmt[i] == "L") {
            i = i + 1;
        }
        if i >= n {
            return py_error("ValueError", "incomplete format");
        }
        conv = fmt[i];
        i = i + 1;

        arg: PyObj = py_none();
        if haskey {
            if not mapping {
                return py_error("TypeError", "format requires a mapping");
            }
            d = (args as PyDict).dict_str_map();
            if key in d {
                arg = d[key];
            } else {
                return py_error("KeyError", key);
            }
        } else {
            if ai >= len(argv) {
                return py_error("TypeError", "not enough arguments for format string");
            }
            arg = argv[ai];
            ai = ai + 1;
        }

        piece = "";
        if conv == "d" or conv == "i" or conv == "u" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%d format: a number is required");
            }
            piece = _fmt_int(_int_of(arg), 10, "0123456789", "", flags, prec, width);
        } elif conv == "x" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%x format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789abcdef", "0x", flags, prec, width
            );
        } elif conv == "X" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%X format: an integer is required");
            }
            piece = _fmt_int(
                _int_of(arg), 16, "0123456789ABCDEF", "0X", flags, prec, width
            );
        } elif conv == "o" {
            if not _is_intlike(arg) {
                return py_error("TypeError", "%o format: an integer is required");
            }
            piece = _fmt_int(_int_of(arg), 8, "01234567", "0o", flags, prec, width);
        } elif conv == "c" {
            if _is_intlike(arg) {
                piece = chr(_int_of(arg));
            } elif isinstance(arg, PyStr) {
                piece = (arg as PyStr).val;
            } else {
                return py_error("TypeError", "%c requires int or char");
            }
        } elif conv == "s" {
            piece = _trunc(_pyobj_str(arg), prec);
        } elif conv == "r" {
            piece = _trunc(_pyobj_repr(arg), prec);
        } else {
            return py_error("ValueError", "unsupported format character");
        }
        out = out + _pad_spaces(piece, width, fminus);
    }
    if (not mapping) and ai < len(argv) {
        return py_error(
            "TypeError", "not all arguments converted during string formatting"
        );
    }
    return PyStr(t="str", val=out);
}

::py::

def _py_container_del(container, key):
    # Compiled-jac `del container[key]` on a typed dict pins the removed value:
    # the runtime's anchor system caches an ObjectAnchor in the value's __dict__
    # (a strong root gc.collect cannot reach), so deleted user objects leak.
    # Python-mode deletion has plain refcount semantics. See the weakref shim
    # and OP_DELETE_NAME for context; remove once the compiler fixes del.
    del container[key]

def _py_container_del_index(lst, i):
    del lst[i]

::py::
