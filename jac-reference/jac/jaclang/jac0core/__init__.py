"""Pure-Python boot modules (the pre-.jac tier).

Everything that must import before any .jac module can load: the sealed
image reader (``sealed``), the cache path resolver (``cache_paths``),
and the extension registry (``ext_registry``). The .jac seed set that
used to live here moved to function-named homes (compiler/, runtime/,
lib/, ...) with membership declared in ``jaclang/bootstrap_manifest.py``
(#8681); this package's own move to ``bootstrap/`` completes that.
"""
