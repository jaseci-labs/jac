"""Template-style relative import: `...lib.utils` resolves only after the
component is vendored into a project (`jac add` scaffolds lib/utils.jac),
exactly like the shadcn registry components checked in-repo. A relative
bare import is never an npm package or an installed Python module, so
E5084 must stay silent even though the target is unresolvable here."""

import from ...lib.utils { cn }

def:pub Widget -> JsxElement {
    <div className={cn("a", "b")}>ok</div>
}
