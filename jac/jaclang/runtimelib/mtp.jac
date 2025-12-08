"""Meaning Typed Programming constructs for Jac Language."""
import from __future__ { annotations }
import from collections.abc { Callable }
import from dataclasses { dataclass }
"""Meaning Typed Intermediate Representation."""
@dataclass(eq=False, repr=False)
class MTIR {
    with entry {
        let caller: Callable;
        let args: <>dict[((int | str), object)];
        let call_params: <>dict[(str, object)];
    }
}
