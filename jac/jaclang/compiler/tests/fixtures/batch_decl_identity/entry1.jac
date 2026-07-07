"""First batch entry; loads evaluator + box as dependencies."""

import type from jaclang.compiler.tests.fixtures.batch_decl_identity.evaluator {
    Evaluator
}

def kick(ev: Evaluator, flag: bool) {
    ev.produce(flag);
}
