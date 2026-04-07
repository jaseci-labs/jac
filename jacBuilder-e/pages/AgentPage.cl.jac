"""Agent Page — chat-first IDE for vibe coding with Claude."""

import from react { useState, useRef, useEffect }
import from "@jac/runtime" { useNavigate }
import from ..components.ui.button { Button }
import from ..components.ui.badge { Badge }
import from "..components.ui.scroll-area" { ScrollArea }
import from ..lib.utils { cn }
import from ..components.ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ..components.ui.spinner { Spinner }
import from ..components.ui.avatar { Avatar, AvatarFallback }
import from ..components.ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }
import from "..components.ui.alert-dialog" {
    AlertDialog, AlertDialogContent, AlertDialogHeader,
    AlertDialogTitle, AlertDialogDescription,
    AlertDialogFooter, AlertDialogCancel, AlertDialogAction
}
import from ..components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from ..components.ui.collapsible { Collapsible, CollapsibleTrigger, CollapsibleContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon, PlayIcon, StopIcon, GitBranchIcon,
    Delete02Icon, PlusSignIcon, Message01Icon, ArrowRight01Icon,
    Refresh01Icon, ComputerTerminal01Icon, AiChat02Icon,
    ViewIcon, CodeIcon, Settings01Icon, Globe02Icon,
    ArrowDown01Icon
}

import from ..hooks.useAgentIDE { useAgentIDE }
import from ..hooks.useClaudeChat { useClaudeChat }
import from ..hooks.useGit { useGit }
import from ..hooks.useProjectSettings { useProjectSettings }
import from "..components.ui.resizable" { ResizablePanelGroup, ResizablePanel, ResizableHandle }
import from ..components.ide.IDEPreviewPanel { IDEPreviewPanel }
import from ..components.ide.TerminalPanel { TerminalPanel }
import from ..components.ide.GitPanel { GitPanel }
import from ..components.ide.DiffPanel { DiffPanel }
import from ..components.ide.ChatPanel { ChatPanel, AssistantMessage, ClaudeStreamingMessage, ThreadList, ThreadItem }
import from ..components.ide.EnvVarPanel { EnvVarPanel }
import from ..components.ide.ActivityTimeline { ActivityTimeline }
import from ..services.ideService { idePreviewScreenshot, sendWsRequest }

"""Project list item in left sidebar."""
def ProjectItem(props: Any) -> Any {
    p = props.project;
    isActive = props.isActive or False;
    onSelect = props.onSelect;

    return <Button variant="ghost" size="sm"
        className={cn("gap-2 w-full text-left justify-start", ("bg-muted border border-primary/30" if isActive else "hover:bg-muted border border-transparent"))}
        onClick={lambda { selectHandler = onSelect; selectHandler.call(None, p.id); }}
    >
        <div className={cn("size-2 rounded-full flex-shrink-0", ("bg-primary" if isActive else "bg-muted-foreground/15"))} />
        <span className={cn("text-sm truncate flex-1", ("text-foreground" if isActive else "text-muted-foreground"))}>{p.name}</span>
    </Button>;
}

"""Agent page: projects sidebar + chat center + preview/git right."""
def:pub AgentPage() -> Any {
    navigate = useNavigate();
    ide = useAgentIDE();
    claudeChat = useClaudeChat(ide);
    worktreePath = claudeChat.threadWorktreePath or "";
    git = useGit(ide.projectId, worktreePath);
    settings = useProjectSettings(ide.projectId);

    has terminalCollapsed: bool = False;
    has diffCollapsed: bool = True;
    has fileViewerOpen: bool = False;
    has inputValue: str = "";
    has rightTab: str = "preview";
    has showMergeConfirm: bool = False;

    inputRef = useRef(None);

    aiProvider = claudeChat.aiProvider or "jaccoder";
    isClaude = aiProvider == "claude";
    accentColor = "violet" if isClaude else "orange";

    activeChat = claudeChat;

    useEffect(lambda {
        if claudeChat.claudeAvailable and claudeChat.aiProvider != "claude" {
            claudeChat.toggleProvider();
        }
    }, [claudeChat.claudeAvailable]);

    useEffect(lambda {
        if inputRef.current { inputRef.current.focus(); }
    }, [ide.projectId]);

    def handleSend() -> None {
        if not inputValue.trim() or activeChat.isLoading { return; }
        text = inputValue;
        inputValue = "";
        activeChat.sendMessage(text);
    }

    def handleKeyDown(e: Any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            handleSend();
        }
    }

    def handleRunPreview() -> None {
        wtPath = claudeChat.threadWorktreePath or "";
        ide.startPreview(wtPath);
    }

    def handleStopPreview() -> None {
        ide.stopPreview();
    }

    async def handleMerge() -> None {
        branchName = claudeChat.threadBranch;
        if not branchName { return; }
        result = await git.mergeBranch(branchName);
        showMergeConfirm = False;
        if result and result.success {
            git.refresh();
        }
    }

    async def handleUndo() -> None {
        if not ide.projectId { return; }
        result = await git.getWorkingDiff();
        if result and result.success {
            sendWsRequest("stop", ide.userId, ide.projectId, 0, lambda(_: Any) {});
        }
    }

    def handleViewFile(path: str) -> None {
        ide.viewFile(path);
        fileViewerOpen = True;
    }

    displayName = localStorage.getItem("jac_display_name") or "User";
    initial = displayName[0].toUpperCase() if displayName else "U";

    previewIsActive = ide.previewStatus == "running" or ide.previewStatus == "starting";

    return <div className="flex h-screen bg-background overflow-hidden">
        <div className="flex flex-col w-[280px] flex-shrink-0 bg-background border-r border-border" style={{"flexShrink": 0}}>
            <div className="flex items-center gap-2 px-4 h-14 flex-shrink-0 border-b border-border">
                <img src="/static/assets/logo-builder.png" alt="" className="size-6" />
                <span className="text-sm font-semibold text-foreground">{"Agent Mode"}</span>
                <div className="flex-1" />
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button variant="ghost" size="icon-xs" onClick={lambda { navigate("/dashboard"); }}>
                            <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent side="right">{"Back to Dashboard"}</TooltipContent>
                </Tooltip>
            </div>

            <div className="px-3 py-2 border-b border-border">
                <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">{"Projects"}</span>
            </div>

            <ScrollArea className="flex-1 min-h-0">
                <div className="px-2 py-1 flex flex-col gap-0.5">
                    {ide.projects.map(lambda p: Any -> Any {
                        isActive = p.id == ide.projectId;
                        return <div key={p.id}>
                            <ProjectItem project={p} isActive={isActive} onSelect={ide.switchProject} />
                            {isActive and <div className="ml-4 mt-0.5">
                                <ThreadList claudeChat={claudeChat} />
                            </div> or None}
                        </div>;
                    })}
                    {ide.projects.length == 0 and not ide.isLoading and <div className="flex flex-col items-center py-8 gap-2">
                        <span className="text-xs text-muted-foreground">{"No projects yet"}</span>
                        <Button size="sm" variant="outline" className="text-primary" onClick={lambda { navigate("/dashboard"); }}>{"Create Project"}</Button>
                    </div> or None}
                    {ide.isLoading and <div className="flex justify-center py-4">
                        <Spinner className="size-4 text-primary" />
                    </div> or None}
                </div>
            </ScrollArea>

            <div className="px-3 py-3 border-t border-border">
                <div className="flex items-center gap-2">
                    <Avatar className="size-[30px]">
                        <AvatarFallback className="bg-primary/20 text-primary text-xs">{initial}</AvatarFallback>
                    </Avatar>
                    <span className="text-xs font-medium truncate flex-1 text-foreground">{displayName}</span>
                </div>
            </div>
        </div>

        <ResizablePanelGroup direction="horizontal" className="flex-1 min-w-0">
        <ResizablePanel defaultSize={"55%"} minSize={"30%"}>
        <div className="flex flex-col h-full">
            <div className="flex items-center h-10 px-4 flex-shrink-0 border-b border-border bg-card">
                <div className="flex items-center gap-2">
                    <HugeiconsIcon icon={AiChat02Icon} strokeWidth={2} className={cn("size-3.5", ("text-claude" if isClaude else "text-primary"))} />
                    <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                        {"Claude Code" if isClaude else "JacCoder"}
                    </span>
                    {ide.project and <Badge variant="secondary" className="text-[10px]">{ide.project.name}</Badge> or None}
                </div>
                <div className="flex-1" />
                <div className="flex items-center gap-1.5">
                    {claudeChat.claudeAvailable and <div className="flex items-center rounded-md border border-border bg-background">
                        <Button variant="ghost" size="xs"
                            className={cn("text-[10px] px-2 py-0.5 rounded-l-md rounded-r-none", ("bg-primary text-primary-foreground" if not isClaude else "text-muted-foreground"))}
                            onClick={lambda -> None { if isClaude { claudeChat.toggleProvider(); } }}>
                            {"JacCoder"}
                        </Button>
                        <Button variant="ghost" size="xs"
                            className={cn("text-[10px] px-2 py-0.5 rounded-r-md rounded-l-none", ("bg-claude text-claude-foreground" if isClaude else "text-muted-foreground"))}
                            onClick={lambda -> None { if not isClaude { claudeChat.toggleProvider(); } }}>
                            {"Claude"}
                        </Button>
                    </div> or None}
                    {isClaude and activeChat.isLoading and <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="ghost" className="text-destructive hover:text-destructive"
                                onClick={lambda -> None { claudeChat.interruptClaude(); }}>
                                <HugeiconsIcon icon={StopIcon} strokeWidth={2} className="size-3" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{"Interrupt"}</TooltipContent>
                    </Tooltip> or None}
                    {ide.projectId and <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="ghost" className="text-muted-foreground"
                                onClick={lambda -> None { navigate("/project/" + ide.projectId); }}>
                                <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className="size-[13px]" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{"Open in IDE"}</TooltipContent>
                    </Tooltip> or None}
                    <Button size="icon-xs" variant="ghost" className="text-muted-foreground"
                        onClick={lambda -> None { activeChat.clearChat(); }}
                        disabled={activeChat.messages.length == 0}>
                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </div>
            </div>

            {not ide.projectId and <div className="flex-1 flex items-center justify-center">
                <div className="flex flex-col items-center gap-3">
                    <div className="w-16 h-16 rounded-2xl bg-card border border-border flex items-center justify-center">
                        <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className="size-7 text-muted-foreground" />
                    </div>
                    <span className="text-sm text-muted-foreground">{"Select a project to start building"}</span>
                </div>
            </div> or <div className="flex flex-col flex-1 min-h-0">
                {isClaude and claudeChat.envMode and <div className="flex items-center gap-2 px-4 py-1.5 border-b border-border bg-background">
                    <div className="flex items-center gap-1.5">
                        <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-[11px] text-muted-foreground" />
                        <span className="text-[10px] text-muted-foreground">
                            {claudeChat.threadBranch or git.currentBranch or "main"}
                        </span>
                    </div>
                    {claudeChat.threadWorktreePath and <Badge variant="outline" className="text-claude border-claude/30 text-[9px] h-[14px] px-1">{"worktree"}</Badge> or None}
                    {ide.previewWorktreePath and <Badge variant="outline" className="text-info border-info/30 text-[9px] h-[14px] px-1">{"wt preview"}</Badge> or None}
                    <div className="flex-1" />
                    {not claudeChat.activeThreadId and not claudeChat.isLoading and <div className="flex items-center rounded-md border border-border bg-background">
                        <Button variant="ghost" size="xs"
                            className={cn("text-[9px] px-1.5 py-0.5 rounded-l-md rounded-r-none", ("bg-claude text-claude-foreground" if claudeChat.envMode == "local" else "text-muted-foreground"))}
                            onClick={lambda -> None { claudeChat.setEnvMode("local"); }}>
                            {"Local"}
                        </Button>
                        <Button variant="ghost" size="xs"
                            className={cn("text-[9px] px-1.5 py-0.5 rounded-r-md rounded-l-none", ("bg-claude text-claude-foreground" if claudeChat.envMode == "worktree" else "text-muted-foreground"))}
                            onClick={lambda -> None { claudeChat.setEnvMode("worktree"); }}>
                            {"Worktree"}
                        </Button>
                    </div> or None}
                </div> or None}

                <div className="relative flex-1 min-h-0">
                <ScrollArea ref={claudeChat.scrollRef} className="absolute inset-0 px-4 py-3">
                    {activeChat.messages.length == 0 and <div className="flex flex-col items-center justify-center h-full gap-3">
                        <div className="w-12 h-12 rounded-2xl bg-card border border-border flex items-center justify-center">
                            <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className="size-[22px] text-muted-foreground" />
                        </div>
                        <span className="text-[13px] text-muted-foreground text-center max-w-[320px] leading-relaxed">
                            {"Describe what you want to build. Claude will write the code and you can see the result in the live preview."}
                        </span>
                    </div> or None}

                    <div className="flex flex-col gap-3">
                        {activeChat.messages.map(lambda (msg: Any, idx: int) -> Any {
                            if msg.role == "user" {
                                return <div key={String(idx)} className="flex justify-end">
                                    <div className={cn("max-w-[85%] rounded-xl px-3.5 py-2.5", ("bg-claude text-claude-foreground" if isClaude else "bg-primary text-primary-foreground"))}>
                                        <span className="text-[13px] leading-relaxed whitespace-pre-wrap">{msg.content}</span>
                                    </div>
                                </div>;
                            }
                            if msg.role == "error" {
                                return <div key={String(idx)} className="flex justify-start">
                                    <div className="max-w-[85%] rounded-xl px-3.5 py-2.5 bg-destructive/10 border border-destructive/25">
                                        <span className="text-[13px] leading-relaxed text-destructive/70 whitespace-pre-wrap">{msg.content}</span>
                                    </div>
                                </div>;
                            }
                            if msg.isStreaming {
                                return <ClaudeStreamingMessage key={String(idx)} msg={msg} />;
                            }
                            return <AssistantMessage key={String(idx)} msg={msg} />;
                        })}
                    </div>
                </ScrollArea>

                {activeChat.showJumpToLatest and <div className="absolute bottom-3 left-0 right-0 flex justify-center pointer-events-none z-10">
                    <Button
                        size="xs"
                        variant="outline"
                        className="h-6 gap-1.5 text-[11px] text-muted-foreground pointer-events-auto bg-background/90 backdrop-blur-sm border-border/60 hover:text-foreground hover:border-border shadow-md rounded-full px-3"
                        onClick={lambda -> None { activeChat.scrollToLatest(); }}>
                        <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-3" />
                        <span>Jump to latest</span>
                    </Button>
                </div> or None}
                </div>

                <div className="flex-shrink-0 px-4 py-3 border-t border-border bg-background">
                    <div className="flex items-center gap-2">
                        <input
                            ref={inputRef} value={inputValue}
                            onChange={lambda (e: Any) { inputValue = e.currentTarget.value; }}
                            onKeyDown={handleKeyDown}
                            placeholder={("Ask Claude Code..." if isClaude else "Describe what you want to build...")}
                            disabled={activeChat.isLoading or not ide.projectId}
                            className="flex-1 h-9 px-3 text-sm rounded-md border border-border bg-card text-foreground outline-none placeholder:text-muted-foreground disabled:opacity-50"
                        />
                        <Button size="sm" className={cn("h-9 px-3", ("bg-claude hover:bg-claude/90" if isClaude else "bg-primary hover:bg-primary/80"))}
                            onClick={lambda -> None { handleSend(); }}
                            disabled={not inputValue.trim() or activeChat.isLoading or not ide.projectId}>
                            <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className="size-4" />
                        </Button>
                    </div>
                </div>
            </div>}
        </div>
        </ResizablePanel>

        <ResizableHandle className="w-1 bg-border hover:bg-primary/35 transition-colors" />

        <ResizablePanel defaultSize={"45%"} minSize={"25%"} className="flex flex-col bg-card overflow-hidden">
            <Tabs
                value={rightTab}
                onValueChange={lambda (val: str) -> None { rightTab = val or "preview"; }}
                className="flex flex-col h-full"
            >
                <div className="flex items-center h-10 flex-shrink-0 border-b border-border bg-background">
                    <TabsList variant="line" className="h-full bg-transparent gap-0 rounded-none p-0">
                        <TabsTrigger value="preview" className="h-full rounded-none px-3.5 text-[11px] font-semibold">
                            <div className="flex items-center gap-1.5">
                                <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className="size-[13px]" />
                                <span>{"Preview"}</span>
                                {previewIsActive and <div className="size-1.5 rounded-full bg-success" /> or None}
                            </div>
                        </TabsTrigger>
                        <TabsTrigger value="git" className="h-full rounded-none px-3.5 text-[11px] font-semibold">
                            <div className="flex items-center gap-1.5">
                                <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-[13px]" />
                                <span>{"Git"}</span>
                                {git.currentBranch and <Badge variant="secondary" className="text-[8px] h-[14px] px-1">{git.currentBranch}</Badge> or None}
                            </div>
                        </TabsTrigger>
                        <TabsTrigger value="settings" className="h-full rounded-none px-3.5 text-[11px] font-semibold">
                            <div className="flex items-center gap-1.5">
                                <HugeiconsIcon icon={Settings01Icon} strokeWidth={2} className="size-[13px]" />
                                <span>{"Settings"}</span>
                            </div>
                        </TabsTrigger>
                    </TabsList>
                    <div className="flex-1" />
                    <div className="flex items-center gap-1 pr-2">
                        {rightTab == "preview" and ide.projectId and not previewIsActive and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-success hover:text-success" onClick={lambda -> None { handleRunPreview(); }}>
                                    <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-3" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Run Preview"}</TooltipContent>
                        </Tooltip> or None}
                        {rightTab == "preview" and previewIsActive and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-destructive hover:text-destructive" onClick={lambda -> None { handleStopPreview(); }}>
                                    <HugeiconsIcon icon={StopIcon} strokeWidth={2} className="size-3" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Stop Preview"}</TooltipContent>
                        </Tooltip> or None}
                        {rightTab == "preview" and ide.projectId and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-muted-foreground" onClick={lambda -> None { ide.refreshPreview(); }}>
                                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-[11px]" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Refresh"}</TooltipContent>
                        </Tooltip> or None}
                        {rightTab == "git" and claudeChat.threadBranch and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-claude hover:text-claude" onClick={lambda -> None { showMergeConfirm = True; }}>
                                    <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-3" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Merge to main"}</TooltipContent>
                        </Tooltip> or None}
                        {rightTab == "git" and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-muted-foreground" onClick={lambda -> None { git.refresh(); }}>
                                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-[11px]" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Refresh"}</TooltipContent>
                        </Tooltip> or None}
                        {ide.projectId and <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost" className="text-muted-foreground" onClick={lambda -> None { fileViewerOpen = True; }}>
                                    <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-[11px]" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"View Files"}</TooltipContent>
                        </Tooltip> or None}
                    </div>
                </div>

                <TabsContent value="preview" className="flex flex-col flex-1 min-h-0 mt-0">
                    <div className="flex-1 min-h-0">
                        <IDEPreviewPanel
                            previewUrl={ide.previewUrl}
                            previewStatus={ide.previewStatus}
                            onRun={handleRunPreview}
                            onOpenExternal={lambda -> None { if ide.previewUrl { window.open(ide.previewUrl, "_blank"); } }}
                            onScreenshot={lambda -> None { idePreviewScreenshot(ide.projectId); }}
                            refreshKey={ide.previewRefreshKey}
                        />
                    </div>
                    <TerminalPanel
                        content={ide.terminalContent}
                        isCollapsed={terminalCollapsed}
                        onToggle={lambda -> None { terminalCollapsed = not terminalCollapsed; }}
                        onClear={lambda -> None {}}
                    />
                </TabsContent>

                <TabsContent value="git" className="flex flex-col flex-1 min-h-0 mt-0">
                    <ScrollArea className="flex-1 min-h-0">
                        <GitPanel git={git} />
                        <div className="border-t border-border">
                            <Button variant="ghost" size="xs"
                                className="gap-1.5 w-full px-3 py-1.5 justify-start"
                                onClick={lambda -> None { diffCollapsed = not diffCollapsed; }}
                            >
                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-[10px] text-muted-foreground" style={{
                                    "transform": "rotate(90deg)" if not diffCollapsed else "rotate(0deg)",
                                    "transition": "transform 0.15s ease"
                                }} />
                                <span className="text-[9px] font-semibold uppercase tracking-wider text-muted-foreground">{"Diff"}</span>
                            </Button>
                            {not diffCollapsed and <DiffPanel git={git} /> or None}
                        </div>
                    </ScrollArea>
                </TabsContent>

                <TabsContent value="settings" className="flex flex-col flex-1 min-h-0 mt-0">
                    <ScrollArea className="flex-1 min-h-0">
                        <div className="p-3">
                            <span className="text-xs font-semibold uppercase tracking-wider mb-3 block text-muted-foreground">{"Project Environment"}</span>
                            <EnvVarPanel settings={settings} />
                        </div>
                    </ScrollArea>
                </TabsContent>
            </Tabs>
        </ResizablePanel>
        </ResizablePanelGroup>

        <AlertDialog open={showMergeConfirm} onOpenChange={lambda v: Any { if not v { showMergeConfirm = False; } }}>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>{"Merge to Main"}</AlertDialogTitle>
                    <AlertDialogDescription>
                        {"Merge branch "}
                        <Badge variant="outline" className="text-claude border-claude/30">{claudeChat.threadBranch or ""}</Badge>
                        {" into main?"}
                    </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel onClick={lambda { showMergeConfirm = False; }}>{"Cancel"}</AlertDialogCancel>
                    <AlertDialogAction className="bg-claude hover:bg-claude/90" onClick={lambda { handleMerge(); }}>{"Merge"}</AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>

        <Dialog open={fileViewerOpen and ide.viewerFile != None} onOpenChange={lambda v: Any { if not v { fileViewerOpen = False; ide.closeViewer(); } }}>
            <DialogContent className="sm:max-w-3xl">
                <DialogHeader>
                    <DialogTitle>{ide.viewerFile.path if ide.viewerFile else "File Viewer"}</DialogTitle>
                </DialogHeader>
                {ide.viewerFile and <ScrollArea style={{"height": "500px"}}>
                    <pre className="m-0 p-4 text-xs leading-normal text-foreground font-mono whitespace-pre-wrap break-all">{ide.viewerFile.content}</pre>
                </ScrollArea> or None}
            </DialogContent>
        </Dialog>

        <Dialog open={fileViewerOpen and not ide.viewerFile} onOpenChange={lambda v: Any { if not v { fileViewerOpen = False; } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Project Files"}</DialogTitle>
                </DialogHeader>
                <ScrollArea style={{"maxHeight": "400px"}}>
                    <div className="flex flex-col gap-0.5">
                        {ide.files.map(lambda (f: Any, i: int) -> Any {
                            fName = f.name if f.name else String(f);
                            fPath = f.path if f.path else fName;
                            return <Button key={String(i)} variant="ghost" size="sm" className="w-full justify-start gap-2"
                                onClick={lambda { handleViewFile(fPath); }}
                            >
                                <span className="text-xs text-foreground">{fPath}</span>
                            </Button>;
                        })}
                    </div>
                </ScrollArea>
            </DialogContent>
        </Dialog>
    </div>;
}
