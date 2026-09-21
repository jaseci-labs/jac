import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.constant { ExprCtx }
import from jaclang.compiler.frontend.roles { Kid, ValueRole }

walker ReactiveUseWalker {
    has reactive: set[str],
        writes: list[tuple[int, int, str]] = [],
        reads: list[tuple[int, int, str, uni.Name]] = [];

    can walk_children with uni.UniNode entry {
        if isinstance(
            here, (uni.Assignment, uni.Name, uni.LambdaExpr, uni.Ability, uni.Archetype)
        ) {
            return;
        }
        visit:0: [here->:Kid:->];
    }

    can collect_assignment with uni.Assignment entry {
        if len(here.target) == 1
            and isinstance(here.target[0], uni.Name)
            and here.target[0].sym_name in self.reactive {
            target = here.target[0];
            self.writes.append(
                (target.loc.first_line, target.loc.col_start, target.sym_name)
            );
        }
        visit:0: [here->:ValueRole:->];
    }

    can collect_name with uni.Name entry {
        if here.value in self.reactive and here.expr_ctx == ExprCtx.LOAD {
            parent = here.parent;
            if not (isinstance(parent, uni.AtomTrailer) and parent.is_attr) {
                self.reads.append(
                    (here.loc.first_line, here.loc.col_start, here.value, here)
                );
            }
        }
    }
}
