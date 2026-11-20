"""Provider whose method return type is Box (absolute import path)."""

import from jaclang.compiler.tests.fixtures.batch_decl_identity.box { Box }

obj Evaluator {
    def produce(flag: bool) -> Box | None;
}
