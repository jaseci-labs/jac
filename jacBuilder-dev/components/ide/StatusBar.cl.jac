import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, GitBranchIcon, CircleIcon,
    Rocket01Icon, LinkSquare02Icon,
    PlayIcon, StopIcon, ViewIcon, ViewOffSlashIcon,
    Search01Icon
}

def:pub StatusBar(props: Any) -> Any {
    projectName = props.projectName or "";
    gitBranch = props.gitBranch or "";
    gitDirty = props.gitDirty or 0;
    cursorLine = props.cursorLine or 1;
    cursorColumn = props.cursorColumn or 1;
    previewStatus = props.previewStatus or "stopped";
    deploymentStatus = props.deploymentStatus or "";
    deploymentUrl = props.deploymentUrl or "";
    onBackClick = props.onBackClick;
    onBranchClick = props.onBranchClick;
    onTogglePreview = props.onTogglePreview;
    onRun = props.onRun;
    onStop = props.onStop;
    showPreview = props.showPreview or False;
    hasProject = props.hasProject or False;
    projectType = props.projectType or "fullstack";

    isScript = projectType == "script";
    isBackend = projectType == "backend";
    isRunning = previewStatus == "running";
    isStarting = previewStatus == "starting";
    isDeployed = deploymentStatus == "running";

    dotCls = "bg-muted-foreground";
    if isRunning { dotCls = "bg-success"; }
    elif isStarting { dotCls = "bg-warning"; }
    elif previewStatus == "error" { dotCls = "bg-destructive"; }

    def openCommandPalette() -> None {
        evt = Reflect.construct(KeyboardEvent, ["keydown", {"key": "k", "ctrlKey": True, "bubbles": True}]);
        document.dispatchEvent(evt);
    }

    return <div className="h-6 flex items-center justify-between pl-2 pr-2 bg-background border-t border-border flex-shrink-0 text-[11px] text-muted-foreground gap-1 select-none">
        <div className="flex items-center gap-2 min-w-0">
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={onBackClick}
                        className="h-[22px] gap-1 px-1 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                    >
                        <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-3" />
                        <span className="max-w-[140px] overflow-hidden text-ellipsis whitespace-nowrap">{projectName}</span>
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{"Back to Dashboard"}</TooltipContent>
            </Tooltip>

            {gitBranch and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={onBranchClick}
                        className="h-[22px] gap-0.5 px-1 text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground"
                    >
                        <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-3" />
                        <span>{gitBranch}</span>
                        {gitDirty > 0 and <span className="text-warning">{"*"}</span> or None}
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{"Source Control"}</TooltipContent>
            </Tooltip> or None}
        </div>

        <button
            className="flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[11px] text-muted-foreground hover:bg-muted hover:text-foreground transition-colors cursor-pointer"
            onClick={lambda { openCommandPalette(); }}
        >
            <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3" />
            <span>{"Command Palette"}</span>
            <kbd className="ml-0.5 px-1 py-px rounded bg-muted border border-border text-[10px] font-mono leading-none">{"Ctrl+K"}</kbd>
        </button>

        <div className="flex items-center gap-1.5">
            <span className="font-mono text-[11px]">
                {"Ln " + String(cursorLine) + ", Col " + String(cursorColumn)}
            </span>

            <div className="w-px h-3 bg-border" />

            {(isRunning or isStarting) and not isScript and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={onStop}
                        className="h-[22px] gap-0.5 px-1 text-[11px] text-destructive hover:bg-destructive/10 hover:text-destructive"
                    >
                        <HugeiconsIcon icon={StopIcon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{(isBackend and "Stop Server" or "Stop Preview")}</TooltipContent>
            </Tooltip> or <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={onRun}
                        disabled={not hasProject}
                        className="h-[22px] gap-0.5 px-1 text-[11px] text-success hover:bg-success/10 hover:text-success"
                    >
                        <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{(isScript and "Run Script" or (isBackend and "Start Server" or "Run Preview"))}</TooltipContent>
            </Tooltip>}

            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={onTogglePreview}
                        className={cn(
                            "h-[22px] gap-1 px-1 text-[11px] hover:bg-muted hover:text-foreground",
                            (showPreview and "text-primary" or "text-muted-foreground")
                        )}
                    >
                        <div className={cn("w-[7px] h-[7px] rounded-full", dotCls)} />
                        <span>{(isScript and "script" or (isBackend and ("api " + previewStatus) or previewStatus))}</span>
                        {not isScript and (showPreview and <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-3" /> or <HugeiconsIcon icon={ViewOffSlashIcon} strokeWidth={2} className="size-3" />) or None}
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{(isScript and "Script Mode" or (isBackend and "API Explorer" or (showPreview and "Hide Preview" or "Show Preview")))}</TooltipContent>
            </Tooltip>

            {isDeployed and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button
                        variant="ghost"
                        size="xs"
                        onClick={lambda -> None { if deploymentUrl { window.open(deploymentUrl, "_blank"); } }}
                        className="h-[22px] gap-0.5 px-1 text-[11px] text-success hover:bg-muted"
                    >
                        <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-3" />
                        <span>{"deployed"}</span>
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="top">{"Open deployment"}</TooltipContent>
            </Tooltip> or None}
        </div>
    </div>;
}
