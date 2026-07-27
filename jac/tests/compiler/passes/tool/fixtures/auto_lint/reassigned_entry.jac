"""A variable reassigned inside a with entry block must not be promoted.

The reassigned name is bound more than once, so it is a reassignment (a mutable
local), not a declaration. Promoting each binding to a global would emit
duplicate, conflicting declarations and misrepresent the code, so the whole
variable stays in the with entry block. A name bound exactly once is still
extracted.
"""

with entry {
    once = 5;
    count = 0;
    count = count + 1;
    count = count + 1;
}
