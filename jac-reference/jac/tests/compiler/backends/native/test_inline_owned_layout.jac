import os;
import from tests.support { TESTS_DIR, assert_native_identity }

test "imported owned fields and inline swaps agree across backends" {
    source = os.path.join(
        TESTS_DIR, "compiler", "backends", "native", "fixtures", "inline_owned_use.jac"
    );
    assert assert_native_identity(source) == "34 12 95\nreleased\n";
}
