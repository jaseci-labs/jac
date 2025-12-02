"""You can import python modules freely."""

import random;
import from math { sqrt as square_root }  # list of as clauses comes at end
import datetime as dt;
import defs.mod_defs;  # includes are useful when brigning definitions into scope
import from defs.main_defs { jactastic }

with entry {  # code that executes on module load or script run
    random_number = random.randint(1, 10);
    print("Random number:", random_number);
    # or, f"Random Number: {random_number}" |> print;
    s_root = square_root(16);
    print("Square root:", s_root);
    # or, f"Square root: {s_root}" |> print;
    current_time = dt.datetime.now();
    print("Current time:", current_time);
    # or, f"Current time: {current_time}" |> print;
    jactastic.Jactastic() |> print;
}
