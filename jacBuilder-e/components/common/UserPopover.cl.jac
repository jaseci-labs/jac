"""UserPopover — avatar-triggered user menu with theme, settings, and sign out."""
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Settings01Icon, Logout01Icon, Sun03Icon, Moon02Icon, ComputerIcon, Tick02Icon
}
import from ..ui.popover { Popover, PopoverTrigger, PopoverContent }
import from ..ui.avatar { Avatar, AvatarFallback }
import from ..ui.separator { Separator }
import from ..ui.button { Button }
import from ...lib.utils { cn }

def:pub UserPopover(props: Any) -> Any {
    displayName = props.displayName or "User";
    initial = displayName.charAt(0).toUpperCase();
    themeState = props.themeState;
    onSettings = props.onSettings;
    onLogout = props.onLogout;
    version = props.version or "0.0.0";

    has open: bool = False;

    return <Popover open={open} onOpenChange={lambda v: Any { open = Boolean(v); }}>
        <PopoverTrigger asChild={True}>
            <button className="flex items-center gap-2.5 w-full px-3 py-2.5 rounded-lg hover:bg-accent transition-colors cursor-pointer text-left">
                <Avatar className="size-8">
                    <AvatarFallback className="bg-primary/20 text-primary text-sm font-medium">{initial}</AvatarFallback>
                </Avatar>
                <div className="flex-1 min-w-0">
                    <span className="text-sm font-medium text-foreground truncate block">{displayName}</span>
                    <span className="text-[11px] text-muted-foreground">{"v" + version}</span>
                </div>
            </button>
        </PopoverTrigger>
        <PopoverContent side="top" align="start" sideOffset={8} className="w-[240px] p-1.5">
            <div className="px-2.5 py-2">
                <span className="text-sm font-medium text-foreground block truncate">{displayName}</span>
            </div>
            <Separator className="my-1" />
            <div className="flex flex-col gap-0.5">
                <button
                    className="flex items-center gap-2 w-full px-2.5 py-1.5 rounded-md text-sm text-foreground hover:bg-accent transition-colors cursor-pointer text-left"
                    onClick={lambda {
                        open = False;
                        if onSettings { settingsFn = onSettings; settingsFn.call(None); }
                    }}
                >
                    <HugeiconsIcon icon={Settings01Icon} strokeWidth={2} className="size-4 text-muted-foreground" />
                    <span>{"Settings"}</span>
                </button>
            </div>
            <Separator className="my-1" />
            <div className="px-2.5 py-1">
                <span className="text-[11px] font-medium uppercase tracking-wider text-muted-foreground">{"Appearance"}</span>
            </div>
            <div className="flex flex-col gap-0.5">
                <button
                    className={cn("flex items-center gap-2 w-full px-2.5 py-1.5 rounded-md text-sm transition-colors cursor-pointer text-left", (themeState.theme == "system" and "bg-accent text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                    onClick={lambda { themeState.setTheme("system"); }}
                >
                    <HugeiconsIcon icon={ComputerIcon} strokeWidth={2} className="size-4" />
                    <span className="flex-1">{"System"}</span>
                    {themeState.theme == "system" and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3.5 text-primary" />}
                </button>
                <button
                    className={cn("flex items-center gap-2 w-full px-2.5 py-1.5 rounded-md text-sm transition-colors cursor-pointer text-left", (themeState.theme == "light" and "bg-accent text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                    onClick={lambda { themeState.setTheme("light"); }}
                >
                    <HugeiconsIcon icon={Sun03Icon} strokeWidth={2} className="size-4" />
                    <span className="flex-1">{"Light"}</span>
                    {themeState.theme == "light" and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3.5 text-primary" />}
                </button>
                <button
                    className={cn("flex items-center gap-2 w-full px-2.5 py-1.5 rounded-md text-sm transition-colors cursor-pointer text-left", (themeState.theme == "dark" and "bg-accent text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                    onClick={lambda { themeState.setTheme("dark"); }}
                >
                    <HugeiconsIcon icon={Moon02Icon} strokeWidth={2} className="size-4" />
                    <span className="flex-1">{"Dark"}</span>
                    {themeState.theme == "dark" and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3.5 text-primary" />}
                </button>
            </div>
            <Separator className="my-1" />
            <button
                className="flex items-center gap-2 w-full px-2.5 py-1.5 rounded-md text-sm text-destructive hover:bg-destructive/10 transition-colors cursor-pointer text-left"
                onClick={lambda {
                    open = False;
                    if onLogout { logoutFn = onLogout; logoutFn.call(None); }
                }}
            >
                <HugeiconsIcon icon={Logout01Icon} strokeWidth={2} className="size-4" />
                <span>{"Sign out"}</span>
            </button>
        </PopoverContent>
    </Popover>;
}
