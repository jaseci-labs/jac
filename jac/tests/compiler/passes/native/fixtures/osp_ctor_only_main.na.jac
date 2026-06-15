"""Issue #6683 fixture (entry half): a module that CONSTRUCTS an Object-Spatial
node (`Hub`) but uses NO OSP construct of its own -- no spawn / visit / connect
/ edge ref. The spawn happens entirely inside the imported `run_probe`.

Tag-table population is gated on a module actually USING OSP (so a construct-only
consumer skips the kernel, #6642 Blocker 2). Before #6683 that gate also dropped
the type-tag VALUE written into the node's reserved `__type_tag` field at
construction: this module left it 0. When `run_probe` then spawned on the node,
the kernel's `tag_of` read 0 and `node_desc(0)` returned a null descriptor,
aborting the walk -- `Aborted (core dumped)`. The construction site must write
the node's globally-stable tag regardless of whether the constructing module
itself uses OSP. The byte-identical program with the spawn moved into the entry
module always ran clean (that module uses OSP, so the tag was assigned).

Expected: prints `7`."""

import from osp_ctor_only_lib { Hub, run_probe }

with entry {
    h = Hub(tag=7);
    print(run_probe(h));
}
