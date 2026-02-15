"""Abstract class for IR Passes for Jac."""
import from threading { Event }
import from typing { TYPE_CHECKING, TypeVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

glob T = TypeVar('T', bound=uni.UniNode);
"""Abstract class for IR passes."""
class UniPass(Transform[(uni.Module, uni.Module)]) {
    """Initialize parser."""
    def init(
        self: UniPass,
        ir_in: uni.Module,
        prog: JacProgram,
        cancel_token: (Event | None) = None
    ) -> None {
        self.term_signal = False;
        self.prune_signal = False;
        Transform.init(self, ir_in, prog, cancel_token=cancel_token);
    }

    """Run once before pass."""
    def before_pass(self: UniPass) -> None { }

    """Run once after pass."""
    def after_pass(self: UniPass) -> None { }

    """Run on entering node."""
    def enter_node(self: UniPass, nd: uni.UniNode) -> None {
        import from jaclang.jac0core.helpers { pascal_to_snake }
        if hasattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}") {
            getattr(self, f"enter_{pascal_to_snake(type(nd).__name__)}")(nd);
        }
    }

    """Run on exiting node."""
    def exit_node(self: UniPass, nd: uni.UniNode) -> None {
        import from jaclang.jac0core.helpers { pascal_to_snake }
        if hasattr(self, f"exit_{pascal_to_snake(type(nd).__name__)}") {
            getattr(self, f"exit_{pascal_to_snake(type(nd).__name__)}")(nd);
        }
    }

    """Prune traversal."""
    def prune(self: UniPass) -> None {
        self.prune_signal = True;
    }

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
                raise ValueError("Node has no sub_node_tab. " + str(nd)) ;
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
    def recalculate_parents(self: UniPass, nd: uni.UniNode) -> None {
        if not nd {
            return;
        }
        for i in nd.kid {
            if i {
                i.parent = nd;
                self.recalculate_parents(i);
            }
        }
    }

    """Run pass."""
    def transform(self: UniPass, ir_in: uni.Module) -> uni.Module {
        self.ir_out = ir_in;
        if not isinstance(ir_in, uni.UniNode) {
            return ir_in;
        }
        self.before_pass();
        if not isinstance(ir_in, uni.UniNode) {
            raise ValueError('Current node is not an UniNode.') ;
        }
        self.traverse(ir_in);
        self.after_pass();
        return self.ir_in;
    }

    """Traverse tree."""
    def traverse(self: UniPass, nd: uni.UniNode) -> uni.UniNode {
        if self.is_canceled() {
            return nd;
        }
        self.cur_node = nd;
        self.enter_node(nd);
        if not self.prune_signal {
            for i in nd.kid {
                if i {
                    self.traverse(i);
                }
            }
        } else {
            self.prune_signal = False;
        }
        self.cur_node = nd;
        if self.is_canceled() {
            return nd;
        }
        self.exit_node(nd);
        return nd;
    }
}
