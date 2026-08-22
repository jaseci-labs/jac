# P3.2a — float core algorithms (repr, hash).
#
# Shortest round-trip repr: smallest ``%.*e`` precision that ``float()`` re-parses
# to the same double, then CPython's fixed vs exponential ``'r'`` style.
import from objects { PyFloat, PyInt, PyObj, PyStr, _digit_val, }
import from pyhash { float_hash_value, }

def _float_exp_suffix(s: str) -> int {
    i = 0;
    while i < len(s) {
        c = s[i];
        if c == "e" or c == "E" {
            sign = 1;
            j = i + 1;
            if j < len(s) and (s[j] == "+" or s[j] == "-") {
                if s[j] == "-" {
                    sign = -1;
                }
                j = j + 1;
            }
            exp = 0;
            while j < len(s) {
                d = _digit_val(s[j]);
                if d < 0 {
                    break;
                }
                exp = exp * 10 + d;
                j = j + 1;
            }
            return sign * exp;
        }
        i = i + 1;
    }
    return 0;
}

# CPython ``float_repr`` / ``PyFloat_Repr`` (shortest round-trip ``'r'`` style).
def float_repr(v: PyFloat) -> PyObj {
    d = v.val;
    if d != d {
        return PyStr(t="str", val="nan");
    }
    if d * 0.0 != 0.0 {
        if d < 0.0 {
            return PyStr(t="str", val="-inf");
        }
        return PyStr(t="str", val="inf");
    }
    if d == 0.0 {
        s0 = str(d);
        if len(s0) > 0 and s0[0] == "-" {
            return PyStr(t="str", val="-0.0");
        }
        return PyStr(t="str", val="0.0");
    }
    p = 0;
    best = "";
    while p <= 17 {
        candidate = f"{d:.{p}e}";
        if float(candidate) == d {
            best = candidate;
            break;
        }
        p = p + 1;
    }
    if best == "" {
        p = 17;
        best = f"{d:.17e}";
    }
    expo = _float_exp_suffix(best);
    decpt = expo + 1;
    ndig = p + 1;
    if decpt <= -4 or decpt > 16 {
        return PyStr(t="str", val=best);
    }
    frac = ndig - decpt;
    if frac < 0 {
        frac = 0;
    }
    out = f"{d:.{frac}f}";
    if frac == 0 {
        out = out + ".0";
    }
    return PyStr(t="str", val=out);
}

# CPython ``float_hash`` — ``_Py_HashDouble`` (+ pointer hash for NaN).
def float_hash_obj(v: PyFloat) -> PyObj {
    return PyInt(t="int", val=int(float_hash_value(v.val, id(v))));
}

# P3.2c — float core helpers (hash entry + EQ lane).
# Lift: Objects/_lifted/floatobject_core.jac
# Full shortest-repr / SipHash live in floatobject.jac + pyhash.jac already.
