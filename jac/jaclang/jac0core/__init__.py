"""Pure-Python boot modules (the pre-.jac tier).

Everything that must import before any .jac module can load: the sealed
image reader (``sealed``), the cache path resolver (``cache_paths``), the
extension registry (``ext_registry``), and the kernel boot and its stage 0
(``stage0``). Every .jac module, the compiler's own included, is compiled by
the kernel; nothing here compiles Jac.
"""
