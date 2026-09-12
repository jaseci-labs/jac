import copy;
import weakref;
import from jaclang.compiler.ir.base { UniNode }
import from jaclang.compiler.ir.identity { MutationPermit }
import from jaclang.compiler.ir.syntax.edges { Role, Kid }

def freeze_source(source: UniNode, permit: MutationPermit) {
    nodes = source._unclaimed_nodes(permit);
    for current in nodes {
        if isinstance(current, UniNode) {
            current._struct_frozen = True;
        }
        current.mutation_permit = permit;
    }
}

def copy_syntax_edges(source: UniNode, target: UniNode, memo: dict) {
    outgoing = source.__jac__.out_light;
    if not outgoing {
        return;
    }
    anchor = target.__jac__;
    anchor.out_light = {};
    back = weakref.ref(target);
    for (relation, children) in outgoing.items() {
        if relation is Kid or issubclass(relation, Role) {
            copied = [copy.deepcopy(child, memo) for child in children];
            anchor.out_light[relation] = copied;
            for child in copied {
                incoming = child.__jac__.in_light;
                if incoming is None {
                    incoming = {};
                    child.__jac__.in_light = incoming;
                }
                incoming.setdefault(relation, []).append(back);
            }
        }
    }
}
