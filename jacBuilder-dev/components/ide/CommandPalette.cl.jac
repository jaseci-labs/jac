import from react { useEffect }
import from ..ui.command {
    CommandDialog, CommandInput, CommandList, CommandEmpty,
    CommandGroup, CommandItem, CommandSeparator
}
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    PlayIcon, StopIcon, FileAddIcon,
    FloppyDiskIcon, ViewIcon, ViewOffSlashIcon, MapsIcon, LinkSquare02Icon,
    ComputerTerminal01Icon, KeyboardIcon, Message01Icon, CodeIcon,
    Key01Icon, Globe02Icon, Rocket01Icon, Delete02Icon, Clock01Icon, Camera01Icon,
    File01Icon, Search01Icon,
    GitBranchIcon, GitCommitIcon, GitMergeIcon, GitCompareIcon,
    ArrowUp01Icon, ArrowDown01Icon, Refresh01Icon,
    BookmarkAdd01Icon, FileAttachmentIcon, SidebarLeft01Icon
}
import from .FileTree { FileIcon }
import from "...lib.utils" { cn }

def:pub CommandPalette(props: Any) -> Any {
    onRun = props.onRun;
    onStop = props.onStop;
    onNewFile = props.onNewFile;
    onSave = props.onSave;
    onTogglePreview = props.onTogglePreview;
    onToggleMinimap = props.onToggleMinimap;
    onOpenPreview = props.onOpenPreview;
    onToggleTerminal = props.onToggleTerminal;
    onShowShortcuts = props.onShowShortcuts;
    previewStatus = props.previewStatus or "stopped";
    showPreview = props.showPreview or False;
    hasProject = props.hasProject or False;
    hasActiveTab = props.hasActiveTab or False;
    onSwitchView = props.onSwitchView;
    onOpenSettings = props.onOpenSettings;
    onShareProject = props.onShareProject;
    onDeploy = props.onDeploy;
    onDestroyDeploy = props.onDestroyDeploy;
    isDeployed = props.isDeployed or False;
    onCaptureVersion = props.onCaptureVersion;
    onSwitchToExport = props.onSwitchToExport;
    onOpenSymbolSearch = props.onOpenSymbolSearch;
    git = props.git or None;
    onToggleSidebar = props.onToggleSidebar;
    fileList = props.fileList or [];
    onFileClick = props.onFileClick;
    projectType = props.projectType or "fullstack";

    has isOpen: bool = False;

    isRunning = previewStatus == "running" or previewStatus == "starting";
    isScript = projectType == "script";
    isBackend = projectType == "backend";
    hasGit = Boolean(git);

    useEffect(lambda {
        def handleKeyDown(e: Any) -> None {
            if (e.ctrlKey or e.metaKey) and (e.key == "k" or e.key == "p") {
                e.preventDefault();
                isOpen = not isOpen;
            }
        }
        kd = handleKeyDown;
        document.addEventListener("keydown", kd);
        return lambda {
            document.removeEventListener("keydown", kd);
        };
    }, []);

    def runAction(fn: Any) -> None {
        isOpen = False;
        if fn { actionFn = fn; actionFn.call(None); }
    }

    return <CommandDialog open={isOpen} onOpenChange={lambda v: Any { isOpen = Boolean(v); }}>
        <CommandInput placeholder="Search commands..." />
        <CommandList>
            <CommandEmpty>{"No matching commands..."}</CommandEmpty>

            <CommandGroup heading="Files">
                {fileList.map(lambda(f: str) -> Any {
                    fileName = f.split("/").pop() or f;
                    return <CommandItem
                        key={"file-" + f}
                        onSelect={lambda { runAction(lambda { if onFileClick { fileClickFn = onFileClick; fileClickFn.call(None, f); } }); }}
                    >
                        <FileIcon fileName={fileName} size={16} />
                        <span>{fileName}</span>
                        <span className="text-xs text-muted-foreground ml-auto">{f}</span>
                    </CommandItem>;
                })}
            </CommandGroup>

            <CommandSeparator />

            <CommandGroup heading="Actions">
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(onRun); }}>
                    <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className={cn("size-4", (hasProject and "text-green-500" or "text-muted-foreground"))} />
                    <span>{(isScript and "Run Script" or (isBackend and "Start Server" or "Run Preview"))}</span>
                </CommandItem>
                <CommandItem disabled={not isRunning} onSelect={lambda { runAction(onStop); }}>
                    <HugeiconsIcon icon={StopIcon} strokeWidth={2} className={cn("size-4", (isRunning and "text-red-500" or "text-muted-foreground"))} />
                    <span>{"Stop"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(onNewFile); }}>
                    <HugeiconsIcon icon={FileAddIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"New File"}</span>
                </CommandItem>
                <CommandItem disabled={not hasActiveTab} onSelect={lambda { runAction(onSave); }}>
                    <HugeiconsIcon icon={FloppyDiskIcon} strokeWidth={2} className="size-4 text-yellow-500" />
                    <span>{"Save File"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+S"}</span>
                </CommandItem>
                {not isScript and <CommandItem onSelect={lambda { runAction(onTogglePreview); }}>
                    {showPreview and <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-4 text-primary" /> or <HugeiconsIcon icon={ViewOffSlashIcon} strokeWidth={2} className="size-4 text-primary" />}
                    <span>{(isBackend and (showPreview and "Hide API Explorer" or "Show API Explorer") or (showPreview and "Hide Preview Panel" or "Show Preview Panel"))}</span>
                </CommandItem> or None}
                <CommandItem onSelect={lambda { runAction(onToggleMinimap); }}>
                    <HugeiconsIcon icon={MapsIcon} strokeWidth={2} className="size-4 text-muted-foreground" />
                    <span>{"Toggle Minimap"}</span>
                </CommandItem>
                <CommandItem disabled={not isRunning} onSelect={lambda { runAction(onOpenPreview); }}>
                    <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Open Preview in New Tab"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(onToggleTerminal); }}>
                    <HugeiconsIcon icon={ComputerTerminal01Icon} strokeWidth={2} className="size-4 text-muted-foreground" />
                    <span>{"Toggle Terminal"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onToggleSidebar { sidebarFn = onToggleSidebar; sidebarFn.call(None); } }); }}>
                    <HugeiconsIcon icon={SidebarLeft01Icon} strokeWidth={2} className="size-4 text-muted-foreground" />
                    <span>{"Toggle Sidebar"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+B"}</span>
                </CommandItem>
            </CommandGroup>

            <CommandSeparator />

            <CommandGroup heading="Views">
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "files"); } }); }}>
                    <HugeiconsIcon icon={FileAttachmentIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"View: Explorer"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+Shift+E"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "search"); } }); }}>
                    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"View: Search Symbols"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+Shift+F"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "git"); } }); }}>
                    <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"View: Source Control"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+Shift+G"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "run"); } }); }}>
                    <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"View: Run & Preview"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+Shift+D"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "chat"); } }); }}>
                    <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"View: AI Chat"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+Shift+A"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(onShowShortcuts); }}>
                    <HugeiconsIcon icon={KeyboardIcon} strokeWidth={2} className="size-4 text-muted-foreground" />
                    <span>{"Keyboard Shortcuts"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Shift+?"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(onOpenSettings); }}>
                    <HugeiconsIcon icon={Key01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Environment Variables"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if onShareProject { onShareProject(); } }); }}>
                    <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Share to Community"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if isDeployed { if onDestroyDeploy { onDestroyDeploy(); } } else { if onDeploy { onDeploy(); } } }); }}>
                    {isDeployed and <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-4 text-red-500" /> or <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-4 text-primary" />}
                    <span>{isDeployed and "Destroy Deployment" or "Deploy to Cloud"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if onSwitchToExport { exportFn = onSwitchToExport; exportFn.call(None); } }); }}>
                    <HugeiconsIcon icon={FileAttachmentIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Export Project"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if onOpenSymbolSearch { symFn = onOpenSymbolSearch; symFn.call(None); } }); }}>
                    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Go to Symbol in Workspace"}</span>
                    <span className="text-xs text-muted-foreground ml-auto">{"Ctrl+T"}</span>
                </CommandItem>
                <CommandItem disabled={not hasProject} onSelect={lambda { runAction(lambda { if onCaptureVersion { onCaptureVersion(); } }); }}>
                    <HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Save Snapshot"}</span>
                </CommandItem>
            </CommandGroup>

            {hasGit and <CommandSeparator /> or None}
            {hasGit and <CommandGroup heading="Git">
                <CommandItem onSelect={lambda { runAction(lambda { git.doPush(); }); }}>
                    <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Push"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { git.doPull(); }); }}>
                    <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Pull"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { git.createCheckpoint(); }); }}>
                    <HugeiconsIcon icon={BookmarkAdd01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Create Checkpoint"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { git.refresh(); }); }}>
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Refresh Status"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "git"); } }); }}>
                    <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Open Git Panel"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "git"); } }); }}>
                    <HugeiconsIcon icon={GitCompareIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: View Diff"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "git"); } }); }}>
                    <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: View History"}</span>
                </CommandItem>
                <CommandItem onSelect={lambda { runAction(lambda { if onSwitchView { viewFn = onSwitchView; viewFn.call(None, "git"); } }); }}>
                    <HugeiconsIcon icon={GitMergeIcon} strokeWidth={2} className="size-4 text-primary" />
                    <span>{"Git: Merge Branch"}</span>
                </CommandItem>
            </CommandGroup> or None}
        </CommandList>
    </CommandDialog>;
}
