import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    CodesandboxIcon, GitBranchIcon, PlayIcon,
    Message01Icon, Settings01Icon, PackageIcon, DownloadSquare02Icon
}

def:pub ActivityBar(props: Any) -> Any {
    activeView = props.activeView or "files";
    onViewChange = props.onViewChange;
    previewStatus = props.previewStatus or "stopped";
    gitChangedCount = props.gitChangedCount or 0;
    sidebarCollapsed = props.sidebarCollapsed or False;

    isRunning = previewStatus == "running" or previewStatus == "starting";

    def handleClick(viewId: str) -> None {
        handler = onViewChange;
        handler.call(None, viewId);
    }

    topItems = [
        {"id": "files", "icon": CodesandboxIcon, "label": "Explorer", "shortcut": "Ctrl+Shift+E"},
        {"id": "git", "icon": GitBranchIcon, "label": "Source Control", "shortcut": "Ctrl+Shift+G"},
        {"id": "run", "icon": PlayIcon, "label": "Run & Preview", "shortcut": "Ctrl+Shift+D"},
        {"id": "chat", "icon": Message01Icon, "label": "AI Chat", "shortcut": "Ctrl+Shift+A"},
        {"id": "export", "icon": DownloadSquare02Icon, "label": "Export", "shortcut": "Ctrl+Shift+X"}
    ];

    return <div className="w-12 flex-shrink-0 flex flex-col items-center bg-background border-r border-border pt-1 gap-0.5 h-full">
        {topItems.map(lambda(item: Any) -> Any {
            isActive = activeView == item.id and not sidebarCollapsed;
            return <Tooltip key={item.id}>
                <TooltipTrigger asChild={True}>
                    <div className="relative w-12 flex justify-center items-center">
                        {isActive and <div className="absolute left-0 top-1.5 bottom-1.5 w-0.5 bg-foreground rounded-r-sm" /> or None}
                        <Button
                            variant="ghost" size="icon"
                            onClick={lambda -> None { handleClick(item.id); }}
                            className={cn("size-9 hover:bg-accent", ("text-foreground" if isActive else "text-muted-foreground"))}
                            style={{"opacity": (1 if isActive else 0.6)}}
                        >
                            <HugeiconsIcon icon={item.icon} strokeWidth={2} className="size-5" />
                        </Button>
                        {item.id == "git" and gitChangedCount > 0 and <Badge
                            className="absolute top-1 right-1.5 text-[9px] h-4 min-w-[16px] px-1 pointer-events-none bg-info text-info-foreground border-0"
                        >
                            {String(gitChangedCount)}
                        </Badge> or None}
                        {item.id == "run" and isRunning and <div className="absolute top-1.5 right-2 w-[7px] h-[7px] rounded-full bg-success pointer-events-none" /> or None}
                    </div>
                </TooltipTrigger>
                <TooltipContent side="right">{item.label + " (" + item.shortcut + ")"}</TooltipContent>
            </Tooltip>;
        })}

        <div className="flex-1" />

        <Tooltip>
            <TooltipTrigger asChild={True}>
                <div className="relative w-12 flex justify-center items-center mb-2">
                    {activeView == "settings" and not sidebarCollapsed and <div className="absolute left-0 top-1.5 bottom-1.5 w-0.5 bg-foreground rounded-r-sm" /> or None}
                    <Button
                        variant="ghost" size="icon"
                        onClick={lambda -> None { handleClick("settings"); }}
                        className={cn("size-9 hover:bg-accent", ("text-foreground" if activeView == "settings" and not sidebarCollapsed else "text-muted-foreground"))}
                        style={{"opacity": (1 if activeView == "settings" and not sidebarCollapsed else 0.6)}}
                    >
                        <HugeiconsIcon icon={Settings01Icon} strokeWidth={2} className="size-5" />
                    </Button>
                </div>
            </TooltipTrigger>
            <TooltipContent side="right">{"Settings"}</TooltipContent>
        </Tooltip>
    </div>;
}
