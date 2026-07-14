"""Regression fixture (imported half): the graph is BUILT here (`build`) but
SPAWNED in the importing module. Before the fix, the importer's first `spawn`
re-ran the SHARED OSP kernel glob-init (`__jac_glob_init_osp_kernel`) through
its per-module `__osp_ensure_init` guard, re-initializing the link-merged
adjacency singletons (`_e_src` = []) and wiping the graph this module had
populated -- so the edge ref collapsed to empty after a single spawn. The
kernel glob-init must run exactly ONCE program-wide. Expected: 2 2 3."""

node Hub {}
node Area { has tag: int = 0; }

walker Pass {
    has seen: int = 0;

    can start with Hub entry {
        visit [here -->[?:Area]];
    }

    can at_area with Area entry {
        self.seen += here.tag;
    }
}

def build(hub: Hub) {
    hub ++> Area(tag=1);
    hub ++> Area(tag=2);
}
