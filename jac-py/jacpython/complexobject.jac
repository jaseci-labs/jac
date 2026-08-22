# P3.2c — complex hash combination helpers.
# Lift: Objects/_lifted/complexobject_core.jac
import from objects { PyComplex, }

glob _PyHASH_IMAG: int = 1000003;

def complex_hash_combine(hashreal: int, hashimag: int) -> int {
    if hashreal == -1 or hashimag == -1 {
        return -1;
    }
    combined = hashreal + _PyHASH_IMAG * hashimag;
    if combined == -1 {
        return -2;
    }
    return combined;
}

def complex_imag_is_zero(c: PyComplex) -> bool {
    return c.imag == 0.0;
}
