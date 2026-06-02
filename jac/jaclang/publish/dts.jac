"""TypeScript declaration (.d.ts) generation for npm-published Jac modules.

Phase 3 promotes the Phase 1 JSDoc surface to real `.d.ts` files: exported
functions, archetypes (obj/node -> class), and globals get typed declarations,
reusing the same Jac->type-string mapping (`jac_type_to_ts`). Consumers then get
full IntelliSense and type-checking from a `types`-pointing package.json.
"""

import from jaclang.jac0core.unitree { Module }

"""Generate the `.d.ts` declaration text for a compiled module's exported
   functions, classes, and globals. Returns "" when nothing is exported."""
def dts_for_module(mod: Module) -> str;
