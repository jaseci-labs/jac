import from ..sub_a.a_module { A_VALUE, a_func }

glob B_VALUE = f"B uses {A_VALUE}";

def b_func -> str {
    return f"B calls: {a_func()}";
}
