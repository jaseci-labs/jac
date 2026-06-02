"""JSDoc generation from typed Jac signatures for `jac bundle --target npm`.

Phase 1 ships JSDoc-annotated JavaScript so TypeScript/IDE consumers get type
information without a full `.d.ts` emitter (that is Phase 3). The Jac->JSDoc
type mapping here is the same surface a later declaration pass will reuse.
"""

import from jaclang.jac0core.unitree { Module }

"""Map a Jac type expression string to a JSDoc/TypeScript type string.

   Scalars map to JS primitives (int/float->number, str->string, bool->boolean);
   containers map structurally (list[X]->Array<X>, dict[K,V]->Object<K,V>);
   unions map to `(A|B)`; unknown identifiers (custom classes) pass through.
   `is_return` lets a bare `None` map to `void` instead of `null`."""
def jac_type_to_jsdoc(type_str: str, is_return: bool = False) -> str;

"""Map a Jac type expression string to an idiomatic TypeScript type string.

   Same structural mapping as jac_type_to_jsdoc, but emits TS spellings:
   `any` (not `*`) and `Record<K, V>` (not `Object<K, V>`)."""
def jac_type_to_ts(type_str: str, is_return: bool = False) -> str;

"""Build a JSDoc comment block (the `/** ... */` text, no trailing newline) for
   every top-level function in a compiled module, keyed by function name."""
def jsdoc_for_module(mod: Module) -> dict[str, str];

"""Insert each JSDoc block immediately before its matching `function`/`class`
   declaration in the JavaScript source, preserving the declaration's
   indentation. Names absent from the JS are skipped."""
def inject_jsdoc(js: str, blocks: dict[str, str]) -> str;
