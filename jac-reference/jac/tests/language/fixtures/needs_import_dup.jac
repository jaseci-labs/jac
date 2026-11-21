"""Test of jac importing python."""
import os;
import tests.language.fixtures.pyfunc as pyfunc;
import random;
import from tests.language.fixtures.pyfunc { my_print }

with entry {
    pyfunc.__name__ = "pyfunc";
    pyfunc.__spec__ = None;
    my_print(pyfunc);
    print(random.random());
}

import tests.language.fixtures.circle_pysolo;
import from tests.language.fixtures.circle_pysolo { calculate_area }

with entry {
    print(f"are {calculate_area(2.0)}");
}
