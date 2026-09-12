# Statement-dispatch registry breaking the codegen<->sibling import cycles.
#
# visit_stmt (compiler_codegen) lowers compound statements through handler
# slots in this dict instead of importing the split-out sibling modules
# directly: those siblings import shared lowering helpers (visit_stmts,
# emit_name_store, ...) FROM compiler_codegen, so any static edge in either
# direction would close an import cycle. Each sibling wires its visitors at
# import time in a `with entry` block (see _csvmodule.jac's
# register_module_exception for the same idiom); entry drivers
# (product_compile, compiler_slice) import the siblings so registration
# always precedes the first compile. An unwired slot fails loudly (call
# through None) rather than silently skipping a statement kind.
#
# A dict holder rather than per-slot scalar globs -- a glob rebound inside a
# function is scoped local and never persists; item assignment mutates the
# holder in place so imported references observe the registration.
glob stmt_handlers: dict[str, any] = {};
