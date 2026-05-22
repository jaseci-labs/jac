"""Left navigation sidebar for Little X."""

import from "lucide-react" { Home, Compass, Hash, User, Feather, LogOut }

def:pub Sidebar(
    activeTab: str,
    displayUsername: str,
    profileUsername: str,
    profileAvatar: str,
    notifCount: int,
    onNavigate: any,
    onLogout: any,
) -> JsxElement {
    navFn = onNavigate;
    logoutFn = onLogout;

    return
        <aside className="lx-sidebar-left">
            <div className="lx-brand">
                <img
                    src="/static/assets/littlex-logo.svg"
                    className="lx-brand-logo"
                    alt="little-x"
                />
                <span className="lx-brand-name">LITTLE-X</span>
            </div>
            <nav className="lx-nav">
                <div
                    className={"lx-nav-item" + (
                        " lx-nav-item-active" if activeTab == "feed" else ""
                    )}
                    onClick={lambda { navFn.call(None, "feed"); }}
                >
                    <Home size={22}/>
                    <span>Home</span>
                </div>
                <div
                    className={"lx-nav-item" + (
                        " lx-nav-item-active" if activeTab == "explore" else ""
                    )}
                    onClick={lambda { navFn.call(None, "explore"); }}
                >
                    <Compass size={22}/>
                    <span>Explore</span>
                </div>
                <div
                    className={"lx-nav-item" + (
                        " lx-nav-item-active" if activeTab == "channels" else ""
                    )}
                    onClick={lambda { navFn.call(None, "channels"); }}
                >
                    <Hash size={22}/>
                    <span>Channels</span>
                </div>
                <div
                    className={"lx-nav-item" + (
                        " lx-nav-item-active" if activeTab == "profile" else ""
                    )}
                    onClick={lambda { navFn.call(None, "profile"); }}
                >
                    <User size={22}/>
                    <span>Profile</span>
                    {if notifCount > 0 {
                        <span className="lx-nav-badge">{str(notifCount)}</span>
                    }}
                </div>
            </nav>
            <button
                className="lx-compose-btn"
                onClick={lambda { navFn.call(None, "feed"); }}
            >
                <Feather size={18}/>
                <span>Post</span>
            </button>
            <div style={{"flex": "1"}}/>
            <div className="lx-sidebar-user">
                <img className="lx-avatar" src={profileAvatar} alt={profileUsername}/>
                <div className="lx-sidebar-user-info">
                    <div className="lx-sidebar-user-name">{displayUsername}</div>
                    <div className="lx-sidebar-user-handle">
                        {"@" + displayUsername}
                    </div>
                </div>
                <button
                    className="lx-logout-icon-btn"
                    onClick={lambda { logoutFn.call(None); }}
                >
                    <LogOut size={18}/>
                </button>
            </div>
        </aside>;
}
