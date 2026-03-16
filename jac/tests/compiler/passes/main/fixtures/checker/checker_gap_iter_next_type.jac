"""FIXED: enumerate and zip tuple unpacking now work correctly.

enumerate is FIXED:
- Self type resolution now works (TypeVarType("Self") substituted to class)
- enumerate.__iter__() returns Self -> enumerate[T]
- enumerate.__next__() returns tuple[int, T]
- For-loop unpacking correctly extracts idx:int and item:T

zip is FIXED:
- Version conditionals inside class bodies are now parsed by pyast_load_pass
- zip.__new__ overloads are correctly loaded and matched by arg count
- TypeVar bindings from __new__ params are substituted into return type
- zip[tuple[_T1, _T2]] correctly specializes to zip[tuple[Data, str]]

See Pyright's getTypeOfIterator function (typeEvaluator.ts:3048-3130).
"""

node Data {
    has name: str;
}

with entry {
    items: list[Data] = [Data(name="a"), Data(name="b")];

    for item in items {
        print(item.name);  # Works - item is Data
    }

    for (idx, item) in enumerate(items) {
        wrong_idx: str = idx;     # <-- Error: Cannot assign int to str
        wrong_item: int = item;   # <-- Error: Cannot assign Data to int
        print(item.name);         # <-- Works correctly
    }

    # Test 3: zip tuple unpacking (FIXED)
    names: list[str] = ["x", "y"];
    for (data, name) in zip(items, names) {
        # WORKS: data is Data, assigning to str errors
        wrong_data: str = data;   # <-- Error: Cannot assign Data to str

        # WORKS: name is str, assigning to int errors
        wrong_name: int = name;   # <-- Error: Cannot assign str to int

        print(data.name);  # <-- Works correctly
    }
}
