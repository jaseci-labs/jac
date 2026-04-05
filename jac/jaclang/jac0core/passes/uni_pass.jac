"""Abstract class for IR Passes for Jac."""
import from threading { Event }
import from typing { TYPE_CHECKING, TypeVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

glob T = TypeVar('T', bound=uni.UniNode);
"""Abstract class for IR passes."""
obj UniPass(ModuleCodegenPass) {
    has term_signal: bool = False,
        prune_signal: bool = False;

    """Initialize parser."""
    def postinit -> None;

    """Run once before pass."""
    def before_pass -> None;

    """Run once after pass."""
    def after_pass -> None;

    """Run on entering node."""
    def enter_node(nd: uni.UniNode) -> None;

    """Run on exiting node."""
    def exit_node(nd: uni.UniNode) -> None;

    """Prune traversal."""
    def prune -> None;

    """Get all sub nodes of type."""
    static def get_all_sub_nodes(
        nd: uni.UniNode, typ: type[T], brute_force: bool = False
    ) -> list[T] {
        result: list[T] = [];
        if not nd {
            return result;
        } elif len(nd._sub_node_tab) {
            if (typ in nd._sub_node_tab) {
                for i in nd._sub_node_tab[typ] {
                    if isinstance(i, typ) {
                        result.append(i);
                    }
                }
            }
        } elif len(nd.kid) {
            if not brute_force {
                raise ValueError("Node has no sub_node_tab. " + str(nd));
            } else {
                for i in nd.kid {
                    if isinstance(i, typ) {
                        result.append(i);
                    }
                    result.extend(UniPass.get_all_sub_nodes(i, typ, brute_force));
                }
            }
        }
        return result;
    }

    """Check if node has parent of type."""
    static def find_parent_of_type(nd: uni.UniNode, typ: type[T]) -> (T | None) {
        while nd.parent {
            if isinstance(nd.parent, typ) {
                return nd.parent;
            }
            nd = nd.parent;
        }
        return None;
    }

    """Check if node has parent of type."""
    static def has_parent_of_node(nd: uni.UniNode, parent: uni.UniNode) -> bool {
        while nd.parent {
            if (nd.parent == parent) {
                return True;
            }
            nd = nd.parent;
        }
        return False;
    }

    """Recalculate parents."""
    def recalculate_parents(nd: uni.UniNode) -> None;

    """Run pass."""
    def transform(ir_in: uni.Module) -> uni.Module;

    """Traverse tree."""
    def traverse(nd: uni.UniNode) -> uni.UniNode;
}
