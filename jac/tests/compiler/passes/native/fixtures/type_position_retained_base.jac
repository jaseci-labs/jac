"""A base the native lane keeps is a run-time dependency and still refuses.

Only a base the native lane *erases* is free: an ordinary Python base has to
be there for the archetype to mean what it says, and nothing in a native unit
can supply it. Waving this through would trade a clear refusal for a class
that silently loses everything it inherited.
"""

import threading;


obj Holder(threading.Event) {
    has n: int = 3;
}


def run -> int {
    return Holder(n=5).n;
}
