"""Test combining consecutive glob statements.

Consecutive glob statements with the same modifiers (access, frozen)
should be combined into a single glob statement with comma-separated assignments.
"""

# Consecutive glob statements with no modifiers - should be combined
glob x = 1;
glob y = 2;
glob z = 3;

# Public glob statements - should be combined separately
glob : pub a = 10;
glob : pub b = 20;

# Protected glob statements - should be combined separately
glob : protect c = 100;
glob : protect d = 200;
glob : protect e = 300;

# Mixed modifiers should NOT be combined together
glob m1 = 1;
glob : pub m2 = 2;
glob : protect m3 = 3;

# Non-consecutive globs should NOT be combined
glob before = 0;
def helper -> int {
    return 42;
}

glob after = 99;
