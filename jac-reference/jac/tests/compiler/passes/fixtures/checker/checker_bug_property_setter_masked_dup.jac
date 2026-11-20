"""Regression fixture: a structural `.setter` decorator must not mask real dups.

The looser version of the E0076 fix skipped any method whose decorator matched
`@<anything>.setter` / `.getter` / `.deleter`, which silently swallowed real
duplicate-method bugs when the decorator target was not actually a property.
The strict fix only skips when the decorator's target Name was declared
`@property` in this class body, so the second `def foo` below must still raise
E0076.
"""

obj Container {
    def foo -> int {
        return 1;
    }

    @bar.setter
    def foo -> int {
        return 2;
    }
}
