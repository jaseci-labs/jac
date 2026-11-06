"""A C function defined in Jac, beside a private Jac helper it calls."""

import from c {
    def jac_c_export_answer(x: i64) -> i64 {
        return export_helper(x) + 41;
    }
}

def export_helper(x: i64) -> i64 {
    return x * 2;
}
