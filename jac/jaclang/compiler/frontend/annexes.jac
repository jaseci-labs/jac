import from jaclang.compiler.ir.schema { Module }
import from jaclang.compiler.ir.syntax.edges { BodyRole }

def merge_annex_into(nd: Module, annex_mod: Module) -> None {
    stmts = list(annex_mod.body);
    if not stmts {
        return;
    }
    nd.add_kids_right(stmts, pos_update=False, parent_update=True, role=BodyRole);
    for sub in annex_mod._in_mod_nodes {
        if sub is not annex_mod {
            nd._in_mod_nodes.append(sub);
        }
    }
}
