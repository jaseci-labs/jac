"""Regression fixture: declaring two setters (or two getters / two deleters)
for the same property is a real duplicate and must raise E0076.

A property can have at most one setter, one getter, and one deleter. The
duplicate-accessor case is the structural mirror of the plain duplicate-method
case the standard E0076 check catches.
"""

obj Container {
    has _val: int = 0;

    @property
    def val -> int {
        return self._val;
    }

    @val.setter
    def val(new_val: int) {
        self._val = new_val;
    }

    @val.setter
    def val(new_val: int) {
        self._val = new_val * 2;
    }
}
