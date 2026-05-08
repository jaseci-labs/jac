"""You can import python modules freely."""

import random;
import from math { sqrt as square_root }  # list of as clauses comes at end
import datetime as dt;
import defs.mod_defs;  # includes are useful when brigning definitions into scope
import from defs.main_defs { jactastic }

glob random_number = random.randint(1, 10);

with entry {
    print("Random number:", random_number);
}

# or, f"Random Number: {random_number}" |> print;
glob s_root = square_root(16);

with entry {
    print("Square root:", s_root);
}

# or, f"Square root: {s_root}" |> print;
glob current_time = dt.datetime.now();

with entry {
    print("Current time:", current_time);
    # or, f"Current time: {current_time}" |> print;
    jactastic.Jactastic() |> print;
}
# code that executes on module load or script run
