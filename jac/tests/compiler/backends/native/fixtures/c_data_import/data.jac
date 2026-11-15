"""C data definitions (globs with initializers in an `import from c` block)
that another module imports."""

import from c {
    obj Pair {
        has left: i32 = 0,
            right: i32 = 0;
    }
    glob counter: i32 = 7,
         pair: Pair = Pair(left=3, right=4);
}

# Flags defined together, one negative.
import from c {
    glob works: i32 = -1,
         enabled: i32 = 1;
}

def bump {
    counter = counter + 1;
}
