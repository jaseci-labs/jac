"""Mobile bottom navigation bar for Little X."""

import from "lucide-react" { Home, Compass, Hash, User }

def:pub MobileNav(
    activeTab: str, notifCount: int, onNavigate: Callable[[str], None]
) -> JsxElement {
    return
        <nav className="lx-mobile-nav">
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "feed" else ""
                )}
                onClick={lambda { onNavigate("feed"); }}
            >
                <Home size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "explore" else ""
                )}
                onClick={lambda { onNavigate("explore"); }}
            >
                <Compass size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "channels" else ""
                )}
                onClick={lambda { onNavigate("channels"); }}
            >
                <Hash size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "profile" else ""
                )}
                onClick={lambda { onNavigate("profile"); }}
            >
                <User size={24}/>
                {if notifCount > 0 {
                    <span className="lx-nav-badge">{str(notifCount)}</span>
                }}
            </div>
        </nav>;
}
