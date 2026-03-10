"""Test type narrowing for isinstance checks.

Tests:
- Basic isinstance(x, T)
- isinstance with multiple types (tuple)
- isinstance with else branch
- Not isinstance (negation)
- Nested isinstance checks
"""

"""Base classes for testing"""
obj SuperClass {
    has class_var1: int = 0,
        property: None = None;
}

obj MyClass1(SuperClass) {
    has class_var2: int = 0,
        property2: None = None;
}

obj MyClass2(SuperClass) {
    has property2: None = None;
}

obj UnrelatedClass {
    has other_prop: str = "";
}


"""Test 1: Basic isinstance narrowing"""
def test_basic_isinstance(x: SuperClass | UnrelatedClass) {
    if isinstance(x, MyClass1) {
        # x should be narrowed to MyClass1
        val: int = x.class_var2;
    }
}


"""Test 2: isinstance with else branch"""
def test_isinstance_else(x: int | str) {
    if isinstance(x, int) {
        # x should be int
        int_val: int = x;
        result: int = x + 1;
    } else {
        # x should be str
        str_val: str = x;
        upper: str = x.upper();
    }
}


"""Test 3: isinstance with tuple of types"""
def test_isinstance_tuple(x: int | str | float | list) {
    if isinstance(x, (int, str)) {
        # x should be int | str
        y: int | str = x;
    } else {
        # x should be float | list
        z: float | list = x;
    }
}


"""Test 4: Negated isinstance"""
def test_not_isinstance(x: int | str) {
    if not isinstance(x, int) {
        # x should be str
        str_val: str = x;
    } else {
        # x should be int
        int_val: int = x;
    }
}


"""Test 5: Nested isinstance narrowing"""
obj Base1;

obj Sub1_1(Base1) {
    has value: str = "";
}

obj Sub1_2(Base1) {
    has value: Base1;
}

def test_nested_isinstance(node: Base1) {
    if isinstance(node, Sub1_1) {
        # node.value should be str
        str_val: str = node.value;
    } elif isinstance(node, Sub1_2) {
        # node.value should be Base1
        base_val: Base1 = node.value;
        # TODO: Attribute chain narrowing (isinstance(node.value, Sub1_1))
        # requires Phase 1.3 - CFG-based expression narrowing
        # if isinstance(node.value, Sub1_1) {
        #     sub_val: Sub1_1 = node.value;
        # }
    }
}


"""Test 6: isinstance with None type"""
def test_isinstance_none(x: int | None) {
    if isinstance(x, int) {
        # x should be int
        int_val: int = x;
    } else {
        # x should be None
        none_val: None = x;
    }
}


"""Test 7: isinstance preserving type info"""
def test_isinstance_preserve(x: list[int] | dict[str, int]) {
    if isinstance(x, list) {
        # x should still be list[int], not just list
        lst: list[int] = x;
    } else {
        # x should be dict[str, int]
        dct: dict[str, int] = x;
    }
}


"""Test 8: Redundant isinstance (should still work)"""
def test_redundant_isinstance(x: MyClass1) {
    if isinstance(x, SuperClass) {
        # x is still MyClass1 (subclass of SuperClass)
        val: MyClass1 = x;
    }
}
