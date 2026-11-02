"""A shared library with an entry: `jac_main(argc, argv)` runs it with the host's argv."""
import sys;
import from .shared_main_helper { twice }

glob argc_seen: int = -1;

def:pub seen_argc -> int {
    return argc_seen;
}

def:pub doubled(x: int) -> int {
    return twice(x);
}

with entry {
    argc_seen = len(sys.argv);
}
