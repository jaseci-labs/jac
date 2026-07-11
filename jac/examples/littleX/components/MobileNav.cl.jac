"""Mobile bottom navigation bar for Little X."""

import from "lucide-react" { Home, Compass, Hash, User }
import from ..lib.utils { cn }

def:pub MobileNav(
    activeTab: str, notifCount: int, onNavigate: Callable[[str], None]
) -> JsxElement {
    item = "flex flex-1 items-center justify-center py-3 transition-colors";
    return
        <nav
            className="fixed inset-x-0 bottom-0 z-40 flex border-t border-border bg-background/80 backdrop-blur-lg md:hidden"
        >
            <button
                className={cn(
                    item,
                    "text-primary" if activeTab == "feed" else "text-muted-foreground"
                )}
                onClick={lambda { onNavigate("feed"); }}
            >
                <Home size={24}/>
            </button>
            <button
                className={cn(
                    item,
                    "text-primary"
                        if activeTab == "explore"
                        else "text-muted-foreground"
                )}
                onClick={lambda { onNavigate("explore"); }}
            >
                <Compass size={24}/>
            </button>
            <button
                className={cn(
                    item,
                    "text-primary"
                        if activeTab == "channels"
                        else "text-muted-foreground"
                )}
                onClick={lambda { onNavigate("channels"); }}
            >
                <Hash size={24}/>
            </button>
            <button
                className={cn(
                    item,
                    "relative text-primary"
                        if activeTab == "profile"
                        else "relative text-muted-foreground"
                )}
                onClick={lambda { onNavigate("profile"); }}
            >
                <User size={24}/>
                {if notifCount > 0 {
                    <span
                        className="absolute right-[28%] top-2 flex size-4 items-center justify-center rounded-full bg-primary text-[0.6rem] font-bold text-primary-foreground"
                    >
                        {str(notifCount)}
                    </span>
                }}
            </button>
        </nav>;
}
