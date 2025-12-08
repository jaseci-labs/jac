# top/sub_b/b_module.jac
# Import from sibling subpackage using parent-relative import
import from ..sub_a.a_module { A_VALUE, a_func }

glob B_VALUE = f"B uses {A_VALUE}";

def b_func -> str {
    return f"B calls: {a_func()}";
}
