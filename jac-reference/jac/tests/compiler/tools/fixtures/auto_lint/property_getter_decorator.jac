"""A same-object getter decorator extends the property decorator it follows, so it
must be folded into the native accessor block alongside it -- never left behind as
a stray method.

A cross-object accessor decorator targets a property owned by another object, so it
has no local native form and must survive the rewrite untouched.
"""

obj Container {
    has _val: int = 0;

    @property
    def val -> int {
        return self._val;
    }

    @val.getter
    def val -> int {
        return self._val + 1;
    }

    @val.setter
    def val(new_val: int) {
        self._val = new_val;
    }
}

obj Extender(Container) {
    @Container.val.setter
    def val(new_val: int) {
        self._val = new_val * 2;
    }
}
