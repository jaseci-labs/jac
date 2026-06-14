"""Regression fixture (entry half): builds the graph through an IMPORTED
function (`build`, in `osp_xmod_buildsplit_lib`) then spawns a walker in THIS
module. The build module and the spawn module differ, so the spawn module's
first `__osp_ensure_init` is what used to re-run the shared kernel glob-init and
wipe the adjacency. Prints `before after seen`; the bug printed `2 0 0`, the
fix prints `2 2 3` (graph survives, walker sums area tags 1+2)."""

import from osp_xmod_buildsplit_lib { Hub, Area, Pass, build }

with entry {
    hub = Hub();
    build(hub);
    before = len([hub -->[?:Area]]);
    w = hub spawn Pass();
    after = len([hub -->[?:Area]]);
    print(before, after, w.seen);
}
