"""Regression fixture (builder head half). Imports OSP archetypes from
`osp_xmod_annexbuild_lib` and declares `build` BODYLESS; the body — the only
place this module touches an OSP construct (`++>`) — lives in the impl annex
`osp_xmod_annexbuild_builder.na.impl.jac`. The whole point of the regression:
the OSP construct is contributed by the annex (spliced into the head's tree
with its own provenance), never written in the head file itself."""

import from osp_xmod_annexbuild_lib { Hub, Area }

def build(hub: Hub);
