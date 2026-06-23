"""Re-exports the guarded provider via a MULTI-SEGMENT star import.

The star source `pkg.submod` is multi-segment (dotted), so it exercises the
`len(resolved) >= 2` path. On main this path appends an extension to an
already-extensioned file path (e.g. `.../submod.jac` -> `.../submod.jac.pyi`),
which never exists, so `Marker` fails to resolve.
"""

include pkg.submod;
