"""An `as` cast names a type, so the module it comes from is not a run-time use.

The only mention of `threading` here is the type of a cast. A cast lowers to
its own operand natively -- the same erasure `typing.cast` gets -- so nothing
in the emitted unit reads the Python module, and the module-import gate must
not refuse it.
"""

import threading;


def run(payload: any) -> int {
    ev = payload as threading.Event;
    return 1 if ev is not None else 0;
}
