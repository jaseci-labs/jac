"""Icon set — NATIVE variant (Lucide via `lucide-react-native`, real RN SVG).

The compiler picks this file over `icon.cl.jac` for the react-native target.
`lucide-react-native` peer-depends on `react-native-svg`, which Metro bundles
correctly on native (the incompatibility is only with the web/Vite pipeline —
which never sees this file, since web uses `icon.cl.jac`). Same `<Icon/>` API.
"""

cl {
    import from "lucide-react-native" {
        Hammer,
        FolderGit2,
        Compass,
        Activity,
        User,
        Plus,
        Rocket,
        Play,
        Square,
        RotateCw,
        FileCode,
        Terminal,
        ChevronRight,
        ChevronLeft,
        Check,
        X,
        Lock,
        AtSign,
        Search,
        Server,
        Clock,
        Star,
        Download,
        GitBranch,
        Circle,
        LogOut,
        Sparkles,
        Bell,
        Settings,
        Zap,
        Box,
        Send,
        Image as ImageIcon,
        MoreHorizontal,
        Mic,
        ArrowDownUp,
        Smartphone,
        Palette,
        FolderOpen,
        Pencil
    }

    # name → Lucide component. Same keys exist in icon.cl.jac.
    glob LUCIDE = {
             hammer: Hammer,
             projects: FolderGit2,
             community: Compass,
             activity: Activity,
             user: User,
             plus: Plus,
             rocket: Rocket,
             play: Play,
             stop: Square,
             restart: RotateCw,
             file: FileCode,
             edit: Pencil,
             terminal: Terminal,
             chevron: ChevronRight,
             back: ChevronLeft,
             check: Check,
             close: X,
             lock: Lock,
             at: AtSign,
             search: Search,
             server: Server,
             clock: Clock,
             star: Star,
             clone: Download,
             branch: GitBranch,
             dot: Circle,
             logout: LogOut,
             spark: Sparkles,
             bell: Bell,
             settings: Settings,
             zap: Zap,
             box: Box,
             send: Send,
             image: ImageIcon,
             dots: MoreHorizontal,
             mic: Mic,
             sort: ArrowDownUp,
             phone: Smartphone,
             palette: Palette,
             folder: FolderOpen
         };

    # Render a Lucide icon by name. `fill` paints it solid in its own color
    # (an active/selected state); `width` is the stroke weight.
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
