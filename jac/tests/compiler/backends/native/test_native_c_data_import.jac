"""C data a module defines (an `import from c` glob with an initializer) is
imported by another module like any other data symbol: reads and writes on
either side reach the one C object."""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "c_data_import"
     );

test "an imported C data definition is the defining module's object" {
    out = assert_native_identity(os.path.join(FIXTURES, "main.jac"));
    assert out == "7 3 4\n18 40\n19\nTrue -1 2 1\n" , out;
}
