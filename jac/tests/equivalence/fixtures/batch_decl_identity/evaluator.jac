"""Provider whose method return type is Box (absolute import path)."""

import from tests.equivalence.fixtures.batch_decl_identity.box { Box }

obj Evaluator {
    def produce(flag: bool) -> Box | None;
}
