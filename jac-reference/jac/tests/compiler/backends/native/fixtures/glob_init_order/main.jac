"""A glob initializer reading another module's list glob across an import
cycle: `holder` imports `table`'s member list, and `table` imports a function
back from `holder`."""

import from holder { SPEC, COUNT, NAMES }
import from table { owner }

with entry {
    print(SPEC.name, COUNT, len(SPEC.offsets), owner());
    for (name, offset) in zip(NAMES, SPEC.offsets) {
        print(name, offset);
    }
}
