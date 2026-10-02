"""A subclass an importer defines satisfies isinstance checks compiled in the
module that defines its base.

`isinstance(value, Base)` on an erased operand compared the object's vtable
against the candidate vtables its own module could see, so a `Child(Base)`
declared by an importer answered `False` natively and `True` on the Python
backend. A miss now asks the object's own ancestry: a headered build reads
the class name out of the allocation header and resolves it through the
class records every unit registers at initialization, and a headerless
(nogc) build reads the object's first word as a vtable once it is found in
the program's registered vtables. An unrelated object, flat or not, still
answers `False`.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURE = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "xmod_subclass_isinstance",
         "main.jac"
     );

test "importer subclasses answer isinstance checks compiled with their base" {
    out = assert_native_identity(FIXTURE);
    assert out.split("\n")
        == [
            "True False False",
            "True True False",
            "False False False",
            "False False True",
            "True False",
            "False True False",
            "True True False",
            ""
        ] , out;
}
