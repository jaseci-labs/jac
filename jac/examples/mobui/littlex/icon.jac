"""Icon set — WEB variant (Lucide via `lucide-react`, real DOM SVG).

The compiler picks `icon.native.jac` (which uses `lucide-react-native`) for
the react-native target instead of this file, so the same `<Icon name=.../>`
call renders crisp Lucide vector icons on both platforms. `lucide-react` renders
plain `<svg>` and needs no `react-native-svg`, so the web bundle stays clean.
"""

import from "lucide-react" {
    House,
    Search,
    Bell,
    User,
    Heart,
    MessageCircle,
    Repeat2,
    SquarePen,
    LogOut,
    Lock,
    AtSign,
    Star,
    Calendar,
    X,
    Send,
    Image as ImageIcon
}

# name → Lucide component. Same keys exist in icon.native.jac.
glob LUCIDE = {
         home: House,
         search: Search,
         bell: Bell,
         user: User,
         heart: Heart,
         comment: MessageCircle,
         repeat: Repeat2,
         edit: SquarePen,
         logout: LogOut,
         lock: Lock,
         at: AtSign,
         spark: Star,
         calendar: Calendar,
         close: X,
         send: Send,
         image: ImageIcon
     };

"""Render a Lucide icon by name. `fill` paints it solid in its own color
    (active like / brand mark); `width` is the stroke weight."""
def:pub Icon(name: str, size: int, color: str, fill: bool, width: float) -> JsxElement {
    Glyph = LUCIDE[name];
    return
        <Glyph
            size={size}
            color={color}
            fill={(color if fill else "none")}
            strokeWidth={width}
        />;
}
