"""Regression fixture (entry half). Builds the graph through the imported
`build` (whose body is an impl annex that wires imported OSP nodes), then spawns
`Pass` in THIS module. Prints `before after seen`; the fix prints `2 2 3` (graph
built, walker sums area tags 1+2). Before the fix the builder module failed to
compile (E5090 on the annexed `++>`) / mis-codegen."""

import from osp_xmod_annexbuild_lib { Hub, Area, Pass }
import from osp_xmod_annexbuild_builder { build }

with entry {
    hub = Hub();
    build(hub);
    before = len([hub -->[?:Area]]);
    w = hub spawn Pass();
    after = len([hub -->[?:Area]]);
    print(before, after, w.seen);
}
