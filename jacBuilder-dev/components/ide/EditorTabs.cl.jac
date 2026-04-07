import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Cancel01Icon, FloppyDiskIcon, MapsIcon, TextWrapIcon, GitCompareIcon }
import from .FileTree { FileIcon }
import from ...lib.utils { cn }

def:pub EditorTabs(props: Any) -> Any {
    tabs = props.tabs or [];
    activeTab = props.activeTab or "";
    onTabClick = props.onTabClick;
    onTabClose = props.onTabClose;
    onSave = props.onSave;
    isDirty = props.isDirty or False;
    showMinimap = props.showMinimap or False;
    onToggleMinimap = props.onToggleMinimap;
    wordWrap = props.wordWrap or False;
    onToggleWordWrap = props.onToggleWordWrap;

    if tabs.length == 0 {
        return None;
    }

    return <div className="flex items-center flex-shrink-0 border-b border-border bg-background">
        <div className="flex-1 min-w-0 overflow-x-auto overflow-y-hidden [&::-webkit-scrollbar]:h-1.5 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:bg-border [&::-webkit-scrollbar-thumb]:rounded-full">
            <div className="flex flex-nowrap h-9">
                {tabs.map(lambda (tab: Any) -> Any {
                    isActive = tab.path == activeTab;
                    isDiffTab = tab.isDiff or False;
                    tabFileName = tab.path.split("/").pop();
                    displayName = tabFileName;
                    if isDiffTab {
                        slashIdx = tab.path.indexOf("/", 7);
                        realPath = tab.path.slice(slashIdx + 1) if slashIdx >= 0 else tab.path;
                        displayName = realPath.split("/").pop();
                    }

                    return <div
                        key={tab.path}
                        className={("flex items-center gap-1.5 px-3 h-full border-r border-border cursor-pointer min-w-fit border-b-2 border-b-primary bg-background" if isActive else "flex items-center gap-1.5 px-3 h-full border-r border-border cursor-pointer min-w-fit border-b-2 border-b-transparent bg-background")}
                    >
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={lambda { onTabClick(tab.path); }}
                            className="h-full flex items-center gap-1.5 p-0 rounded-none hover:bg-transparent"
                        >
                            {isDiffTab and <HugeiconsIcon icon={GitCompareIcon} strokeWidth={2} className="size-3 text-info" /> or <FileIcon fileName={displayName} size={12} />}
                            <span className={cn("text-[12px] whitespace-nowrap", (isActive and "font-medium text-foreground" or "text-muted-foreground"))}>
                                {displayName}
                            </span>
                            {isDiffTab and <span className="text-[9px] font-mono text-info bg-info/10 px-1 rounded">{"diff"}</span> or None}
                            {tab.isDirty and not isDiffTab and <span className="text-[11px] text-warning font-bold leading-none">{"*"}</span> or None}
                        </Button>
                        <Button
                            variant="ghost"
                            size="icon-xs"
                            onClick={lambda (e: Any) {
                                e.stopPropagation();
                                onTabClose(tab.path);
                            }}
                            className="size-3.5 text-muted-foreground hover:bg-accent flex-shrink-0"
                        >
                            <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-2.5" />
                        </Button>
                    </div>;
                })}
            </div>
        </div>
        <div className="flex items-center gap-0.5 px-2 h-9 flex-shrink-0 border-l border-border">
            {onSave and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="icon-xs"
                        onClick={lambda -> None { onSave(); }}
                        className={("size-6 hover:bg-accent text-warning" if isDirty else "size-6 hover:bg-accent text-muted-foreground opacity-50")}
                    >
                        <HugeiconsIcon icon={FloppyDiskIcon} strokeWidth={2} className="size-3.5" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="bottom">{"Save (Ctrl+S)"}</TooltipContent>
            </Tooltip> or None}
            {onToggleMinimap and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="icon-xs"
                        onClick={lambda -> None { onToggleMinimap(); }}
                        className={("size-6 hover:bg-accent text-primary" if showMinimap else "size-6 hover:bg-accent text-muted-foreground opacity-50")}
                    >
                        <HugeiconsIcon icon={MapsIcon} strokeWidth={2} className="size-3.5" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="bottom">{showMinimap and "Hide Minimap" or "Show Minimap"}</TooltipContent>
            </Tooltip> or None}
            {onToggleWordWrap and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="icon-xs"
                        onClick={lambda -> None { onToggleWordWrap(); }}
                        className={("size-6 hover:bg-accent text-primary" if wordWrap else "size-6 hover:bg-accent text-muted-foreground opacity-50")}
                    >
                        <HugeiconsIcon icon={TextWrapIcon} strokeWidth={2} className="size-3.5" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="bottom">{wordWrap and "Disable Word Wrap" or "Enable Word Wrap"}</TooltipContent>
            </Tooltip> or None}
        </div>
    </div>;
}
