"""Entry module whose only server endpoint is reached through the client's
`sv import` from a server module that crashes at import time (#6507 fail-loud).
"""

to cl:

import from .failload_frontend { Panel as ClientPanel }

def:pub app -> JsxElement {
    return
        <ClientPanel/>;
}
