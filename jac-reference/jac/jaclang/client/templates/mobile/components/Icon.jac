"""Icons for {{name}} - WEB variant (Lucide via `lucide-react`).

The compiler picks `Icon.native.jac` for the react-native target and this
file otherwise. Both export the same `Icon` API, so screens never branch on
platform. Keep the `LUCIDE` keys identical in the two files.
"""

import from "lucide-react" { Check, Plus, Sparkles }

glob LUCIDE = {"check": Check, "plus": Plus, "sparkles": Sparkles};

def:pub Icon(name: str, size: int, color: str) -> JsxElement {
    Glyph = LUCIDE[name];
    <Glyph size={size} color={color}/>
}
