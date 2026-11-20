import from "lucide-react" {
    Home,
    Compass,
    Hash,
    User,
    Feather,
    LogOut,
    MoreHorizontal,
    BookOpen,
    Bot,
}

def:pub Sidebar(
    activeTab: str,
    displayUsername: str,
    profileUsername: str,
    profileAvatar: str,
    notifCount: int,
    onNavigate: Callable[[str], Coroutine[any, any, None]],
    onLogout: Callable[[], Coroutine[any, any, None]],
) -> JsxElement;
