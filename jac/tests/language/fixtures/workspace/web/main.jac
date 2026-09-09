"""The web app: a client page over the shared Card component."""

import from core.helper { label }
import from core.ui.Card { Card }

def:pub app -> JsxElement {
    return <section><Card count={2}/><span>{label(2)}</span></section>;
}
