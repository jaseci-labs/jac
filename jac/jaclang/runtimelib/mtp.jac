"""Meaning Typed Programming constructs for Jac Language."""
import from collections.abc { Callable }
import from dataclasses { dataclass }
"""Meaning Typed Intermediate Representation."""
@dataclass(eq=False, repr=False)
class MTIR {
    with entry {
        caller: Callable;
        args: <>dict[((int | str), object)];
        call_params: <>dict[(str, object)];
    }
}
