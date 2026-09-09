"""Entry module whose only server endpoint is reached through the client's
bridged import of a server module that crashes at import time (#6507 fail-loud).
"""

import from .failload_frontend { Panel as ClientPanel }

def:pub app -> JsxElement {
    <ClientPanel/>
}
