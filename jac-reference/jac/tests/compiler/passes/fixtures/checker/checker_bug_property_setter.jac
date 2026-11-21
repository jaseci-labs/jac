"""Property setter / getter / deleter must not be flagged as duplicate methods.

`@<name>.setter`, `@<name>.deleter`, and `@<name>.getter` decorators extend
an existing `@property` by reusing the same method name. This is the canonical
Python property pattern and must not trigger E0076 (Duplicate method).
"""

obj Container {
    has _val: int = 0,
        _name: str = "x";

    @property
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

    @property
    def name -> str {
        return self._name;
    }

    @name.setter
    def name(new_name: str) {
        self._name = new_name;
    }
}
