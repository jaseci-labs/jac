"""Regression fixture (builder head half). Imports OSP archetypes from
`osp_xmod_annexbuild_lib` and declares `build` BODYLESS; the body — the only
place this module touches an OSP construct (`++>`) — lives in the impl annex
`osp_xmod_annexbuild_builder.na.impl.jac`. The whole point of the regression:
the OSP construct is reachable only through `mod.impl_mod`, never the head
module's `kid` tree."""

import from osp_xmod_annexbuild_lib { Hub, Area }

def build(hub: Hub);
