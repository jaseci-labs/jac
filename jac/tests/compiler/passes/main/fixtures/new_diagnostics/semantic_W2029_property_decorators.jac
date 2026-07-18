"""Python-style property decorators in an 'obj' are non-idiomatic and warn (W2029).

Jac has native property syntax, so the decorator forms get the same nudge that
'@classmethod' (W2006) and '@staticmethod' (W2007) already get. The 'class'
archetype is Python's compatibility escape hatch and stays exempt.
"""

obj Container {
    has _val: int = 0;

    @property
    def val -> int {
        return self._val;
    }

    @val.getter
    def val -> int {
        return self._val;
    }

    @val.setter
    def val(new_val: int) {
        self._val = new_val;
    }

    @val.deleter
    def val {
        self._val = 0;
    }
}

class Legacy {
    @property
    def v(self: Legacy) -> int {
        return 1;
    }
}
