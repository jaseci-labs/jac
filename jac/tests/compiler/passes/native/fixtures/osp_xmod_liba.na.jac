"""Native OSP library A (issue #6642): a graph archetype set + a walker whose
ability navigates edges. Imported alongside osp_xmod_libb by osp_xmod_two to
exercise cross-module OSP spanning TWO independent libraries -- a configuration
globally-stable hash tags handle but position-based numbering could not."""

node Room { has tag: int = 0; }
edge Door { has w: int = 0; }

walker Scan {
    has total: int = 0;
    can at_room with Room entry {
        self.total += here.tag;
        visit [here ->:Door:->];
    }
}
