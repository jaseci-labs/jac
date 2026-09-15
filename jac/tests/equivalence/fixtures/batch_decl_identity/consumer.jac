"""Consumer mirroring operations.jac: relative type import + method-return flow."""

import from . { box as jbox }
import type from .evaluator { Evaluator }

def use(ev: Evaluator, flag: bool) -> jbox.Box | None {
    result = ev.produce(flag);
    if result {
        return result;
    }
    return None;
}
