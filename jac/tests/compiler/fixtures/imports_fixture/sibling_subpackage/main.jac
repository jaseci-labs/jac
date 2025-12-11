import from top.sub_a.a_module { A_VALUE, a_func }
import from top.sub_b.b_module { B_VALUE, b_func }

with entry {
    print(f"Sibling subpkg - A_VALUE: {A_VALUE}");
    print(f"Sibling subpkg - a_func(): {a_func()}");
    print(f"Sibling subpkg - B_VALUE: {B_VALUE}");
    print(f"Sibling subpkg - b_func(): {b_func()}");
}
