"""Icon set — NATIVE variant (Lucide via `lucide-react-native`, real RN SVG).

The compiler picks this file over `icon.cl.jac` for the react-native target.
`lucide-react-native` peer-depends on `react-native-svg`, which Metro bundles
correctly on native (the incompatibility is only with the web/Vite pipeline —
which never sees this file, since web uses `icon.cl.jac`). Same `<Icon/>` API.
"""

cl {
    import from "lucide-react-native" {
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

    # name → Lucide component. Same keys exist in icon.cl.jac.
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
    def:pub Icon(
        name: str, size: int, color: str, fill: bool, width: float
    ) -> JsxElement {
        Glyph = LUCIDE[name];
        return
            <Glyph
                size={size}
                color={color}
                fill={(color if fill else "none")}
                strokeWidth={width}
            />;
    }
}
