"""Per-target entry-script generators for jac-client.

Each generator in this package contributes a `_entry.js` body for one client
target (web, native, ...). jac-client registers them explicitly during
target bootstrap via `jaclang.runtimelib.entry_generators`.
"""
