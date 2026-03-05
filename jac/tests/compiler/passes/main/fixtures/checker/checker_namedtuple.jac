"""Test NamedTuple type checking - comprehensive tests for all features."""
import from typing { NamedTuple }

class ProcessedImports(NamedTuple) {
    has import_pieces: list[str],
        bundled_module_names: set[str];
}

class Point(NamedTuple) {
    has x: int,
        y: int;
}

class Person(NamedTuple) {
    has name: str,
        age: int,
        city: str = "Unknown";
}

# Test helper function that expects a Point
def process_point(p: Point) -> int {
    return p.x + p.y;
}

# Test helper function that expects tuple
def process_tuple(t: tuple) -> None {
    print(t);
}

with entry {
    # ==========================================================================
    # TEST 1: Constructor with positional arguments
    # ==========================================================================
    import_pieces: list[str] = ["a", "b"];
    bundled_module_names: set[str] = {"x", "y"};
    result = ProcessedImports(import_pieces, bundled_module_names);

    # With literals
    result2 = ProcessedImports(["c"], {"z"});

    # Simple NamedTuple
    p = Point(1, 2);

    # With default value - partial args
    person1 = Person("Alice", 30);
    # With default value - all args
    person2 = Person("Bob", 25, "NYC");

    # ==========================================================================
    # TEST 2: Field access - should return correct types
    # ==========================================================================
    x_val: int = p.x;
    y_val: int = p.y;
    name_val: str = person1.name;
    age_val: int = person1.age;
    pieces: list[str] = result.import_pieces;

    # ==========================================================================
    # TEST 3: Tuple unpacking
    # ==========================================================================
    (px, py) = p;
    (pname, page, pcity) = person2;

    # ==========================================================================
    # TEST 4: Indexing (inherited from tuple)
    # ==========================================================================
    first_elem = p[0];
    second_elem = p[1];

    # ==========================================================================
    # TEST 5: Iteration (inherited from tuple)
    # ==========================================================================
    for coord in p {
        print(coord);
    }

    # ==========================================================================
    # TEST 6: NamedTuple as function argument
    # ==========================================================================
    total = process_point(p);

    # ==========================================================================
    # TEST 7: NamedTuple is a tuple subtype
    # ==========================================================================
    process_tuple(p);

    # ==========================================================================
    # TEST 8: Special methods (_fields, _asdict, _replace, _make)
    # ==========================================================================
    fields = Point._fields;
    as_dict = p._asdict();
    replaced = p._replace();
    made = Point._make([7, 8]);

    # ==========================================================================
    # TEST 9: Comparison (inherited from tuple)
    # ==========================================================================
    p1 = Point(1, 2);
    p2 = Point(1, 2);
    p3 = Point(3, 4);
    is_equal: bool = p1 == p2;
    is_less: bool = p1 < p3;

    # Print to use variables and verify
    print(f"Point: ({x_val}, {y_val})");
    print(f"Person: {name_val}, age {age_val}, city {pcity}");
    print(f"Pieces: {pieces}");
    print(f"Unpacked: {px}, {py}, {pname}, {page}");
    print(f"Indexed: {first_elem}, {second_elem}");
    print(f"Total: {total}");
    print(f"Fields: {fields}");
    print(f"As dict: {as_dict}");
    print(f"Replaced: {replaced}");
    print(f"Made: {made}");
    print(f"Equal: {is_equal}, Less: {is_less}");
    print(result2);
}
