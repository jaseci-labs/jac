"""The middle hop, in its own module, so its linearization is recorded there."""

import from .deep_chain_base { DeepBase }

obj DeepMid(DeepBase) {
    has slot_b: int = 0;
}
