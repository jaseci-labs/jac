"""Fixture: a consumer reading an imported class's class-level constants.

Only the declaring module may define the constants' storage; a consumer that
defined them too would give the link two definitions of one symbol. The
consumer reads them through an instance and off the class, so both paths have
to reach the definer's globals.
"""

import from class_const_xmod_lib { Unit, Double }


def scaled_of(item: Unit) -> int {
    return item.scaled();
}


def run -> int {
    print(scaled_of(Unit(n=2)));
    print(scaled_of(Double(n=2)));
    print(Unit.SCALE);
    print(Double.TAG);
    return 0;
}


with entry {
    run();
}
