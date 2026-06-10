"""Left navigation sidebar for Little X."""

import from "lucide-react" {
    Home,
    Compass,
    Hash,
    User,
    Feather,
    LogOut,
    MoreHorizontal
}
import from .ui.button { Button }
import from .ui.avatar { Avatar, AvatarImage, AvatarFallback }
import from .ui.badge { Badge }
import from .ui.dropdown_menu {
    DropdownMenu,
    DropdownMenuTrigger,
    DropdownMenuContent,
    DropdownMenuGroup,
    DropdownMenuItem
}
import from ..lib.utils { cn }

def:pub Sidebar(
    activeTab: str,
    displayUsername: str,
    profileUsername: str,
    profileAvatar: str,
    notifCount: int,
    onNavigate: Callable[[str], None],
    onLogout: Callable[[], None],
) -> JsxElement {
    nav_base = "h-12 w-full justify-start gap-4 rounded-full px-4 text-lg font-medium";
    initial = displayUsername[0].upper() if displayUsername else "?";

    return
        <aside
            className="sticky top-0 hidden h-screen w-20 shrink-0 flex-col gap-1 border-r border-border px-2 py-4 md:flex xl:w-64 xl:px-3"
        >
            <div className="mb-2 flex items-center gap-2 px-2 xl:px-3">
                <img
                    src="/static/assets/littlex-logo.svg"
                    className="size-9"
                    alt="little-x"
                />
                <span
                    className="hidden font-display text-xl font-black tracking-tight text-primary xl:inline"
                >
                    LITTLE-X
                </span>
            </div>
            <nav className="flex flex-col gap-1">
                <Button
                    variant="ghost"
                    className={cn(
                        nav_base,
                        "text-primary bg-primary/10"
                            if activeTab == "feed"
                            else "text-foreground"
                    )}
                    onClick={lambda { onNavigate("feed"); }}
                >
                    <Home size={24}/>
                    <span className="hidden xl:inline">Home</span>
                </Button>
                <Button
                    variant="ghost"
                    className={cn(
                        nav_base,
                        "text-primary bg-primary/10"
                            if activeTab == "explore"
                            else "text-foreground"
                    )}
                    onClick={lambda { onNavigate("explore"); }}
                >
                    <Compass size={24}/>
                    <span className="hidden xl:inline">Explore</span>
                </Button>
                <Button
                    variant="ghost"
                    className={cn(
                        nav_base,
                        "text-primary bg-primary/10"
                            if activeTab == "channels"
                            else "text-foreground"
                    )}
                    onClick={lambda { onNavigate("channels"); }}
                >
                    <Hash size={24}/>
                    <span className="hidden xl:inline">Channels</span>
                </Button>
                <Button
                    variant="ghost"
                    className={cn(
                        nav_base,
                        "relative text-primary bg-primary/10"
                            if activeTab == "profile"
                            else "relative text-foreground"
                    )}
                    onClick={lambda { onNavigate("profile"); }}
                >
                    <User size={24}/>
                    <span className="hidden xl:inline">Profile</span>
                    {if notifCount > 0 {
                        <Badge
                            className="absolute left-7 top-1.5 size-5 justify-center p-0 text-[0.65rem] xl:left-auto xl:right-4"
                        >
                            {str(notifCount)}
                        </Badge>
                    }}
                </Button>
            </nav>
            <Button
                className="mt-3 h-12 w-12 rounded-full font-semibold shadow-lg shadow-primary/20 xl:w-full"
                onClick={lambda { onNavigate("feed"); }}
            >
                <Feather size={20}/>
                <span className="hidden xl:inline">Post</span>
            </Button>
            <div className="flex-1"/>
            <DropdownMenu>
                <DropdownMenuTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        className="h-auto w-full justify-start gap-2 rounded-full p-2"
                    >
                        <Avatar className="size-9 shrink-0">
                            <AvatarImage src={profileAvatar} alt={profileUsername}/>
                            <AvatarFallback>{initial}</AvatarFallback>
                        </Avatar>
                        <div className="hidden min-w-0 flex-1 text-left xl:block">
                            <div
                                className="truncate text-sm font-semibold text-foreground"
                            >
                                {displayUsername}
                            </div>
                            <div className="truncate text-xs text-muted-foreground">
                                {"@" + displayUsername}
                            </div>
                        </div>
                        <MoreHorizontal
                            size={18}
                            className="hidden shrink-0 text-muted-foreground xl:block"
                        />
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-56">
                    <DropdownMenuGroup>
                        <DropdownMenuItem
                            variant="destructive"
                            onClick={lambda { onLogout(); }}
                        >
                            <LogOut size={15}/>
                            Log out @
                            {displayUsername}
                        </DropdownMenuItem>
                    </DropdownMenuGroup>
                </DropdownMenuContent>
            </DropdownMenu>
        </aside>;
}
