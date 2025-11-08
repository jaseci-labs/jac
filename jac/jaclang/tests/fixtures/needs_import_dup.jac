"""Test of jac importing python."""
import os;
import pyfunc;
import random;
import from pyfunc { my_print }

with entry {

    my_print(pyfunc);
    print(random.random());
}

import circle_pysolo;
import from circle_pysolo { calculate_area }

with entry {
    print(f"are {calculate_area(2.0)}");
}
