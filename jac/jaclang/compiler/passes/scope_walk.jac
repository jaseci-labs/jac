import from jaclang.compiler.frontend.unitree { UniScopeNode }
import from jaclang.compiler.frontend.relations { ScopeChild }
import from jaclang.runtime.osp_kernel { osp_skip_rest }

walker ScopeWalker {
    has seen: set[int] = set();

    can walk_scope with UniScopeNode entry {
        if id(here) in self.seen {
            osp_skip_rest();
            return;
        }
        self.seen.add(id(here));
        visit:0: [here->:ScopeChild:->];
    }
}
