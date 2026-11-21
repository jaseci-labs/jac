"""A client component reaches `dedent` through a bare (Python-ecosystem)
import. The name resolves to no client-reachable module -- not a local Jac
module, not a declared or installed npm package, not a framework package --
so the PY requirement pins the import server-side, the ES backend prunes it
from the client bundle, and the browser would die with
`ReferenceError: dedent is not defined` -- previously with zero compile
diagnostics. Must be E5084 at compile time; server logic belongs behind a
`def:pub` endpoint. (Bare npm names like `react` resolve via the client
npm world and are not errors.)"""

import from textwrap { dedent }

def:pub Widget -> JsxElement {
    holder: any = dedent("  x  ");
    <div>{holder}</div>
}
