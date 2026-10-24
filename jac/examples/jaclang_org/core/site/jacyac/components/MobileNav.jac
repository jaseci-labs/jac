import from "lucide-react" { Home, Compass, Hash, User, BookOpen, Bot }

def:pub MobileNav(
    activeTab: str, notifCount: int, onNavigate: Callable[[str], None]
) -> JsxElement;
