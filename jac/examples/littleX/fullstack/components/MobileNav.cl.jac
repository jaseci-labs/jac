"""Mobile bottom navigation bar for Little X."""

import from "lucide-react" { Home, Compass, Hash, User }

def:pub MobileNav(activeTab: str, notifCount: int, onNavigate: any) -> JsxElement {
    navFn = onNavigate;

    return
        <nav className="lx-mobile-nav">
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "feed" else ""
                )}
                onClick={lambda { navFn.call(None, "feed"); }}
            >
                <Home size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "explore" else ""
                )}
                onClick={lambda { navFn.call(None, "explore"); }}
            >
                <Compass size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "channels" else ""
                )}
                onClick={lambda { navFn.call(None, "channels"); }}
            >
                <Hash size={24}/>
            </div>
            <div
                className={"lx-mobile-nav-item" + (
                    " lx-mobile-nav-item-active" if activeTab == "profile" else ""
                )}
                onClick={lambda { navFn.call(None, "profile"); }}
            >
                <User size={24}/>
                {if notifCount > 0 {
                    <span className="lx-nav-badge">{str(notifCount)}</span>
                }}
            </div>
        </nav>;
}
