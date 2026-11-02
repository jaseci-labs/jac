"""X_VALUE must bind to private_glob_shared's public global, not to
private_glob_hidden's glob:priv of the same name, although hidden is imported
first. Expected probe: 2 * 10 + 1 = 21."""

import from private_glob_hidden { hidden_x }
import from private_glob_shared { X_VALUE }

def private_glob_probe -> int {
    return X_VALUE * 10 + hidden_x();
}
