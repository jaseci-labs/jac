import from "lucide-react" {
    House,
    Compass,
    Hash,
    User,
    Heart,
    MessageCircle,
    Trash2,
    Send,
    LogOut,
    Lock,
    AtSign,
    Search,
    Plus,
    ArrowLeft,
    Users,
    X,
    Pencil,
    Feather,
    TrendingUp,
    WifiOff,
    RefreshCw,
    Check,
    Inbox
}

glob LUCIDE: dict[str, any] = {
         "home": House,
         "explore": Compass,
         "hash": Hash,
         "user": User,
         "heart": Heart,
         "comment": MessageCircle,
         "trash": Trash2,
         "send": Send,
         "logout": LogOut,
         "lock": Lock,
         "at": AtSign,
         "search": Search,
         "plus": Plus,
         "back": ArrowLeft,
         "users": Users,
         "close": X,
         "edit": Pencil,
         "feather": Feather,
         "trending": TrendingUp,
         "offline": WifiOff,
         "refresh": RefreshCw,
         "check": Check,
         "inbox": Inbox
     };

def:pub Icon(name: str, size: int, color: str, fill: bool = False) -> JsxElement {
    Glyph = LUCIDE[name];
    <Glyph size={size} color={color} fill={color if fill else "none"} strokeWidth={2}/>
}
