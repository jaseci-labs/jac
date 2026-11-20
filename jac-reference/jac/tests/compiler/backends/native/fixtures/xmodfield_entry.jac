# Entry module for the cross-module obj-field walk-order gate (#7871 F).
# Importing only the middle module makes the native pass discover modules in
# the order [xmodfield_mid, xmodfield_far]: the module whose obj field is
# typed Point is walked before the module defining Point.

import from xmodfield_mid { wrapper_checksum }

def imported_field_checksum -> int {
    return wrapper_checksum();
}

glob _x: int = 1;
