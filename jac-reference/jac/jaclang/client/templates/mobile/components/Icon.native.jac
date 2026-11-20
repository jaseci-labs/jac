"""Icons for {{name}} - NATIVE variant (Lucide via `lucide-react-native`).

The compiler picks this file over `Icon.jac` for the react-native target.
`lucide-react-native` renders through `react-native-svg`, which Metro bundles
on native. Same `Icon` API; keep the `LUCIDE` keys identical in the two files.
"""

import from "lucide-react-native" { Check, Plus, Sparkles }

glob LUCIDE = {"check": Check, "plus": Plus, "sparkles": Sparkles};

def:pub Icon(name: str, size: int, color: str) -> JsxElement {
    Glyph = LUCIDE[name];
    <Glyph size={size} color={color}/>
}
