# Shared values, diagnostics and code objects for the Python compiler.
#
# The frontend and backend still use this PyObj hierarchy and its constant
# helpers. It was shared with the removed Jac interpreter; retain its behavior
# until compiler values can be separated from the remaining object slots.
# Its only import is opcode_meta, which defines the NB_* operation kinds.
import from jaclang.runtime.python.opcode_meta {
    NB_ADD,
    NB_AND,
    NB_FLOOR_DIVIDE,
    NB_LSHIFT,
    NB_MULTIPLY,
    NB_OR,
    NB_POWER,
    NB_REMAINDER,
    NB_RSHIFT,
    NB_SUBTRACT,
    NB_TRUE_DIVIDE,
    NB_XOR,
}

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

    # Deletion hook for NATIVE facade objects whose deleter differs from a
    # plain attribute-map removal (e.g. xxlimited.Xxo's private-dict setattro
    # delete arm). Default: no custom deleter -- py_del_attr falls through to
    # generic handling when this reports an error.
    def tp_del_attr(name: str) -> PyObj {
        return py_error("AttributeError", name);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error("TypeError", "object is not callable");
    }

    # Canonical dict/set key (the internal hash-key protocol): a PyStr encoding
    # a VALUE into a type-prefixed, collision-safe string so the backing Jac
    # dict keys on value-equality with Python's numeric collapse (see
    # PyInt/PyFloat). Unhashable is an explicit PyError marker (the codebase's
    # is_error idiom) -- never an in-band string -- so no path can mistake it
    # for a legitimate key; callers turn it into their own TypeError.
    def tp_hashkey -> PyObj {
        return py_error("TypeError", "unhashable type");
    }

    # CPython ``tp_name``: the type label error messages quote. Native types
    # report their ``t`` tag; ceval's PyUserObj/PyDictView override with the
    # real class / view name so messages match CPython verbatim.
    def tp_type_name -> str {
        return self.t;
    }

    # __index__: the PyInt to use when this object is a sequence index / slice
    # bound. int is itself; bool coerces; a builtin-int subclass (a PyUserObj
    # boxing an int, e.g. re._constants._NamedIntConstant) unwraps to its base.
    # Everything else is not an integer index.
    def to_index -> PyObj {
        return py_error("TypeError", "object cannot be interpreted as an integer");
    }
}

# Objects/longobject.c long_true_divide (port of the canonical TestLong
# helper): correctly-rounded int/int true division via bit-shift scaling.
# Oversized operands never cross the host float boundary whole, so huge-int
# division yields guest-exact doubles or a guest OverflowError instead of an
# escaping host error.
def int_true_divide(av: int, bv: int) -> PyObj {
    DBL_MAX_EXP = 1024;
    DBL_MIN_EXP = -1021;
    DBL_MANT_DIG = 53;
    DBL_MIN_OVERFLOW = 2 ** DBL_MAX_EXP - 2 ** (DBL_MAX_EXP - DBL_MANT_DIG - 1);
    if bv == 0 {
        return py_error("ZeroDivisionError", "division by zero");
    }
    negative = (av < 0) != (bv < 0);
    a = av;
    b = bv;
    if a < 0 {
        a = -a;
    }
    if b < 0 {
        b = -b;
    }
    if a >= DBL_MIN_OVERFLOW * b {
        return py_error(
            "OverflowError", "integer division result too large for a float"
        );
    }
    d = a.bit_length() - b.bit_length();
    if (d >= 0 and a >= 2 ** d * b) or (d < 0 and a * 2 ** (-d) >= b) {
        d = d + 1;
    }
    exp = d;
    if exp < DBL_MIN_EXP {
        exp = DBL_MIN_EXP;
    }
    exp = exp - DBL_MANT_DIG;
    aa = a;
    bb = b;
    if exp < 0 {
        aa = aa << -exp;
    } else {
        bb = bb << exp;
    }
    q = aa // bb;
    r = aa % bb;
    r2 = r + r;
    if r2 > bb or (r2 == bb and q % 2 == 1) {
        q = q + 1;
    }
    result = float(q);
    scale = 2.0 ** exp;
    result = result * scale;
    if negative {
        result = -result;
    }
    return PyFloat(t="float", val=result);
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
        if kind == NB_ADD {
            return PyInt(t="int", val=a + b);
        }
        if kind == NB_MULTIPLY {
            return PyInt(t="int", val=a * b);
        }
        if kind == NB_REMAINDER {
            if b == 0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyInt(t="int", val=a % b);
        }
        if kind == NB_SUBTRACT {
            return PyInt(t="int", val=a - b);
        }
        if kind == NB_AND {
            return PyInt(t="int", val=a & b);
        }
        if kind == NB_FLOOR_DIVIDE {
            if b == 0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyInt(t="int", val=a // b);
        }
        if kind == NB_OR {
            return PyInt(t="int", val=a | b);
        }
        # NB_TRUE_DIVIDE: int / int is always float, even when it divides
        # evenly (6 / 2 == 3.0, not 3).
        if kind == NB_TRUE_DIVIDE {
            return int_true_divide(a, b);
        }
        if kind == NB_XOR {
            return PyInt(t="int", val=a ^ b);
        }
        if kind == NB_LSHIFT {
            if b < 0 {
                return py_error("ValueError", "negative shift count");
            }
            # CPython long_lshift short-circuits a zero left operand before
            # any digit allocation: 0 << huge is 0, never an overflow.
            if a == 0 {
                return PyInt(t="int", val=0);
            }
            # A shift count at or beyond 2**63 overflows the C ssize_t shift
            # bound; CPython rejects it before allocating
            # (OverflowError "too many digits in integer"), never MemoryError.
            # Without this guard the underlying bigint op escapes as a fatal
            # runtime error instead of a guest-visible Python exception.
            if b >= 9223372036854775808 {
                return py_error("OverflowError", "too many digits in integer");
            }
            return PyInt(t="int", val=a << b);
        }
        if kind == NB_RSHIFT {
            if b < 0 {
                return py_error("ValueError", "negative shift count");
            }
            return PyInt(t="int", val=a >> b);
        }
        if kind == NB_POWER {
            # int ** negative -> float (2 ** -1 == 0.5); 0 ** negative raises
            # with CPython's INT wording -- the float slot says "0.0 cannot be
            # raised...", the int slot says "zero to a negative power".
            if b < 0 {
                if a == 0 {
                    return py_error("ZeroDivisionError", "zero to a negative power");
                }
                return PyFloat(t="float", val=float(a) ** float(b));
            }
            return PyInt(t="int", val=(a ** b) as int);
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython long_richcompare keys on PyLong_Check(other): any int
        # subclass instance compares numerically. A user subclass of int
        # arrives as a boxed user object, so try the __index__ unwrap first;
        # a raising or non-int unwrap keeps the non-numeric handling below.
        if other.t != "int" and other.t != "bool" and other.t != "float" {
            idxr = other.to_index();
            if not is_error(idxr) and (idxr.t == "int" or idxr.t == "bool") {
                other = idxr;
            }
        }
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
        # Overflow (|int| beyond float range) and infinities compare exactly:
        # a finite int is strictly ordered against +-inf and lies beyond every
        # finite float, so no lossy conversion is needed (inf > 10**400 works).
        if other.t == "float" {
            of = other as PyFloat;
            if of.val == float("inf") {
                return _bool_from_cmp(-1, kind);
            }
            if of.val == float("-inf") {
                return _bool_from_cmp(1, kind);
            }
            if of.val != of.val {
                # NaN: unordered -- delegate to PyFloat's operator-encoded NaN
                # rules (no precision is lost that matters here).
                return of.tp_richcompare(kind, self);
            }
            # Exact compare against the float's value; promotion to float would
            # round self and report equality across the 2**53 boundary.
            return _bool_from_cmp(_cmp_int_vs_float(self.val, of.val), kind);
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
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="n:" + str(self.val));
    }
    # int is its own real part / numerator; imag is 0, denominator is 1.
    def tp_getattro(name: str) -> PyObj {
        return _number_getattro(name, self.val);
    }
}

obj PyStr(PyObj) {
    has val: str;

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == NB_ADD and other.t == "str" {
            return PyStr(t="str", val=self.val + (other as PyStr).val);
        }
        if kind == NB_REMAINDER {
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
        pos = _seq_index(
            index,
            len(self.val),
            "string indices must be integers or slices",
            "string index out of range",
        );
        if is_error(pos) {
            return pos;
        }
        return PyStr(t="str", val=self.val[(pos as PyInt).val]);
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
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="s:" + self.val);
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
        pos = _seq_index(
            index,
            len(self.val),
            "bytes indices must be integers or slices",
            "index out of range",
        );
        if is_error(pos) {
            return pos;
        }
        return PyInt(t="int", val=self.val[(pos as PyInt).val]);
    }

    def tp_iter -> PyObj {
        # Iterating bytes yields ints (CPython bytes_iterator), unlike str
        # which yields 1-char strings.
        items: list[PyObj] = [];
        for v in self.val {
            items.append(PyInt(t="int", val=v));
        }
        return PyIter(t="iter", items=items, index=0);
    }

    def tp_bool -> bool {
        return len(self.val) != 0;
    }

    def tp_hashkey -> PyObj {
        key = "b:";
        for v in self.val {
            key = key + str(v) + ",";
        }
        return PyStr(t="str", val=key);
    }
}

# CPython int/bool getattr surface (Objects/longobject.c long_getattr):
# real/numerator read back the value, imag is 0, denominator is 1 -- anything
# else raises AttributeError. Shared by PyInt.tp_getattro and PyBool.tp_getattro.
def _number_getattro(name: str, real: int) -> PyObj {
    if name == "real" or name == "numerator" {
        return PyInt(t="int", val=real);
    }
    if name == "imag" {
        return PyInt(t="int", val=0);
    }
    if name == "denominator" {
        return PyInt(t="int", val=1);
    }
    return py_error("AttributeError", name);
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
        if kind == NB_ADD {
            return PyFloat(t="float", val=a + b);
        }
        if kind == NB_MULTIPLY {
            return PyFloat(t="float", val=a * b);
        }
        if kind == NB_SUBTRACT {
            return PyFloat(t="float", val=a - b);
        }
        if kind == NB_TRUE_DIVIDE {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a / b);
        }
        if kind == NB_REMAINDER {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a % b);
        }
        if kind == NB_FLOOR_DIVIDE {
            if b == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            return PyFloat(t="float", val=a // b);
        }
        if kind == NB_POWER {
            # float.__pow__ never lets the host raise through: a zero base
            # with a negative exponent is ZeroDivisionError and a too-large
            # finite result is OverflowError (Objects/floatobject.c).
            if a == 0.0 and b < 0.0 {
                return py_error("ZeroDivisionError", "zero to a negative power");
            }
            try {
                return PyFloat(t="float", val=a ** b);
            } except OverflowError {
                return py_error(
                    "OverflowError", "(34, 'Numerical result out of range')"
                );
            }
        }
        return py_error("TypeError", "unsupported operand types");
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # int operand: compare exactly. A finite float is strictly ordered
        # against +-inf and lies within every huge int's reach: when the int
        # overflows float conversion it is strictly beyond this float (sign
        # decides), so no lossy coercion is needed (10**400 vs inf works).
        if other.t == "int" {
            iv = (other as PyInt).val;
            if self.val == float("inf") {
                return _bool_from_cmp(1, kind);
            }
            if self.val == float("-inf") {
                return _bool_from_cmp(-1, kind);
            }
            if self.val == self.val {
                # Exact compare (TODO item 25): negated because the helper
                # orders (int, float) and this is (float, int).
                return _bool_from_cmp(-_cmp_int_vs_float(iv, self.val), kind);
            }
            # NaN vs int: every operator but != is False.
            if kind == 3 {
                return PyBool(t="bool", val=True);
            }
            return PyBool(t="bool", val=False);
        }
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
    def tp_hashkey -> PyObj {
        v = self.val;
        if v != v {
            return PyStr(t="str", val="f:nan");
        }
        if v * 0.0 != 0.0 {
            return PyStr(t="str", val="f:" + str(v));
        }
        iv = int(v);
        if float(iv) == v {
            return PyStr(t="str", val="n:" + str(iv));
        }
        return PyStr(t="str", val="f:" + str(v));
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
    def tp_hashkey -> PyObj {
        if self.val {
            return PyStr(t="str", val="n:1");
        }
        return PyStr(t="str", val="n:0");
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
        # bool vs float is an exact numeric compare (True == 1.0, False ==
        # -0.0): answer through the int arm -- eq/ne must be a real value
        # comparison, never the identity fallback below (CPython reflects
        # into float_richcompare and the values coincide).
        if other.t == "float" {
            v = 0;
            if self.val {
                v = 1;
            }
            return PyInt(t="int", val=v).tp_richcompare(kind, other);
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
        return _number_getattro(name, v);
    }
}

obj PyNoneType(PyObj) {
    # Identity dunder: CPython's object.__class__ descriptor NEVER raises
    # AttributeError -- None.__class__ is NoneType. Unset exception chain
    # attributes read as None (e.__cause__/e.__context__/e.__traceback__,
    # StopIteration.value, OSError.errno when unset), so
    # `e.__cause__.__class__.__name__` must resolve to 'NoneType' through
    # this arm, not raise. PyExceptionType doubles as the type-identity
    # surrogate here, matching the Interpolation/Template precedent.
    def tp_getattro(name: str) -> PyObj {
        if name == "__class__" {
            return py_exception_type("NoneType");
        }
        return py_error("AttributeError", name);
    }

    def tp_bool -> bool {
        return False;
    }

    # None == None is True by VALUE, not identity: py_none() mints a fresh
    # instance per call, so two Nones are distinct objects that CPython still
    # reports equal (x is None uses the singleton; x == None compares values).
    # Without this, `None in {None}` / dict lookups / (1, None) == (1, None)
    # all fail on non-identical instances.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind == 2 or kind == 3 {
            if isinstance(other, PyNoneType) {
                return PyBool(t="bool", val=kind == 2);
            }
            return PY_NOT_IMPLEMENTED;
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_hashkey -> PyObj {
        # Byte-parity with the host oracle: CPython hash(None) is process-
        # stable (4238894112 on the pinned 3.14), and the "n:" namespace
        # passes numeric digests through verbatim (see _hashkey_digest). The
        # old bare "none" string FNV-digested to a value no host comparison
        # could ever match (item 41).
        return PyStr(t="str", val="n:4238894112");
    }
}

obj PyEllipsis(PyObj) {
    def tp_hashkey -> PyObj {
        return PyStr(t="str", val="ellipsis");
    }
}

# Complex-tower arithmetic kernels (pure doubles, na-clean): shared by
# PyComplex.nb_binop (complex-on-left) and ._reflected_binop (complex-on-right
# via the py_binop bridge). Formulas mirror Objects/complexobject.c.
def _cx_add(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    return (ar + br, ai + bi);
}

def _cx_sub(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    return (ar - br, ai - bi);
}

def _cx_mul(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    # Plain products/differences: double rounding matches CPython bit-for-bit,
    # and overflow is SILENT here ((1e300+0j)*(1e300+0j) == inf+0j).
    return (ar * br - ai * bi, ar * bi + ai * br);
}

def _cx_is_inf(v: float) -> bool {
    # +-inf detector without math imports; NaN is NOT infinite (v != v first)
    # so NaN results flow through pow silently like CPython's errno-free path.
    if v != v {
        return False;
    }
    return v * 0.0 != 0.0;
}

def _cx_div(ar: float, ai: float, br: float, bi: float) -> tuple[float, float] {
    # CPython _Py_c_quot (Smith's algorithm): scale by the larger divisor
    # component so finite/finite quotients never overflow spuriously. The
    # scaled expressions are exactly CPython's, so results are bit-identical
    # including inf/nan propagation. Caller guards divisor == 0+0j.
    abs_br = br;
    if abs_br < 0.0 {
        abs_br = -abs_br;
    }
    abs_bi = bi;
    if abs_bi < 0.0 {
        abs_bi = -abs_bi;
    }
    if abs_br >= abs_bi {
        ratio = bi / br;
        denom = br + bi * ratio;
        return ((ar + ai * ratio) / denom, (ai - ar * ratio) / denom);
    }
    ratio = br / bi;
    denom = br * ratio + bi;
    return ((ar * ratio + ai) / denom, (ai * ratio - ar) / denom);
}

def _cx_pow_int(ar: float, ai: float, exp: int) -> tuple[int, float, float] {
    # CPython _Py_c_pow integer path: repeated squaring with an errno-style
    # overflow check after EVERY product -- any infinite component (even from
    # an infinite base) is OverflowError; NaN flows silently. err codes:
    # 0 ok, 1 OverflowError, 2 ZeroDivisionError.
    e = exp;
    neg = False;
    if e < 0 {
        neg = True;
        e = -e;
    }
    br = ar;
    bi = ai;
    if neg {
        if br == 0.0 and bi == 0.0 {
            return (2, 0.0, 0.0);
        }
        (br, bi) = _cx_div(1.0, 0.0, br, bi);
    }
    rr = 1.0;
    ri = 0.0;
    while e > 0 {
        if e % 2 == 1 {
            (rr, ri) = _cx_mul(rr, ri, br, bi);
            if _cx_is_inf(rr) or _cx_is_inf(ri) {
                return (1, 0.0, 0.0);
            }
        }
        e = e // 2;
        if e == 0 {
            break;
        }
        (br, bi) = _cx_mul(br, bi, br, bi);
        if _cx_is_inf(br) or _cx_is_inf(bi) {
            return (1, 0.0, 0.0);
        }
    }
    return (0, rr, ri);
}

obj PyComplex(PyObj) {
    has real: float,
        imag: float;

    # Numeric coercion into the complex tower (CPython promotes int/bool/float
    # operands to complex with zero imaginary part). ok=False marks operands
    # the tower declines (str, containers, user instances).
    def _coerce(other: PyObj) -> tuple[bool, float, float] {
        if isinstance(other, PyComplex) {
            c = other as PyComplex;
            return (True, c.real, c.imag);
        }
        if other.t == "float" {
            return (True, (other as PyFloat).val, 0.0);
        }
        if other.t == "int" {
            return (True, float((other as PyInt).val), 0.0);
        }
        if other.t == "bool" {
            if (other as PyBool).val {
                return (True, 1.0, 0.0);
            }
            return (True, 0.0, 0.0);
        }
        return (False, 0.0, 0.0);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        (ok, br, bi) = self._coerce(other);
        if not ok {
            return py_error("TypeError", "unsupported operand types");
        }
        ar = self.real;
        ai = self.imag;
        if kind == NB_ADD {
            (r, i) = _cx_add(ar, ai, br, bi);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_SUBTRACT {
            (r, i) = _cx_sub(ar, ai, br, bi);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_MULTIPLY {
            (r, i) = _cx_mul(ar, ai, br, bi);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_TRUE_DIVIDE {
            # CPython: any zero divisor raises plain "division by zero"
            # (3.14 unified message -- no "complex division by zero").
            if br == 0.0 and bi == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            (r, i) = _cx_div(ar, ai, br, bi);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_POWER {
            # Integer-valued exponents use CPython's repeated-squaring path
            # (native, incl. its overflow/zero rules). General exponents need
            # polar-form transcendentals the na-clean leaf cannot import, so
            # they decline and py_binop's host fallback answers byte-exactly.
            if bi == 0.0 and -100.0 < br and br < 100.0 {
                iv = int(br);
                if float(iv) == br {
                    (err, r, i) = _cx_pow_int(ar, ai, iv);
                    if err == 1 {
                        return py_error("OverflowError", "complex exponentiation");
                    }
                    if err == 2 {
                        return py_error(
                            "ZeroDivisionError", "zero to a negative or complex power"
                        );
                    }
                    return PyComplex(t="complex", real=r, imag=i);
                }
            }
            return py_error("TypeError", "unsupported operand types");
        }
        # // and % raise in CPython too -- but with the GENERIC binop message
        # (no slot exists), which py_binop's host fallback renders verbatim.
        return py_error("TypeError", "unsupported operand types");
    }

    # Reflected half of the tower (2 - 1j, 6 / (3+0j), 2 ** (3+0j)): the left
    # operand arrives already known numeric (py_binop gates on int/float/bool).
    # Declines with PY_NOT_IMPLEMENTED so the caller's host fallback keeps
    # exotic messages byte-exact; ZeroDivision/Overflow propagate natively.
    def _reflected_binop(kind: int, other: PyObj) -> PyObj {
        (ok, lr, li) = self._coerce(other);
        if not ok {
            return PY_NOT_IMPLEMENTED;
        }
        ar = self.real;
        ai = self.imag;
        if kind == NB_ADD {
            (r, i) = _cx_add(lr, li, ar, ai);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_SUBTRACT {
            (r, i) = _cx_sub(lr, li, ar, ai);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_MULTIPLY {
            (r, i) = _cx_mul(lr, li, ar, ai);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_TRUE_DIVIDE {
            if ar == 0.0 and ai == 0.0 {
                return py_error("ZeroDivisionError", "division by zero");
            }
            (r, i) = _cx_div(lr, li, ar, ai);
            return PyComplex(t="complex", real=r, imag=i);
        }
        if kind == NB_POWER {
            if ai == 0.0 and -100.0 < ar and ar < 100.0 {
                iv = int(ar);
                if float(iv) == ar {
                    (err, r, i) = _cx_pow_int(lr, li, iv);
                    if err == 1 {
                        return py_error("OverflowError", "complex exponentiation");
                    }
                    if err == 2 {
                        return py_error(
                            "ZeroDivisionError", "zero to a negative or complex power"
                        );
                    }
                    return PyComplex(t="complex", real=r, imag=i);
                }
            }
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython complex_richcompare: ==/!= compare parts numerically (NaN
        # unordered, so nan-complex equals nothing, not even itself). Ordering
        # is NotImplemented; PyObject_RichCompare then raises the byte-exact
        # "'<' not supported between instances of 'complex' and ..." error.
        if kind != Py_EQ and kind != Py_NE {
            return PY_NOT_IMPLEMENTED;
        }
        (ok, br, bi) = self._coerce(other);
        if ok {
            eqv = self.real == br and self.imag == bi;
            if kind == Py_EQ {
                return PyBool(t="bool", val=eqv);
            }
            return PyBool(t="bool", val=not eqv);
        }
        # Non-numeric operand: identity-tag (in)equality (CPython default).
        if kind == Py_EQ {
            return PyBool(t="bool", val=False);
        }
        return PyBool(t="bool", val=True);
    }

    def tp_bool -> bool {
        return self.real != 0.0 or self.imag != 0.0;
    }

    # Dict/set keying must collapse with the numeric towers: 3+0j keys with
    # int 3 / float 3.0, so a zero imaginary part delegates to PyFloat's
    # n:/f: namespaces wholesale. Nonzero imag lives in "z:" keyed on both
    # parts (str round-trips exactly; -0.0 normalized onto 0.0 because they
    # compare equal). All-NaN divergence mirrors PyFloat's accepted note.
    def tp_hashkey -> PyObj {
        if self.imag == 0.0 {
            return PyFloat(t="float", val=self.real).tp_hashkey();
        }
        r = self.real;
        if r == 0.0 {
            r = 0.0;
        }
        return PyStr(t="str", val="z:" + str(r) + "," + str(self.imag));
    }

    # .real/.imag are floats even for int-built complexes (CPython getters);
    # conjugate() binds through the small wrapper below.
    def tp_getattro(name: str) -> PyObj {
        if name == "real" {
            return PyFloat(t="float", val=self.real);
        }
        if name == "imag" {
            return PyFloat(t="float", val=self.imag);
        }
        if name == "conjugate" {
            return PyComplexMethod(t="complex_method", target=self, name=name);
        }
        return py_error(
            "AttributeError", "'complex' object has no attribute '" + name + "'"
        );
    }
}

# Bound complex.conjugate(): pure arithmetic, answered in-VM.
obj PyComplexMethod(PyObj) {
    has target: PyComplex,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        if len(args) != 0 {
            return py_error(
                "TypeError",
                self.name + "() takes no arguments (" + str(len(args)) + " given)",
            );
        }
        return PyComplex(t="complex", real=self.target.real, imag=-self.target.imag);
    }
}

# A dynamic slice value (slice(1, 7, 2) built at runtime, marshaled, or handed
# back by from_host) must behave like its inline-syntax twin: attribute reads on
# the three bounds, .indices(n), and repr/type all resolve natively so the
# subscript slots' isinstance(PySlice) checks are the ONLY gate a slice index
# has to pass.
#
# Deliberate tradeoff: s.indices is a PySliceIndices wrapper object, not a
# CPython-style bound method -- type(s.indices)/repr(s.indices) differ from
# host. If a synthesis-at-exit-points sweep lands (cf. TODO item 21), add
# PySlice.tp_getattro's __class__ there.
obj PySliceIndices(PyObj) {
    has sl: PySlice;

    # slice.indices(len) -> (start, stop, step) resolved against that length.
    # Errors carry the full method-descriptor qualname (CPython prefixes with
    # the owner type name; TODO item 22).
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "slice.indices() takes no keyword arguments");
        }
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "slice.indices() takes exactly one argument ("
                    + str(len(args))
                    + " given)",
            );
        }
        err = _zero_step_error(self.sl);
        if is_error(err) {
            return err;
        }
        length_obj = args[0].to_index();
        if is_error(length_obj) {
            # CPython names the actual offending type in this message.
            return py_error(
                "TypeError",
                "'" + args[0].t + "' object cannot be interpreted as an integer",
            );
        }
        b = slice_indices(self.sl, (length_obj as PyInt).val);
        out: list[PyObj] = [];
        for v in b {
            out.append(PyInt(t="int", val=v));
        }
        return PyTuple(t="tuple", items=out);
    }
}

obj PySlice(PyObj) {
    has start: PyObj,
        stop: PyObj,
        step: PyObj;

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "start" {
            return self.start;
        }
        if name2 == "stop" {
            return self.stop;
        }
        if name2 == "step" {
            return self.step;
        }
        if name2 == "indices" {
            return PySliceIndices(t="slice_indices", sl=self);
        }
        return py_error(
            "AttributeError", "'slice' object has no attribute '" + name2 + "'"
        );
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        # CPython slice_richcompare: eq/ne compare start, stop, step pairwise
        # (PyObject_RichCompareBool -- identity shortcut and reflected slot
        # included); the first unequal field decides. Ordering is NotImplemented,
        # and a non-slice operand defers to the caller's identity fallback.
        if kind != Py_EQ and kind != Py_NE {
            return PY_NOT_IMPLEMENTED;
        }
        if not isinstance(other, PySlice) {
            return PY_NOT_IMPLEMENTED;
        }
        os = other as PySlice;
        fields: list[PyObj] = [self.start, self.stop, self.step];
        other_fields: list[PyObj] = [os.start, os.stop, os.step];
        for i in range(len(fields)) {
            eq = PyObject_RichCompare(fields[i], other_fields[i], Py_EQ);
            if is_error(eq) {
                return eq;
            }
            if _richcompare_truth(eq) != 1 {
                return PyBool(t="bool", val=kind == Py_NE);
            }
        }
        return PyBool(t="bool", val=kind == Py_EQ);
    }
}

obj PyTuple(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == NB_ADD and other.t == "tuple" {
            return PyTuple(
                t="tuple", items=concat_items(self.items, (other as PyTuple).items)
            );
        }
        if kind == NB_MULTIPLY {
            # tuple * n -- same reference-duplicating repeat as list
            # (CPython tuple_repeat); elements are shared, not copied.
            idx = other.to_index();
            if is_error(idx) {
                return py_error(
                    "TypeError",
                    "can't multiply sequence by non-int of type '" + other.t + "'",
                );
            }
            n = (idx as PyInt).val;
            repeated: list[PyObj] = [];
            while n > 0 {
                repeated.extend(self.items);
                n = n - 1;
            }
            return PyTuple(t="tuple", items=repeated);
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
        pos = _seq_index(
            index,
            len(self.items),
            "tuple indices must be integers or slices",
            "tuple index out of range",
        );
        if is_error(pos) {
            return pos;
        }
        return self.items[(pos as PyInt).val];
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
    # Recursive, length-framed so ("a","b") and ("a","b","") stay distinct.
    # An unhashable element makes the whole tuple unhashable (error propagates).
    def tp_hashkey -> PyObj {
        key = "t:";
        for item in self.items {
            sub = item.tp_hashkey();
            if is_error(sub) {
                return sub;
            }
            subk = hashkey_str(sub);
            key = key + str(len(subk)) + ":" + subk;
        }
        return PyStr(t="str", val=key);
    }

    # CPython ``tuple_richcompare`` as the real tp_richcompare slot:
    # lexicographic element-wise compare through the full protocol (so nested
    # tuples/lists/dicts/user objects compare by value). Ordering falls back to
    # comparing the first differing pair under the original op.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if not isinstance(other, PyTuple) {
            return PY_NOT_IMPLEMENTED;
        }
        w = other as PyTuple;
        vlen = len(self.items);
        wlen = len(w.items);
        i = 0;
        while i < vlen and i < wlen {
            k = PyObject_RichCompareBool(self.items[i], w.items[i], Py_EQ);
            if k < 0 {
                return PyObject_RichCompare(self.items[i], w.items[i], Py_EQ);
            }
            if k == 0 {
                break;
            }
            i = i + 1;
        }
        if i >= vlen or i >= wlen {
            return _bool_from_cmp(_cmp3(vlen, wlen), kind);
        }
        if kind == Py_EQ {
            return PyBool(t="bool", val=False);
        }
        if kind == Py_NE {
            return PyBool(t="bool", val=True);
        }
        return PyObject_RichCompare(self.items[i], w.items[i], kind);
    }
}

# timemodule.c struct_time: CPython's PyStructSequence registers the plain
# tuple slots, so sequence behavior (subscript/iterate/hash/compare) is
# inherited unchanged from PyTuple and only the named-accessor and repr
# surfaces are added here. The 11-slot form carries tm_gmtoff/tm_zone after
# the nine core fields (_STRUCT_TM_ITEMS == 11).
obj PyStructTime(PyTuple) {
    def tp_getattro(name: str) -> PyObj {
        fields: list[str] = [
            "tm_year",
            "tm_mon",
            "tm_mday",
            "tm_hour",
            "tm_min",
            "tm_sec",
            "tm_wday",
            "tm_yday",
            "tm_isdst",

        ];
        i = 0;
        while i < len(fields) {
            if name == fields[i] {
                return self.items[i];
            }
            i = i + 1;
        }
        if name == "tm_gmtoff" or name == "tm_zone" {
            idx = 9;
            if name == "tm_zone" {
                idx = 10;
            }
            if len(self.items) > idx {
                return self.items[idx];
            }
            # The 9-slot form has no zone info; CPython omits the field.
            return py_error(
                "AttributeError",
                "'time.struct_time' object has no attribute '" + name + "'",
            );
        }
        if name == "n_sequence_fields" {
            return PyInt(t="int", val=9);
        }
        if name == "n_fields" {
            return PyInt(t="int", val=len(self.items));
        }
        if name == "n_unnamed_fields" {
            return PyInt(t="int", val=0);
        }
        return py_error(
            "AttributeError",
            "'time.struct_time' object has no attribute '" + name + "'",
        );
    }

    def tp_repr -> PyObj {
        names: list[str] = [
            "tm_year",
            "tm_mon",
            "tm_mday",
            "tm_hour",
            "tm_min",
            "tm_sec",
            "tm_wday",
            "tm_yday",
            "tm_isdst",
            "tm_gmtoff",
            "tm_zone",

        ];
        out = "time.struct_time(";
        i2 = 0;
        while i2 < len(self.items) and i2 < len(names) {
            if i2 > 0 {
                out = out + ", ";
            }
            out = out + names[i2] + "=" + _struct_time_field_repr(self.items[i2]);
            i2 = i2 + 1;
        }
        return PyStr(t="str", val=out + ")");
    }
}

# Field repr for struct_time's tm_* surface: ints/bools render bare, strings
# single-quoted (CPython repr), None for an absent zone.
def _struct_time_field_repr(v: PyObj) -> str {
    if isinstance(v, PyStr) {
        return "'" + (v as PyStr).val + "'";
    }
    if isinstance(v, PyBool) {
        if (v as PyBool).val {
            return "True";
        }
        return "False";
    }
    if isinstance(v, PyNoneType) {
        return "None";
    }
    if isinstance(v, PyFloat) {
        return str((v as PyFloat).val);
    }
    if isinstance(v, PyInt) {
        return str((v as PyInt).val);
    }
    return "<unrepresentable>";
}

obj PyList(PyObj) {
    has items: list[PyObj];

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind == NB_ADD and other.t == "list" {
            return PyList(
                t="list", items=concat_items(self.items, (other as PyList).items)
            );
        }
        if kind == NB_MULTIPLY {
            # list * n -- CPython list_repeat duplicates element REFERENCES,
            # never the elements themselves ([[0]]*3 aliases one inner list).
            # n < 0 behaves as 0; bool indexes as int (True -> 1).
            idx = other.to_index();
            if is_error(idx) {
                return py_error(
                    "TypeError",
                    "can't multiply sequence by non-int of type '" + other.t + "'",
                );
            }
            n = (idx as PyInt).val;
            repeated: list[PyObj] = [];
            while n > 0 {
                repeated.extend(self.items);
                n = n - 1;
            }
            return PyList(t="list", items=repeated);
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
        pos = _seq_index(
            index,
            len(self.items),
            "list indices must be integers or slices",
            "list index out of range",
        );
        if is_error(pos) {
            return pos;
        }
        return self.items[(pos as PyInt).val];
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if isinstance(index, PySlice) {
            # lst[a:b:c] = seq -- CPython list_ass_subscript: step 1 resizes
            # freely; an extended step requires an equal-length sequence and
            # fills the stepped positions in stepping order. The dispatcher
            # (py_store_subscript) drains any iterable value into a PyList
            # first, mirroring CPython's PySequence_Fast entry conversion.
            err = _zero_step_error(index as PySlice);
            if is_error(err) {
                return err;
            }
            if not isinstance(value, PyList) {
                return py_error("TypeError", "can only assign an iterable");
            }
            vals = (value as PyList).items;
            b = slice_indices(index as PySlice, len(self.items));
            si = b[0];
            stop = b[1];
            step = b[2];
            if step == 1 {
                kept: list[PyObj] = [];
                k = 0;
                while k < si {
                    kept.append(self.items[k]);
                    k = k + 1;
                }
                kept.extend(vals);
                k = stop;
                while k < len(self.items) {
                    kept.append(self.items[k]);
                    k = k + 1;
                }
                self.items = kept;
                return py_none();
            }
            count = 0;
            probe = si;
            if step > 0 {
                while probe < stop {
                    count = count + 1;
                    probe = probe + step;
                }
            } else {
                while probe > stop {
                    count = count + 1;
                    probe = probe + step;
                }
            }
            if len(vals) != count {
                return py_error(
                    "ValueError",
                    "attempt to assign sequence of size "
                        + str(len(vals))
                        + " to extended slice of size "
                        + str(count),
                );
            }
            new_items: list[PyObj] = [];
            new_items.extend(self.items);
            pos = si;
            vi = 0;
            if step > 0 {
                while pos < stop {
                    new_items[pos] = vals[vi];
                    pos = pos + step;
                    vi = vi + 1;
                }
            } else {
                while pos > stop {
                    new_items[pos] = vals[vi];
                    pos = pos + step;
                    vi = vi + 1;
                }
            }
            self.items = new_items;
            return py_none();
        }
        npos = _seq_index(
            index,
            len(self.items),
            "list indices must be integers",
            "list assignment index out of range",
        );
        if is_error(npos) {
            return npos;
        }
        self.items[(npos as PyInt).val] = value;
        return py_none();
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
        pos = _seq_index(
            index,
            len(self.items),
            "list indices must be integers",
            "list assignment index out of range",
        );
        if is_error(pos) {
            return pos;
        }
        del self.items[(pos as PyInt).val];
        return py_none();
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.items, index=0);
    }

    # CPython ``list_richcompare_impl`` as the real tp_richcompare slot:
    # EQ/NE length shortcut, element-wise value compare through the full
    # protocol, ordering via the first differing pair.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if not isinstance(other, PyList) {
            return PY_NOT_IMPLEMENTED;
        }
        w = other as PyList;
        if len(self.items) != len(w.items) and (kind == Py_EQ or kind == Py_NE) {
            return PyBool(t="bool", val=kind == Py_NE);
        }
        i = 0;
        while i < len(self.items) and i < len(w.items) {
            vitem = self.items[i];
            witem = w.items[i];
            if vitem is witem {
                i = i + 1;
                continue;
            }
            keq = PyObject_RichCompare(vitem, witem, Py_EQ);
            if is_error(keq) {
                return keq;
            }
            if _richcompare_truth(keq) != 1 {
                break;
            }
            i = i + 1;
        }
        vlen = len(self.items);
        wlen = len(w.items);
        if i >= vlen or i >= wlen {
            return _bool_from_cmp(_cmp3(vlen, wlen), kind);
        }
        if kind == Py_EQ {
            return PyBool(t="bool", val=False);
        }
        if kind == Py_NE {
            return PyBool(t="bool", val=True);
        }
        return PyObject_RichCompare(self.items[i], w.items[i], kind);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }
}

# Host-backed proxy archetype: declared here so acyclic spokes (ceval_defs,
# ceval_bridge_guest, ...) can isinstance/import it; ceval.jac overrides the
# slots via cross-module inheritance (header comment above).
obj PyHostProxy(PyObj) {
    has val: any;
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
#   Argument cells live only in varnames; resolve_cell() in ceval.jac maps a
#   merged LOAD_FAST/_DEREF index to the correct PyCell.
#
# Exception table (co.exceptiontable):
#   Varint-encoded entries: start*2, length*2, target*2, depth<<1|lasti per
#   read_varint()/find_handler() in ceval_exceptions.jac.
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
    def tp_hashkey -> PyObj {
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
        return PyStr(t="str", val=result);
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
        if name == "co_names"
            or name == "co_varnames"
            or name == "co_cellvars"
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
        return py_error(
            "AttributeError", "'code' object has no attribute '" + name + "'"
        );
    }
}

obj PyCell(PyObj) {
    has val: PyObj,
        # CPython cells distinguish NULL (unbound) from a None binding; this VM
        # stores None in `val`, so emptiness is carried here. Lives on the cell
        # (shared across frames) exactly like the C NULL -- a per-frame bound
        # flag cannot work: an enclosing function's STORE_DEREF must make the
        # same cell readable inside a class body it was captured into.
        filled: bool = False;
}

# PEP 695 `type X = v` runtime stand-in (CPython types.TypeAliasType), built by
# CALL_INTRINSIC_1(INTRINSIC_TYPEALIAS). Data-only in this na-clean leaf: the
# lazy __value__ evaluation re-enters the interpreter, so it lives in ceval's
# typealias_value, reached through py_attr's __value__ intercept.
obj PyTypeAlias(PyObj) {
    has name: str,
        # The (possibly empty) type-parameter tuple from the alias statement;
        # codegen passes a real tuple for `type X[T, ...]` and None otherwise.
        type_params: PyObj,
        # The hidden lazy value function (sole param `.format`, guard raises
        # NotImplementedError above format 2 -- emitted by codegen itself).
        value_fn: PyObj,
        computed: bool = False,
        cached_value: PyObj = py_none();

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__type_params__" {
            if self.type_params.t == "none" {
                return PyTuple(t="tuple", items=[]);
            }
            return self.type_params;
        }
        return py_error("AttributeError", name);
    }
}

# PEP 695 type-parameter stand-in (CPython typing.TypeVar as produced by
# CALL_INTRINSIC_1(INTRINSIC_TYPEVAR) and CALL_INTRINSIC_2
# TYPEVAR_WITH_BOUND/_WITH_CONSTRAINTS/_DEFAULT). Data-only: bounds,
# constraints, and defaults are LAZY evaluator functions (PEP 749
# const-evaluators emitted by codegen) whose first access re-enters the
# interpreter, so their resolution lives in ceval's py_attr intercepts
# (typevar_bound_value and siblings), exactly like PyTypeAlias.__value__.
# CPython's typevarobject caches each evaluated value on the TypeVar after
# first access -- the cached_* slots + *_resolved flags model that.
# Implicit PEP 695 parameters live in module 'typing' with inferred variance,
# and their host repr is the bare name ('T'; the '~T' form belongs to
# explicitly-constructed TypeVars outside typing).
obj PyTypeVar(PyObj) {
    has name: str,
        # Lazy evaluators installed by the CALL_INTRINSIC_2 arms;
        # py_none() when the parameter has none.
        evaluate_bound: PyObj = py_none(),
        evaluate_constraints: PyObj = py_none(),
        evaluate_default: PyObj = py_none(),
        # First-access caches.
        cached_bound: PyObj = py_none(),
        cached_constraints: PyObj = py_none(),
        cached_default: PyObj = py_none(),
        bound_resolved: bool = False,
        constraints_resolved: bool = False,
        default_resolved: bool = False,
        # Variance flags (typevarobject.c): implicit PEP 695 parameters are
        # infer-variance; explicit _typing.TypeVar(...) construction flips
        # these through jacpython/typing.jac.
        infer_variance: bool = True,
        covariant: bool = False,
        contravariant: bool = False;

    def tp_getattro(name: str) -> PyObj {
        if name == "__name__" {
            return PyStr(t="str", val=self.name);
        }
        if name == "__module__" {
            return PyStr(t="str", val="typing");
        }
        if name == "__infer_variance__" {
            return PyBool(t="bool", val=self.infer_variance);
        }
        if name == "__covariant__" {
            return PyBool(t="bool", val=self.covariant);
        }
        if name == "__contravariant__" {
            return PyBool(t="bool", val=self.contravariant);
        }
        # Getset surface (CPython typevarobject.c evaluate_bound/
        # evaluate_constraints/evaluate_default): expose the hidden zero-arg
        # evaluator functions themselves; calling one forces evaluation
        # through the py_attr seam's caches. None when the slot is absent.
        if name == "evaluate_bound" {
            return self.evaluate_bound;
        }
        if name == "evaluate_constraints" {
            return self.evaluate_constraints;
        }
        if name == "evaluate_default" {
            return self.evaluate_default;
        }
        # has_default() is a zero-arg probe needing a callable wrapper built
        # on the ceval side of the substrate boundary -- served by py_attr.
        return py_error(
            "AttributeError", "'typing.TypeVar' object has no attribute '" + name + "'"
        );
    }
}

# Internal dict/set slot suffix when unequal keys share one hashkey digest.
glob _DICT_SLOT_COLL: str = "\x00";

# Backing slot for the hash-key protocol: the original key object is kept next
# to its value so keys()/iteration/repr/KeyError return real keys, never the
# internal hashkey string. A plain obj (not a PyObj) -- pure storage.
obj DictEntry {
    has key: PyObj,
        value: PyObj;
}

# Rebuild insertion-order index when callers seeded ``items`` without ``order``.
def _dict_ensure_order(d: PyDict) -> PyObj {
    if len(d.order) > 0 {
        return py_none();
    }
    for sk in d.items {
        d.order.append(sk);
    }
    return py_none();
}

def _set_ensure_order(s: PySet) -> PyObj {
    if len(s.order) > 0 {
        return py_none();
    }
    for sk in s.items {
        s.order.append(sk);
    }
    return py_none();
}

# Allocate a fresh internal slot key for a new dict entry (hashkey may collide).
def _dict_new_slot(d: PyDict, hk: str) -> str {
    if not (hk in d.items) {
        return hk;
    }
    n = 0;
    while True {
        sk = hk + _DICT_SLOT_COLL + str(n);
        if not (sk in d.items) {
            return sk;
        }
        n = n + 1;
    }
}

def _set_new_slot(s: PySet, hk: str) -> str {
    if not (hk in s.items) {
        return hk;
    }
    n = 0;
    while True {
        sk = hk + _DICT_SLOT_COLL + str(n);
        if not (sk in s.items) {
            return sk;
        }
        n = n + 1;
    }
}

def _dict_remove_slot(d: PyDict, sk: str) -> PyObj {
    del d.items[sk];
    kept: list[str] = [];
    for x in d.order {
        if x != sk {
            kept.append(x);
        }
    }
    # Preserve list identity: set-algebra helpers pass order by reference.
    d.order.clear();
    d.order.extend(kept);
    return py_none();
}

def _set_remove_slot(s: PySet, sk: str) -> PyObj {
    del s.items[sk];
    kept: list[str] = [];
    for x in s.order {
        if x != sk {
            kept.append(x);
        }
    }
    # Preserve list identity for callers holding the construction order list.
    s.order.clear();
    s.order.extend(kept);
    return py_none();
}

# Locate the internal slot for ``key`` via hashkey prefilter + rich compare.
# Returns PyStr(slot), py_none() when absent, or a propagated comparison error.
def _dict_find_entry(d: PyDict, key: PyObj) -> PyObj {
    _dict_ensure_order(d);
    hkr = key.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    hk = hashkey_str(hkr);
    for sk in d.order {
        ent = d.items[sk];
        stored = ent.key;
        if key is stored {
            return PyStr(t="str", val=sk);
        }
        skr = stored.tp_hashkey();
        if is_error(skr) {
            continue;
        }
        if hashkey_str(skr) != hk {
            continue;
        }
        eq = PyObject_RichCompare(key, stored, Py_EQ);
        if is_error(eq) {
            return eq;
        }
        if _richcompare_truth(eq) == 1 {
            return PyStr(t="str", val=sk);
        }
    }
    return py_none();
}

# Append ``member`` to a set under construction (value-deduped).
def _set_push_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj {
    probe = PySet(t="set", items=items, order=order, frozen=False);
    if probe.set_contains(member) {
        return py_none();
    }
    hkr = member.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    sk = _set_new_slot(probe, hashkey_str(hkr));
    items[sk] = member;
    order.append(sk);
    return py_none();
}

# Same contract as ``_dict_find_entry`` for set members.
def _set_find_entry(s: PySet, member: PyObj) -> PyObj {
    _set_ensure_order(s);
    hkr = member.tp_hashkey();
    if is_error(hkr) {
        return hkr;
    }
    hk = hashkey_str(hkr);
    for sk in s.order {
        stored = s.items[sk];
        if member is stored {
            return PyStr(t="str", val=sk);
        }
        skr = stored.tp_hashkey();
        if is_error(skr) {
            continue;
        }
        if hashkey_str(skr) != hk {
            continue;
        }
        eq = PyObject_RichCompare(member, stored, Py_EQ);
        if is_error(eq) {
            return eq;
        }
        if _richcompare_truth(eq) == 1 {
            return PyStr(t="str", val=sk);
        }
    }
    return py_none();
}

def _set_remove_member(
    items: dict[str, PyObj], order: list[str], member: PyObj
) -> PyObj {
    probe = PySet(t="set", items=items, order=order, frozen=False);
    found = _set_find_entry(probe, member);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return py_none();
    }
    return _set_remove_slot(probe, expect_str(found));
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
        # Internal slot keys in insertion order (supports hash collisions).
        order: list[str] = [],
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
        _dict_ensure_order(self);
        keys: list[str] = [];
        for sk in self.order {
            keys.append(sk);
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
        found = _dict_find_entry(self, index);
        if is_error(found) {
            return found;
        }
        if found.t == "none" {
            return py_error("KeyError", dict_key_repr(index));
        }
        sk = expect_str(found);
        return self.items[sk].value;
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        found = _dict_find_entry(self, index);
        if is_error(found) {
            return found;
        }
        if found.t != "none" {
            sk = expect_str(found);
            # Overwrite value, keep the FIRST key object + slot position (CPython
            # semantics). Rebuild the entry rather than writing a nested obj field
            # in place (na external-field-write header hazard on the leaf). A plain
            # value overwrite leaves the key set unchanged, so it does NOT bump
            # version -- `for k in d: d[k] = ...` is legal in CPython (size guard).
            self.items[sk] = DictEntry(key=self.items[sk].key, value=value);
        } else {
            sk = _dict_new_slot(self, hk);
            self.items[sk] = DictEntry(key=index, value=value);
            self.order.append(sk);
            self.version = self.version + 1;
        }
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        found = _dict_find_entry(self, index);
        if is_error(found) {
            return found;
        }
        if found.t == "none" {
            return py_error("KeyError", dict_key_repr(index));
        }
        sk = expect_str(found);
        _dict_remove_slot(self, sk);
        self.version = self.version + 1;
        return py_none();
    }

    # Public helpers so bootstrap/ceval code never touches the raw entry map.
    def dict_set(keyobj: PyObj, value: PyObj) -> PyObj {
        return self.mp_ass_subscript(keyobj, value);
    }

    # CPython ``dict_equal`` adapted to hashkey buckets, as a method so both
    # the tp_richcompare slot and free helpers share one implementation.
    def dict_equal(b: PyDict) -> PyObj {
        _dict_ensure_order(self);
        _dict_ensure_order(b);
        if len(self.order) != len(b.order) {
            return PyBool(t="bool", val=False);
        }
        for sk in self.order {
            ent = self.items[sk];
            ak = ent.key;
            av = ent.value;
            bfound = _dict_find_entry(b, ak);
            if is_error(bfound) {
                return bfound;
            }
            if bfound.t == "none" {
                return PyBool(t="bool", val=False);
            }
            bsk = expect_str(bfound);
            bv = b.items[bsk].value;
            if av is not bv {
                veq = PyObject_RichCompare(av, bv, Py_EQ);
                if is_error(veq) {
                    return veq;
                }
                if _richcompare_truth(veq) != 1 {
                    return PyBool(t="bool", val=False);
                }
            }
        }
        return PyBool(t="bool", val=True);
    }

    # CPython dicts have no ordering (dict_compare only answers EQ/NE), so any
    # other op defers to the reflected/identity fallback -> ordering TypeError.
    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if (kind != Py_EQ and kind != Py_NE) or not isinstance(other, PyDict) {
            return PY_NOT_IMPLEMENTED;
        }
        eq = self.dict_equal(other as PyDict);
        if is_error(eq) {
            return eq;
        }
        if kind == Py_NE {
            return PyBool(t="bool", val=_richcompare_truth(eq) != 1);
        }
        return eq;
    }

    def dict_contains(keyobj: PyObj) -> bool {
        found = _dict_find_entry(self, keyobj);
        if is_error(found) {
            return False;
        }
        return found.t != "none";
    }

    def dict_keys -> list[PyObj] {
        _dict_ensure_order(self);
        out: list[PyObj] = [];
        for sk in self.order {
            out.append(self.items[sk].key);
        }
        return out;
    }

    def dict_values -> list[PyObj] {
        _dict_ensure_order(self);
        out: list[PyObj] = [];
        for sk in self.order {
            out.append(self.items[sk].value);
        }
        return out;
    }

    # Values re-keyed by their string key (only entries whose key is a PyStr).
    # For the inherently str-keyed consumers: kwdefaults, %(name) mapping format.
    def dict_str_map -> dict[str, PyObj] {
        _dict_ensure_order(self);
        out: dict[str, PyObj] = {};
        for sk in self.order {
            `entry = self.items[sk];
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
        order: list[str] = [],
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
        hkr = member.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a set element", member);
        }
        hk = hashkey_str(hkr);
        found = _set_find_entry(self, member);
        if is_error(found) {
            return found;
        }
        if found.t != "none" {
            return py_none();
        }
        # First occurrence wins: {1, 1.0, True} keeps the int 1 it saw first
        # (CPython set-literal insertion order). Overwriting would keep the last.
        sk = _set_new_slot(self, hk);
        self.items[sk] = member;
        self.order.append(sk);
        return py_none();
    }

    # Remove and return an arbitrary member (the first in iteration order, which
    # is deterministic here). Empty set -> KeyError, matching CPython's set.pop().
    def set_pop -> PyObj {
        _set_ensure_order(self);
        if len(self.order) == 0 {
            return py_error("KeyError", "pop from an empty set");
        }
        sk = self.order[0];
        member = self.items[sk];
        _set_remove_slot(self, sk);
        return member;
    }

    def set_discard(member: PyObj) -> PyObj {
        found = _set_find_entry(self, member);
        if is_error(found) {
            return py_error("TypeError", "unhashable type");
        }
        if found.t != "none" {
            sk = expect_str(found);
            _set_remove_slot(self, sk);
        }
        return py_none();
    }

    def set_clear -> PyObj {
        self.items = {};
        self.order = [];
        return py_none();
    }

    def set_copy -> PyObj {
        _set_ensure_order(self);
        copy_items: dict[str, PyObj] = {};
        copy_order: list[str] = [];
        for sk in self.order {
            copy_items[sk] = self.items[sk];
            copy_order.append(sk);
        }
        return PySet(t=self.t, items=copy_items, order=copy_order, frozen=self.frozen);
    }

    def set_members -> list[PyObj] {
        _set_ensure_order(self);
        out: list[PyObj] = [];
        for sk in self.order {
            out.append(self.items[sk]);
        }
        return out;
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.set_members(), index=0);
    }

    def tp_bool -> bool {
        return len(self.items) != 0;
    }

    # Only frozensets are hashable (mutable set -> explicit unhashable error).
    # The digest is order-independent: member subkeys are sorted (manual insertion
    # sort, na-clean) so frozenset({1,2}) and frozenset({2,1}) share one key.
    def tp_hashkey -> PyObj {
        if not self.frozen {
            return py_error("TypeError", "unhashable type");
        }
        _set_ensure_order(self);
        keys: list[str] = [];
        for sk in self.order {
            hkr = self.items[sk].tp_hashkey();
            if is_error(hkr) {
                return hkr;
            }
            keys.append(hashkey_str(hkr));
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
        return PyStr(t="str", val=result);
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if not isinstance(other, PySet) {
            return py_error("TypeError", "unsupported operand types");
        }
        o = other as PySet;
        _set_ensure_order(self);
        _set_ensure_order(o);
        result_items: dict[str, PyObj] = {};
        result_order: list[str] = [];
        if kind == NB_OR {
            for sk in self.order {
                err = _set_push_member(result_items, result_order, self.items[sk]);
                if is_error(err) {
                    return err;
                }
            }
            for sk in o.order {
                err = _set_push_member(result_items, result_order, o.items[sk]);
                if is_error(err) {
                    return err;
                }
            }
        } elif kind == NB_AND {
            for sk in self.order {
                m = self.items[sk];
                if o.set_contains(m) {
                    err = _set_push_member(result_items, result_order, m);
                    if is_error(err) {
                        return err;
                    }
                }
            }
        } elif kind == NB_SUBTRACT {
            for sk in self.order {
                m = self.items[sk];
                if not o.set_contains(m) {
                    err = _set_push_member(result_items, result_order, m);
                    if is_error(err) {
                        return err;
                    }
                }
            }
        } elif kind == NB_XOR {
            for sk in self.order {
                err = _set_push_member(result_items, result_order, self.items[sk]);
                if is_error(err) {
                    return err;
                }
            }
            for sk in o.order {
                m = o.items[sk];
                probe = PySet(
                    t=self.t, items=result_items, order=result_order, frozen=False
                );
                if probe.set_contains(m) {
                    err = _set_remove_member(result_items, result_order, m);
                    if is_error(err) {
                        return err;
                    }
                } else {
                    err = _set_push_member(result_items, result_order, m);
                    if is_error(err) {
                        return err;
                    }
                }
            }
        } else {
            return py_error("TypeError", "unsupported operand types");
        }
        return PySet(
            t=self.t, items=result_items, order=result_order, frozen=self.frozen
        );
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
# Tri-state truth of a comparison/protocol result: 1 true, 0 false, -1 error
# (CPython PyObject_RichCompareBool / PyObject_IsTrue convention). Canonical
# implementation lives here (acyclic leaf); abstract_protocol re-exports it for
# dict/list/set helpers and external protocol callers.
def _richcompare_truth(res: PyObj) -> int {
    if is_error(res) {
        return -1;
    }
    if isinstance(res, PyBool) {
        if (res as PyBool).val {
            return 1;
        }
        return 0;
    }
    if res.t == "none" {
        return 0;
    }
    if res.t == "int" {
        if (res as PyInt).val != 0 {
            return 1;
        }
        return 0;
    }
    return 1;
}

# CPython ``PyObject_RichCompare`` (abstract.c do_richcompare): left slot,
# reflected right slot, then the EQ/NE identity fallback; ordering without a
# slot raises the standard TypeError. Lives on the leaf so container
# tp_richcompare slots below can run element comparisons through the same
# protocol -- user dunders ride along via PyUserObj.tp_richcompare.
def PyObject_RichCompare(v: PyObj, w: PyObj, op: int) -> PyObj {
    res = v.tp_richcompare(op, w);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    swapped = _PY_SWAPPED_OP[op];
    res = w.tp_richcompare(swapped, v);
    if is_error(res) {
        return res;
    }
    if res is not PY_NOT_IMPLEMENTED {
        return res;
    }
    if op == Py_EQ {
        return PyBool(t="bool", val=v is w);
    }
    if op == Py_NE {
        return PyBool(t="bool", val=v is not w);
    }
    return py_ordering_type_error(op, v, w, _base_type_name);
}

# CPython ``tp_name`` for a builtin-boxed value, keyed by the ``t`` tag.
# User subclasses and dict views carry richer names; ceval layers those on in
# ``_compare_type_name``, which wraps this for its own ordering/binop sites.
def _base_type_name(v: PyObj) -> str {
    if v.t == "none" {
        return "NoneType";
    }
    return v.t;
}

# The CPython ordering TypeError:
# "'<' not supported between instances of 'int' and 'str'".
# ``type_name_fn`` resolves each operand's type name so callers with richer
# operand kinds (user classes, dict views) can supply their own namer.
def py_ordering_type_error(
    op_kind: int, v: PyObj, w: PyObj, type_name_fn: any
) -> PyObj {
    ops = ["<", "<=", "", "", ">", ">="];
    if op_kind < 0 or op_kind >= len(ops) or ops[op_kind] == "" {
        return py_error("TypeError", "invalid rich comparison opcode");
    }
    return py_error(
        "TypeError",
        "'"
            + ops[op_kind]
            + "' not supported between instances of '"
            + (type_name_fn(v) as str)
            + "' and '"
            + (type_name_fn(w) as str)
            + "'"
    );
}

# Integer tri-state: 1 true, 0 false, -1 error (matches C API).
def PyObject_RichCompareBool(v: PyObj, w: PyObj, op: int) -> int {
    if v is w {
        if op == Py_EQ {
            return 1;
        }
        if op == Py_NE {
            return 0;
        }
    }
    res = PyObject_RichCompare(v, w, op);
    return _richcompare_truth(res);
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

# CPython 3.14's two-part unhashable TypeError, quoted at the insertion site
# (set element / dict key) with the operand's real type name.
def _unhashable_error(what: str, v: PyObj) -> PyObj {
    name = v.tp_type_name();
    return py_error(
        "TypeError",
        "cannot use '" + name + "' as " + what + " (unhashable type: '" + name + "')"
    );
}

def _set_contains_elem(so: PySet, key: PyObj) -> PyObj {
    found = _set_find_entry(so, key);
    if is_error(found) {
        return found;
    }
    if found.t == "none" {
        return PyBool(t="bool", val=False);
    }
    return PyBool(t="bool", val=True);
}

def _pyset_richcompare_na(op: int, v: PySet, w: PySet) -> PyObj {
    _set_ensure_order(v);
    _set_ensure_order(w);
    v_sub = True;
    for sk in v.order {
        elem = v.items[sk];
        found = _set_contains_elem(w, elem);
        if is_error(found) {
            return found;
        }
        if not (found as PyBool).val {
            v_sub = False;
        }
    }
    w_sub = True;
    for sk in w.order {
        elem = w.items[sk];
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

# One traceback entry (CPython PyTracebackObject). The chain heads at the
# OUTERMOST frame the exception passed through (the catching frame) and tb_next
# walks toward the raise point; entries are prepended as frames unwind. An entry
# keeps the code object and the line of the instruction where propagation
# crossed this frame -- never a live frame reference -- so holding a traceback
# cannot pin an execution stack and no reference cycles arise.
obj PyTraceback(PyObj) {
    has tb_next: any = None,
        code: any = None,
        tb_lineno: int = 0,
        tb_lasti: int = 0;

    def tp_getattro(name2: str) -> PyObj {
        # Identity dunder: tb.__class__.__name__ reads 'traceback' like any
        # CPython object (object.__class__ never raises AttributeError).
        if name2 == "__class__" {
            return py_exception_type("traceback");
        }
        if name2 == "tb_next" {
            if self.tb_next is not None {
                return self.tb_next as PyObj;
            }
            return py_none();
        }
        if name2 == "tb_lineno" or name2 == "tb_lasti" or name2 == "tb_frame" {
            # tb_lineno/tb_lasti are plain int attributes on C tracebacks too.
            if name2 == "tb_lineno" {
                return PyInt(t="int", val=self.tb_lineno);
            }
            if name2 == "tb_lasti" {
                return PyInt(t="int", val=self.tb_lasti);
            }
            return PyTracebackFrame(
                t="frame", frame_code=self.code, frame_lineno=self.tb_lineno
            );
        }
        return py_error("AttributeError", name2);
    }
}

# Minimal frame view behind traceback entries: f_code/f_lineno answer the two
# idioms every traceback consumer uses (traceback.py, logging, repr of frames).
# f_back is always None -- the chain lives on the traceback, not on frames.
obj PyTracebackFrame(PyObj) {
    has frame_code: any,
        frame_lineno: int;

    def tp_getattro(name2: str) -> PyObj {
        # Identity dunder: frame.__class__.__name__ reads 'frame' (CPython).
        if name2 == "__class__" {
            return py_exception_type("frame");
        }
        if name2 == "f_code" {
            if self.frame_code is not None {
                return self.frame_code as PyObj;
            }
            return py_none();
        }
        if name2 == "f_lineno" {
            return PyInt(t="int", val=self.frame_lineno);
        }
        if name2 == "f_back" {
            return py_none();
        }
        return py_error("AttributeError", name2);
    }
}

# Canonical builtin-exception hierarchy: direct parent links from CPython
# ``Lib/test/exception_hierarchy.txt``. Single source of truth for name-level
# subclass tests (except-matching, isinstance/issubclass, per-type str/repr
# dispatch); exceptions_core and ceval build on this via exc_is_subclass_of.
glob EXC_PARENT: dict[str, str] = {
         "BaseExceptionGroup": "BaseException",
         "GeneratorExit": "BaseException",
         "KeyboardInterrupt": "BaseException",
         "SystemExit": "BaseException",
         "Exception": "BaseException",
         "ArithmeticError": "Exception",
         "FloatingPointError": "ArithmeticError",
         "OverflowError": "ArithmeticError",
         "ZeroDivisionError": "ArithmeticError",
         "AssertionError": "Exception",
         "AttributeError": "Exception",
         "BufferError": "Exception",
         "EOFError": "Exception",
         "ExceptionGroup": "Exception",
         # dataclasses.FrozenInstanceError: CPython defines it under AttributeError
         # (Lib/dataclasses.py), so guest `except AttributeError` catches frozen
         # assignment errors through the name-level hierarchy walk.
         "FrozenInstanceError": "AttributeError",
         "ImportError": "Exception",
         "ModuleNotFoundError": "ImportError",
         "LookupError": "Exception",
         "IndexError": "LookupError",
         "KeyError": "LookupError",
         "MemoryError": "Exception",
         "NameError": "Exception",
         "UnboundLocalError": "NameError",
         "OSError": "Exception",
         "BlockingIOError": "OSError",
         "ChildProcessError": "OSError",
         "ConnectionError": "OSError",
         "BrokenPipeError": "ConnectionError",
         "ConnectionAbortedError": "ConnectionError",
         "ConnectionRefusedError": "ConnectionError",
         "ConnectionResetError": "ConnectionError",
         "FileExistsError": "OSError",
         "FileNotFoundError": "OSError",
         "InterruptedError": "OSError",
         "IsADirectoryError": "OSError",
         "NotADirectoryError": "OSError",
         "PermissionError": "OSError",
         "ProcessLookupError": "OSError",
         "TimeoutError": "OSError",
         "ReferenceError": "Exception",
         "RuntimeError": "Exception",
         "NotImplementedError": "RuntimeError",
         "PythonFinalizationError": "RuntimeError",
         "RecursionError": "RuntimeError",
         "StopAsyncIteration": "Exception",
         "StopIteration": "Exception",
         "SyntaxError": "Exception",
         "IndentationError": "SyntaxError",
         "TabError": "IndentationError",
         "_IncompleteInputError": "SyntaxError",
         "SystemError": "Exception",
         "TypeError": "Exception",
         "ValueError": "Exception",
         "UnicodeError": "ValueError",
         "UnicodeDecodeError": "UnicodeError",
         "UnicodeEncodeError": "UnicodeError",
         "UnicodeTranslateError": "UnicodeError",
         "Warning": "Exception",
         "BytesWarning": "Warning",
         "DeprecationWarning": "Warning",
         "EncodingWarning": "Warning",
         "FutureWarning": "Warning",
         "ImportWarning": "Warning",
         "PendingDeprecationWarning": "Warning",
         "ResourceWarning": "Warning",
         "RuntimeWarning": "Warning",
         "SyntaxWarning": "Warning",
         "UnicodeWarning": "Warning",
         "UserWarning": "Warning",

     },
     EXC_EXTRA_PARENTS: dict[str, str] = {"ExceptionGroup": "BaseExceptionGroup",},
     OSERROR_ERRNO_MAP: dict[int, str] = {
         1: "PermissionError",  # EPERM
         2: "FileNotFoundError",  # ENOENT
         3: "ProcessLookupError",  # ESRCH
         4: "InterruptedError",  # EINTR
         11: "BlockingIOError",  # EAGAIN / EWOULDBLOCK
         13: "PermissionError",  # EACCES
         17: "FileExistsError",  # EEXIST
         20: "NotADirectoryError",  # ENOTDIR
         21: "IsADirectoryError",  # EISDIR
         32: "BrokenPipeError",  # EPIPE
         103: "ConnectionAbortedError",  # ECONNABORTED
         104: "ConnectionResetError",  # ECONNRESET
         108: "BrokenPipeError",  # ESHUTDOWN
         110: "TimeoutError",  # ETIMEDOUT
         111: "ConnectionRefusedError",  # ECONNREFUSED
         114: "BlockingIOError",  # EALREADY
         115: "BlockingIOError",  # EINPROGRESS

     };

# Extra direct parents for multiple-inheritance nodes of the builtin tree.
# CPython has exactly one (``class ExceptionGroup(BaseExceptionGroup,
# Exception)``), which the single-parent EXC_PARENT chain cannot express:
# ``issubclass(ExceptionGroup, BaseExceptionGroup)`` must hold even though
# BaseExceptionGroup is not reachable through Exception. Consulted by
# exc_is_subclass_of alongside EXC_PARENT.

# CPython's OSError smart-mapping (Python/errors.c,
# PyErr_SetFromErrnoWithFilenameObjects): when OSError itself is called with
# >=2 positional args and an int first arg, the errno selects a subclass.
# Values are the Linux (asm-generic) errno numbering, each entry probed
# against the host interpreter; errnos absent here stay plain OSError
# (verified: EBUSY(16), EINVAL(22), ... do NOT map on host).
# Membership test for the builtin exception tree (every name in EXC_PARENT
# plus the BaseException root).
def is_builtin_exception_name(name: str) -> bool {
    return name == "BaseException" or name in EXC_PARENT;
}

# Name-level subclass test over EXC_PARENT (inclusive of `name == base`),
# with multiple-inheritance parents from EXC_EXTRA_PARENTS.
def exc_is_subclass_of(name: str, base: str) -> bool {
    if name == base {
        return True;
    }
    cur = name;
    while cur in EXC_PARENT {
        if cur in EXC_EXTRA_PARENTS
            and exc_is_subclass_of(EXC_EXTRA_PARENTS[cur], base) {
            return True;
        }
        cur = EXC_PARENT[cur];
        if cur == base {
            return True;
        }
    }
    return False;
}

def _exc_field_int(fields: dict[str, PyObj], key: str) -> int {
    # -1 encodes "absent / not an int" so callers can distinguish a stored 0.
    if key in fields {
        v = fields[key];
        if isinstance(v, PyInt) {
            return (v as PyInt).val;
        }
    }
    return -1;
}

def _exc_field_str(fields: dict[str, PyObj], key: str) -> str {
    if key in fields {
        v = fields[key];
        if isinstance(v, PyStr) {
            return (v as PyStr).val;
        }
        if isinstance(v, PyInt) {
            return str((v as PyInt).val);
        }
    }
    return "";
}

def _exc_has_value(fields: dict[str, PyObj], key: str) -> bool {
    return key in fields and not isinstance(fields[key], PyNoneType);
}

# CPython ``oserror_init`` (posix branch): parse every argument arity into
# errno/strerror/filename/filename2, trimming the stored args tuple to
# ``(errno, strerror)`` -- filename data lives on attributes only.
def _oserror_parse(args: list[PyObj]) -> dict[str, PyObj] {
    # Every arity fills all four members: CPython's oserror_init runs for every
    # construction form (including the plain-message one-arg form), and its
    # getsets read unset members as None instead of raising AttributeError.
    fields: dict[str, PyObj] = {};
    fields["errno"] = py_none();
    fields["strerror"] = py_none();
    fields["filename"] = py_none();
    fields["filename2"] = py_none();
    n = len(args);
    if n == 0 {
        return fields;
    }
    if n == 1 {
        # OSError(5): errno-only form; OSError('plain'): generic message.
        if isinstance(args[0], PyInt) {
            fields["errno"] = args[0];
        }
        return fields;
    }
    fields["errno"] = args[0];
    fields["strerror"] = args[1];
    # Unset optional members read as None (the C struct's zero-init state).
    fields["filename"] = args[2] if n >= 3 else py_none();
    fields["filename2"] = args[4] if n >= 5 else py_none();
    return fields;
}

# Trimming of ``.args`` mirrors CPython oserror_init; every construction form
# succeeds because all OSError arities map to typed fields.
def _construct_oserror(name: str, args: list[PyObj]) -> PyException {
    # CPython OSErrorInit smart-mapping: only the bare OSError constructor
    # remaps; explicit subclasses (PermissionError(13, 'p')) keep their own
    # identity. The multi-arg int-errno form is required: OSError('msg') and
    # OSError('a', 'b') stay plain (verified against host).
    type_name = name;
    if name == "OSError" and len(args) >= 2 and isinstance(args[0], PyInt) {
        mapped = OSERROR_ERRNO_MAP.get((args[0] as PyInt).val);
        if mapped is not None {
            type_name = mapped;
        }
    }
    parsed = _oserror_parse(args);
    # CPython keeps only (errno, strerror) in .args once filename parsing ran.
    exc_args: list[PyObj] = [];
    if len(args) <= 1 {
        exc_args.extend(args);
    } else {
        exc_args.extend([args[0], args[1]]);
    }
    message = "";
    if len(exc_args) == 1 {
        message = expect_str(exc_args[0]);
    }
    return PyException(
        t="exception",
        type_name=type_name,
        message=message,
        args=exc_args,
        type_fields=parsed
    );
}

# CPython ``ImportError.__init__``: msg[, name[, path]] positional plus name= /
# path= kwargs. Positional extras stay in .args verbatim; kwargs never enter it.
def _construct_import_error(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyException {
    fields: dict[str, PyObj] = {};
    if "name" in kwargs {
        fields["name"] = kwargs["name"];
    } elif len(args) >= 2 {
        fields["name"] = args[1];
    } else {
        fields["name"] = py_none();
    }
    if "path" in kwargs {
        fields["path"] = kwargs["path"];
    } elif len(args) >= 3 {
        fields["path"] = args[2];
    } else {
        fields["path"] = py_none();
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

# CPython ``SyntaxError.__init__``: msg[, (filename, lineno, offset, text) | info-dict].
def _construct_syntax_error(name: str, args: list[PyObj]) -> PyException {
    fields: dict[str, PyObj] = {};
    if len(args) > 0 {
        fields["msg"] = args[0];
    } else {
        fields["msg"] = py_none();
    }
    if len(args) > 1 {
        info = args[1];
        if isinstance(info, PyTuple) {
            items = (info as PyTuple).items;
            labels = ["filename", "lineno", "offset", "text"];
            for i in range(len(labels)) {
                if i < len(items) {
                    fields[labels[i]] = items[i];
                } else {
                    fields[labels[i]] = py_none();
                }
            }
        }
        # Dict-form info is served by attribute delegation when the instance
        # crosses back from the host; native dicts are rare enough that the
        # tuple form is the one pinned by conformance probes.
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

# CPython ``Unicode(Decode|Encode|Translate)Error.__init__``:
# (encoding, object, start, end, reason), all five required.
def _construct_unicode_error(name: str, args: list[PyObj]) -> PyObj {
    if len(args) != 5 {
        kind = "Decode";
        if name == "UnicodeEncodeError" {
            kind = "Encode";
        } elif name == "UnicodeTranslateError" {
            kind = "Translate";
        }
        return py_error(
            "TypeError",
            "Unicode" + kind + "Error constructor takes exactly 5 arguments"
        );
    }
    fields: dict[str, PyObj] = {};
    keys = ["encoding", "object", "start", "end", "reason"];
    for i in range(len(keys)) {
        fields[keys[i]] = args[i];
    }
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    message = "";
    if len(args) == 1 {
        message = expect_str(args[0]);
    }
    return PyException(
        t="exception",
        type_name=name,
        message=message,
        args=exc_args,
        type_fields=fields
    );
}

# CPython ``PySequence_Tuple`` over the native shapes our VM produces:
# tuples/lists pass through; str/dict iterate (sq_item protocol); generators
# and bare iterables lack sq_item -> False (caller raises the "must be a
# sequence" TypeError). range and user-defined sequences need VM-side
# protocol dispatch (PyRange lives in ceval; P3 split kernel shares this seam).
def _py_sequence_tuple(o: PyObj, out: list[PyObj]) -> bool {
    if isinstance(o, PyTuple) {
        out.extend((o as PyTuple).items);
        return True;
    }
    if isinstance(o, PyList) {
        out.extend((o as PyList).items);
        return True;
    }
    if isinstance(o, PyStr) {
        for ch in (o as PyStr).val {
            out.append(PyStr(t="str", val=ch));
        }
        return True;
    }
    if isinstance(o, PyDict) {
        _dict_ensure_order(o as PyDict);
        d = o as PyDict;
        for sk in d.order {
            out.append(d.items[sk].key);
        }
        return True;
    }
    return False;
}

# CPython ``_BaseExceptionGroup_new_impl`` (Objects/exceptions.c). The
# positional-arity and message-type errors carry the FIXED literal
# "BaseExceptionGroup.__new__" regardless of which group class the call went
# through (host: ExceptionGroup('m') reports the BaseExceptionGroup parser),
# while the keyword rejection names the FINAL selected type. Validation order
# mirrors the C flow exactly: arity, msg str-check, PySequence_Tuple,
# non-empty, per-item instance scan tracking BaseException-only leaves, nest
# rejection under ExceptionGroup subclasses, auto-selection of ExceptionGroup
# for exact-BaseExceptionGroup calls whose leaves are all Exceptions, and the
# keyword check LAST.
def _construct_exc_group(
    name: str, args: list[PyObj], kwargs: dict[str, PyObj]
) -> PyObj {
    if len(args) != 2 {
        return py_error(
            "TypeError",
            "BaseExceptionGroup.__new__() takes exactly 2 arguments ("
                + str(len(args))
                + " given)",
        );
    }
    if args[0].t != "str" {
        return py_error(
            "TypeError",
            "BaseExceptionGroup.__new__() argument 1 must be str, not " + args[0].t,
        );
    }
    seq_items: list[PyObj] = [];
    if not _py_sequence_tuple(args[1], seq_items) {
        return py_error("TypeError", "second argument (exceptions) must be a sequence");
    }
    items: list[PyObj] = [];
    has_base_leaf = False;
    for idx in range(len(seq_items)) {
        item = seq_items[idx];
        # Exception-instance membership. User-subclass instances (t=="instance"
        # / host proxies) are rejected until family resolution gains an
        # objects.jac-visible seam -- PyClass/class_mro live in ceval.
        if item.t != "exception" {
            return py_error(
                "ValueError",
                "Item "
                    + str(idx)
                    + " of second argument (exceptions) is not an exception",
            );
        }
        leaf_name = (item as PyException).type_name;
        if not exc_is_subclass_of(leaf_name, "Exception") {
            has_base_leaf = True;
        }
        items.append(item);
    }
    if len(items) == 0 {
        return py_error(
            "ValueError", "second argument (exceptions) must be a non-empty sequence"
        );
    }
    final_name = name;
    if has_base_leaf {
        if exc_is_subclass_of(name, "ExceptionGroup") {
            return py_error(
                "TypeError", "Cannot nest BaseExceptions in an ExceptionGroup"
            );
        }
    } elif name == "BaseExceptionGroup" {
        # CPython selects the ExceptionGroup layout when every contained leaf
        # derives from Exception and the call targeted BaseExceptionGroup
        # itself (subclasses keep their own identity).
        final_name = "ExceptionGroup";
    }
    if len(kwargs) > 0 {
        return py_error("TypeError", final_name + "() takes no keyword arguments");
    }
    # BaseException.args presents (message, [exceptions-list]) on groups
    # (host: ExceptionGroup('hello', [ValueError()]).args); .message/.exceptions
    # serve the typed members read-only.
    exc_args: list[PyObj] = [args[0]];
    arg_list_items: list[PyObj] = [];
    arg_list_items.extend(items);
    exc_args.append(PyList(t="list", items=arg_list_items));
    excs_copy: list[PyObj] = [];
    excs_copy.extend(items);
    return PyExcGroup(
        t="exception",
        type_name=final_name,
        message=(args[0] as PyStr).val,
        args=exc_args,
        excs=excs_copy
    );
}

# Unbound marker served for ExceptionGroup.split / .subgroup on the TYPE
# object; instance calls bind through PyExcGroupMethod on the ceval side.
obj PyEgroupTypeMember(PyObj) {
    has name: str;
}


obj PyExceptionType(PyObj) {
    has name: str;

    def tp_getattro(name2: str) -> PyObj {
        # Type-object identity surface: e.__class__.__name__ idioms.
        if name2 == "__name__" or name2 == "__qualname__" {
            return PyStr(t="str", val=self.name);
        }
        # P3 kernel entry points exist on the type for hasattr/introspection;
        # calls route through the bound instance methods.
        if name2 == "split" or name2 == "subgroup" {
            return PyEgroupTypeMember(t="egroup_type_member", name=name2);
        }
        return py_error("AttributeError", name2);
    }

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Families with dedicated constructor semantics (CPython oserror_init,
        # ImportError/SyntaxError/Unicode*Error __init__) parse their arguments
        # into typed fields before falling through to the generic form.
        if self.name != "Exception"
            and self.name != "BaseException"
            and exc_is_subclass_of(self.name, "OSError") {
            if len(kwargs) > 0 {
                return py_error(
                    "TypeError", self.name + "() takes no keyword arguments"
                );
            }
            return _construct_oserror(self.name, args);
        }
        # ImportError/ModuleNotFoundError is the ONLY builtin exception family
        # whose constructor accepts keywords (name=, path=); it keeps them.
        if self.name == "ImportError" or self.name == "ModuleNotFoundError" {
            return _construct_import_error(self.name, args, kwargs);
        }
        if self.name == "BaseExceptionGroup"
            or self.name == "ExceptionGroup"
            or exc_is_subclass_of(self.name, "BaseExceptionGroup") {
            return _construct_exc_group(self.name, args, kwargs);
        }
        # Every remaining builtin exception constructor rejects keyword
        # arguments byte-exact (host: ValueError(x=1) ->
        # TypeError('ValueError() takes no keyword arguments')).
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        if exc_is_subclass_of(self.name, "SyntaxError") {
            return _construct_syntax_error(self.name, args);
        }
        if self.name == "UnicodeDecodeError"
            or self.name == "UnicodeEncodeError"
            or self.name == "UnicodeTranslateError" {
            return _construct_unicode_error(self.name, args);
        }
        # Exception(*args): keep the FULL args tuple (BaseException.args), not just
        # the first, so `e.args`, str(e), and repr(e) round-trip faithfully. The
        # single-arg `message` shortcut stays for the common one-string case.
        message = "";
        if len(args) == 1 {
            message = expect_str(args[0]);
        }
        exc_args: list[PyObj] = [];
        exc_args.extend(args);
        # CPython stopiteration_init: StopIteration (and subclasses) store
        # args[0] as .value at construction (None when argless, args[0] even
        # with extra args). yield-from unwinding reads this payload out of the
        # raised instance (genobject.c unpacks StopIteration.value), so a
        # custom __next__ raising StopIteration(42) must carry it here.
        si_value: PyObj = py_none();
        if self.name == "StopIteration"
            or exc_is_subclass_of(self.name, "StopIteration") {
            if len(args) > 0 {
                si_value = args[0];
            }
        }
        return PyException(
            t="exception",
            type_name=self.name,
            message=message,
            args=exc_args,
            value=si_value
        );
    }
}

# Bound BaseException.__setstate__(state) for native exceptions: 'args' is
# restored first (CPython BaseException_set_state order), remaining keys land
# in the instance attribute surface (type_fields), mirroring the instance-dict
# update CPython does for the rest of the state mapping.
obj ExcSetStateFn(PyObj) {
    has exc: PyException;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or len(kwargs) > 0 {
            return py_error("TypeError", "__setstate__() takes exactly 1 argument");
        }
        if not isinstance(args[0], PyDict) {
            return py_error(
                "TypeError",
                "__setstate__() argument must be a dict, not '" + args[0].t + "'"
            );
        }
        state = args[0] as PyDict;
        rest: list[tuple[str, PyObj]] = [];
        for skey in state.items {
            sval = state.items[skey].value;
            if isinstance(skey, PyStr) {
                if (skey as PyStr).val == "args" {
                    set = self.exc.tp_setattro("args", sval);
                    if is_error(set) {
                        return set;
                    }
                    continue;
                }
                rest.append(((skey as PyStr).val, sval));
            }
        }
        for pair in rest {
            set = self.exc.tp_setattro(pair[0], pair[1]);
            if is_error(set) {
                # Unknown/readonly names are stored in type_fields instead of
                # failing the restore, matching the instance-dict semantics
                # CPython uses for non-slot attributes.
                self.exc.type_fields[pair[0]] = pair[1];
            }
        }
        return py_none();
    }
}

# CPython BaseException.args_setter: tuples pass through, lists convert,
# anything else raises TypeError. Shared by PyException.tp_setattro and user-
# exception instance writes so pre-raise and caught-wrapper paths stay aligned.
def _exception_args_from_value(value: PyObj) -> PyObj {
    items: list[PyObj] = [];
    if isinstance(value, PyTuple) {
        items.extend((value as PyTuple).items);
        return PyTuple(t="tuple", items=items);
    }
    if isinstance(value, PyList) {
        items.extend((value as PyList).items);
        return PyTuple(t="tuple", items=items);
    }
    return py_error("TypeError", "'" + value.t + "' object is not iterable");
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
        # Implicit chaining: raising while another exception is being handled
        # records that one here so e.__context__ reads it back (None when
        # raised outside any handler). Set by OP_RAISE_VARARGS in ceval.
        context: any = None,
        # StopIteration payload: `return x` in a generator surfaces as
        # StopIteration(x); .send()/next() carry the value here.
        value: any = None,
        # Writable BaseException attributes (CPython allows assignment to all
        # four). Defaults mirror the unset state; reads fall back to None.
        traceback: any = None,
        suppress_context: any = None,
        # Nearest builtin exception ancestor for USER subclass instances
        # (class MyErr(KeyError) -> "KeyError"), resolved from the MRO when the
        # instance is wrapped at raise time. Empty for direct builtin raises,
        # whose type_name already IS the builtin name. Drives per-type __str__
        # dispatch for subclasses without custom slots.
        family: str = "",
        # Type-specific constructor fields (OSError errno/strerror/filename,
        # ImportError name/path, SyntaxError lineno/text, Unicode*Error parts).
        # Populated by the typed constructors in PyExceptionType.tp_call and
        # served read-only by tp_getattro, mirroring the C struct members that
        # each exception type adds over BaseException.
        type_fields: dict[str, PyObj] = {};

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
        if name == "__setstate__" {
            # BaseException.__setstate__(state): restore protocol hook used by
            # pickle/copy and callable directly (gh-97591 test exercises it).
            return ExcSetStateFn(t="exc_setstate_fn", exc=self);
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
        if name == "__context__" {
            if self.context is not None {
                return self.context as PyObj;
            }
            return py_none();
        }
        # Identity dunder: e.__class__ resolves to the exception type object
        # (e.__class__.__name__ on caught exceptions is a core idiom). A raised
        # user subclass keeps its defining PyClass in `raw` so __class__ and
        # type() agree and chained __context__/__cause__ entries expose the
        # real class identity (not a synthetic PyExceptionType marker).
        if name == "__class__" {
            if self.raw is not None {
                raw_obj = self.raw as PyObj;
                if raw_obj.t == "instance" {
                    return raw_obj.tp_getattro("__class__");
                }
            }
            return py_exception_type(self.type_name);
        }
        if name == "__traceback__" {
            if self.traceback is not None {
                return self.traceback as PyObj;
            }
            return py_none();
        }
        if name == "__suppress_context__" {
            if self.suppress_context is not None {
                return self.suppress_context as PyObj;
            }
            # CPython's BaseException_new initializes __suppress_context__ to
            # False (not None) -- truthiness must be false-yet-bool.
            return PyBool(t="bool", val=False);
        }
        # Type-specific fields (e.errno, e.strerror, e.name, e.lineno, ...):
        # unset optional members read as None, exactly like the C structs'
        # zero-initialized slots.
        if name == "__notes__" {
            # PEP 678 notes: reads before any add_note yield an empty list.
            stored = self.type_fields.get("__notes__");
            if stored is not None and isinstance(stored, PyList) {
                items: list[PyObj] = [];
                items.extend((stored as PyList).items);
                return PyList(t="list", items=items);
            }
            return PyList(t="list", items=[]);
        }
        if name in self.type_fields {
            return self.type_fields[name];
        }
        # CPython OSError_getset: errno/strerror/filename/filename2 read as
        # None when unset, regardless of which constructor form ran -- covers
        # instances that bypassed the typed OSError constructor. (Note:
        # characters_written is NOT defaulted -- CPython raises AttributeError
        # for it until an IO write sets it.)
        if name == "errno"
            or name == "strerror"
            or name == "filename"
            or name == "filename2" {
            if self.family == "OSError"
                or exc_is_subclass_of(self.type_name, "OSError") {
                return py_none();
            }
        }
        return py_error("AttributeError", name);
    }

    # Attribute writes on a caught exception. CPython's BaseException exposes
    # args, __traceback__, __cause__, __context__, and __suppress_context__ as
    # writable; everything else stays read-only (AttributeError), matching the
    # tp_getattro surface above. Unknown-attribute writes keep raising because
    # these instances carry no user attribute dict.
    # Type enforcement lives HERE (not in ceval) by design: it only needs types
    # defined in objects.jac itself (PyTraceback, PyBool, the exception t tag),
    # so the old import-cycle blocker on enforcing these checks is gone.
    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name == "args" {
            coerced = _exception_args_from_value(value);
            if is_error(coerced) {
                return coerced;
            }
            items = (coerced as PyTuple).items;
            self.args = [];
            self.args.extend(items);
            # A caught user subclass keeps its live instance in `raw`; mirror
            # args onto it so bare re-raise and super().__init__ paths agree.
            if self.raw is not None {
                raw_obj = self.raw as PyObj;
                if raw_obj.t == "instance" {
                    stored: list[PyObj] = [];
                    stored.extend(items);
                    raw_obj.tp_setattro("args", PyTuple(t="tuple", items=stored));
                }
            }
            return py_none();
        }
        if name == "__traceback__" {
            if not isinstance(value, PyTraceback) and value.t != "none" {
                return py_error(
                    "TypeError", "__traceback__ must be a traceback or None"
                );
            }
            self.traceback = value;
            return py_none();
        }
        if name == "__cause__" {
            # PyErr_SetCause: the cause must be None or an exception instance,
            # and setting a real cause implies __suppress_context__ = True.
            if value.t != "none" and value.t != "exception" {
                return py_error(
                    "TypeError",
                    "exception cause must be None or derive from BaseException"
                );
            }
            self.cause = value;
            if value.t != "none" {
                self.suppress_context = PyBool(t="bool", val=True);
            }
            return py_none();
        }
        if name == "__context__" {
            if value.t != "none" and value.t != "exception" {
                return py_error(
                    "TypeError",
                    "exception context must be None or derive from BaseException"
                );
            }
            self.context = value;
            return py_none();
        }
        if name == "__suppress_context__" {
            if not isinstance(value, PyBool) {
                return py_error("TypeError", "attribute value type must be bool");
            }
            self.suppress_context = value;
            return py_none();
        }
        return py_error("AttributeError", name);
    }
}

# CPython ``BaseExceptionGroup`` (Objects/exceptions.c): a BaseException
# subtype carrying a validated non-empty tuple of exception instances plus the
# message. Subtyping PyException keeps every raise/match/chain path working
# unchanged (they all dispatch on t=="exception"/PyException); the group-only
# members ride the override below with explicit parent delegation.
obj PyExcGroup(PyException) {
    # Validated copy of the constructor's exception sequence; .exceptions
    # serves a fresh tuple over it so callers can't mutate group state.
    has excs: list[PyObj] = [];

    def tp_getattro(name: str) -> PyObj {
        if name == "message" {
            return PyStr(t="str", val=self.message);
        }
        if name == "exceptions" {
            items: list[PyObj] = [];
            items.extend(self.excs);
            return PyTuple(t="tuple", items=items);
        }
        return PyException.tp_getattro(self, name);
    }

    def tp_setattro(name: str, value: PyObj) -> PyObj {
        # CPython getset members reject writes with the bare member message.
        if name == "message" or name == "exceptions" {
            return py_error("AttributeError", "readonly attribute");
        }
        return PyException.tp_setattro(self, name, value);
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

# iter(callable, sentinel) two-argument form (CPython calliterobject): each
# __next__ calls the callable with no args; equality with the sentinel ends
# the iteration permanently.
obj PyCallableIter(PyObj) {
    has fn: PyObj,
        sentinel: PyObj,
        exhausted: bool = False;

    def tp_iter -> PyObj {
        return self;
    }
}

# Old-style sequence iterator (CPython sq_iterator over __getitem__):
# successive seq[index] until IndexError stops it. Data-only here so
# objects.jac stays na-clean; the step logic (seqiter_next) lives in ceval,
# mirroring the PyCallableIter/calliter_next split.
obj PySeqIter(PyObj) {
    has seq: PyObj,
        index: int = 0;

    def tp_iter -> PyObj {
        return self;
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "__setstate__" {
            return PySeqIterSetState(t="seqiter_setstate", it=self);
        }
        return py_error("AttributeError", name);
    }
}

# Pickle/iterator restore hook for old-style sequence iterators (CPython
# sq_iterator): __setstate__(index) rewinds the cursor so exhausted iterators
# can be resumed (array gh-128961).
obj PySeqIterSetState(PyObj) {
    has it: PySeqIter;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "__setstate__() takes no keyword arguments");
        }
        if len(args) != 1 {
            return py_error(
                "TypeError", "__setstate__() takes exactly one argument (index)"
            );
        }
        iv = args[0].to_index();
        if is_error(iv) {
            return iv;
        }
        self.it.index = (iv as PyInt).val;
        return py_none();
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

# Exact int-vs-finite-float comparison (TODO item 25): CPython compares the
# int against the float's EXACT value. float(2**53 + 1) rounds to 2**53, so
# promoting the int to float wrongly reports equality across the 2**53
# boundary. Truncation int(fv) is exact host arithmetic (arbitrary precision);
# the fractional remainder breaks ties. Precondition: fv finite, not NaN.
def _cmp_int_vs_float(a: int, fv: float) -> int {
    t = int(fv);
    frac = fv - float(t);
    if a < t {
        return -1;
    }
    if a > t {
        return 1;
    }
    if frac > 0.0 {
        return -1;
    }
    if frac < 0.0 {
        return 1;
    }
    return 0;
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
    hkr = index.tp_hashkey();
    if is_error(hkr) {
        return "<unhashable>";
    }
    return hashkey_str(hkr);
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

# py_error carrying the FULL BaseException.args tuple: host-raised module
# exceptions (struct.error('bad char ...')) keep e.args across the boundary.
# Message stays empty when args carry the text (BaseException_str rule).
def py_error_with_args(type_name: str, message: str, args: list[PyObj]) -> PyObj {
    exc_args: list[PyObj] = [];
    exc_args.extend(args);
    return PyError(
        t="error",
        exception=PyException(
            t="exception", type_name=type_name, message=message, args=exc_args
        ),
    );
}

def py_exception_type(name: str) -> PyObj {
    return PyExceptionType(t="exception_type", name=name);
}

# Unwrap a SUCCESSFUL tp_hashkey result to its key string. Only call after an
# is_error check -- the unhashable marker is a PyError, not a string.
def hashkey_str(hk_res: PyObj) -> str {
    return (hk_res as PyStr).val;
}

# True iff two tp_hashkey results encode the same key. An unhashable operand
# (a PyError marker) matches nothing -- const-table dedup and friends only ever
# see hashable values, so this stays total without raising.
def hashkey_equal(a: PyObj, b: PyObj) -> bool {
    if isinstance(a, PyStr) and isinstance(b, PyStr) {
        return (a as PyStr).val == (b as PyStr).val;
    }
    return False;
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

# Resolve a non-slice sequence subscript against a sequence of `length`
# (CPython PySequence_GetItem index path): __index__ coercion, negative wrap,
# bounds check. Returns the normalized PyInt position, or an error PyObj with
# the caller's type-specific TypeError / IndexError wording.
def _seq_index(index: PyObj, length: int, type_err: str, index_err: str) -> PyObj {
    idx = index.to_index();
    if is_error(idx) {
        return py_error("TypeError", type_err);
    }
    i = (idx as PyInt).val;
    if i < 0 {
        i = length + i;
    }
    if i >= 0 and i < length {
        return PyInt(t="int", val=i);
    }
    return py_error("IndexError", index_err);
}

# Resolve a PySlice against a sequence of `length` into concrete
# [start, stop, step], applying CPython's negative-index and clamping rules.
def slice_indices(sl: PySlice, length: int) -> list[int] {
    step = 1;
    if not isinstance(sl.step, PyNoneType) {
        step = expect_int(sl.step);
    }
    # CPython's PySlice_AdjustIndices raises ValueError before any stepping
    # loop runs; without this guard a zero-step slice never terminates.
    # Callers pre-check via _zero_step_error, so this is a fail-fast backstop
    # for any future caller that skips the pre-check.
    if step == 0 {
        raise ValueError("slice step cannot be zero");
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

def _slice_positions(length: int, sl: PySlice) -> list[int] {
    b = slice_indices(sl, length);
    i = b[0];
    stop = b[1];
    step = b[2];
    out: list[int] = [];
    if step > 0 {
        while i < stop {
            out.append(i);
            i = i + step;
        }
    } else {
        while i > stop {
            out.append(i);
            i = i + step;
        }
    }
    return out;
}

def _slice_objs(items: list[PyObj], sl: PySlice) -> list[PyObj] {
    out: list[PyObj] = [];
    for i in _slice_positions(len(items), sl) {
        out.append(items[i]);
    }
    return out;
}

def _slice_ints(vals: list[int], sl: PySlice) -> list[int] {
    out: list[int] = [];
    for i in _slice_positions(len(vals), sl) {
        out.append(vals[i]);
    }
    return out;
}

def _slice_str(s: str, sl: PySlice) -> str {
    out = "";
    for i in _slice_positions(len(s), sl) {
        out = out + s[i];
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

def:priv _is_digit(c: str) -> bool {
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

def str_mod_format(
    fmt: str, args: PyObj, str_fn: any = None, repr_fn: any = None
) -> PyObj {
    # str_fn/repr_fn: optional native slot dispatchers (ceval's py_str/py_repr)
    # so %s/%r consult user __str__/__repr__; None keeps the lifted scalar
    # stringifier (na-clean leaf callers).
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
            if str_fn is not None {
                # Callback path (native __str__ slot dispatch from ceval); a
                # raised exception propagates as an error result.
                sv = str_fn(arg) as PyObj;
                if is_error(sv) {
                    return sv;
                }
                piece = _trunc(expect_str(sv), prec);
            } else {
                piece = _trunc(_pyobj_str(arg), prec);
            }
        } elif conv == "r" {
            if repr_fn is not None {
                rv = repr_fn(arg) as PyObj;
                if is_error(rv) {
                    return rv;
                }
                piece = _trunc(expect_str(rv), prec);
            } else {
                piece = _trunc(_pyobj_repr(arg), prec);
            }
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

# Native shim "type" marker (isinstance-matchable shim classes): wraps a
# constructor callable and carries the PyObj.t tag its instances carry.
# py_isinstance answers marker matches with a single value.t comparison --
# no getattr probes, no host bridge. Registered by module shims that expose
# real class-shaped surfaces (traceback.FrameSummary, TracebackException,
# weakref.ReferenceType/ProxyType). Lives here (not ceval) so facade modules
# can wrap their own type surfaces without an import cycle.
obj ShimTypeMarker(PyObj) {
    has tag: str,
        ctor: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return (self.ctor as PyObj).tp_call(args, kwargs);
    }

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "__jac_shim_tag__" {
            return PyStr(t="str", val=self.tag);
        }
        return (self.ctor as PyObj).tp_getattro(name2);
    }
}
