"""Chat Mode panel with streaming AI activity timeline, provider toggle, and Claude thread management."""

import from react { useRef, useEffect, useState }
import from "..ui.scroll-area" { ScrollArea }
import from ...lib.utils { cn }
import from ..ui.textarea { Textarea }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.spinner { Spinner }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "..ui.dropdown-menu" { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator }
import from ..ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from ..ui.separator { Separator }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    SentIcon, Delete02Icon, Message01Icon, AiChat02Icon,
    Cancel01Icon, ArrowRight01Icon, StopIcon, Copy01Icon,
    PlusSignIcon, MoreHorizontalCircle01Icon, PencilEdit01Icon, Clock01Icon, Tick02Icon,
    GitBranchIcon, Undo03Icon,
    PaintBrush04Icon, Bug02Icon, StructureCheckIcon, TextIcon, ImageAdd01Icon,
    ArrowDown01Icon
}
import from .ActivityTimeline { ActivityTimeline }
import from .MarkdownMessage { MarkdownMessage }

glob _SUGGESTIONS: list = [
    {"label": "Add a new feature", "text": "Add a dark mode toggle to the app", "icon": PaintBrush04Icon},
    {"label": "Fix a bug", "text": "Find and fix any bugs in the current code", "icon": Bug02Icon},
    {"label": "Explain the project", "text": "Explain the project structure and how the code is organized", "icon": StructureCheckIcon},
    {"label": "Write tests", "text": "Write test cases for the main functionality", "icon": TextIcon}
];

def:pub UserMessage(props: Any) -> Any {
    msg = props.msg;
    msgIdx = props.msgIdx;
    onResend = props.onResend or None;
    isLoading = props.isLoading or False;
    has isEditing: bool = False;
    has editValue: str = "";
    has copied: bool = False;
    editRef = useRef(None);

    useEffect(lambda -> None {
        if isEditing and editRef.current {
            editRef.current.focus();
            editRef.current.selectionStart = editRef.current.value.length;
        }
    }, [isEditing]);

    def startEdit() -> None {
        if isLoading { return; }
        editValue = msg.content or "";
        isEditing = True;
    }

    def cancelEdit() -> None {
        isEditing = False;
    }

    def handleResend() -> None {
        trimmed = editValue.trim();
        if not trimmed or not onResend { return; }
        isEditing = False;
        resendFn = onResend;
        resendFn.call(None, msgIdx, trimmed);
    }

    def handleCopy() -> None {
        navigator.clipboard.writeText(msg.content or "");
        copied = True;
        setTimeout(lambda { copied = False; }, 2000);
    }

    def handleEditKeyDown(e: Any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            handleResend();
        }
        if e.key == "Escape" {
            cancelEdit();
        }
    }

    if isEditing {
        return <div className="py-2 mt-1.5 mb-0.5">
            <Textarea
                ref={editRef}
                value={editValue}
                onChange={lambda (e: Any) { editValue = e.currentTarget.value; }}
                onKeyDown={handleEditKeyDown}
                className="min-h-[60px] max-h-[200px] w-full resize-none rounded-lg border border-border bg-muted/50 px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus-visible:ring-1 focus-visible:ring-primary/30 focus-visible:ring-offset-0 focus-visible:outline-none shadow-none"
                rows={2}
            />
            <div className="flex items-center gap-1.5 mt-1.5">
                <Button size="xs" variant="default"
                    className="text-[11px] h-6 px-2.5 gap-1"
                    onClick={lambda -> None { handleResend(); }}
                    disabled={not editValue.trim()}>
                    <HugeiconsIcon icon={SentIcon} strokeWidth={2} className="size-2.5" />
                    <span>Resend</span>
                </Button>
                <Button size="xs" variant="ghost"
                    className="text-[11px] h-6 px-2 text-muted-foreground"
                    onClick={lambda -> None { cancelEdit(); }}>
                    <span>Cancel</span>
                </Button>
            </div>
        </div>;
    }

    msgImages = msg.images or [];

    return <div className="py-2.5 mt-2 mb-1 pl-3 border-l-2 border-amber-400/60 bg-amber-400/5 rounded-r-lg group/user cursor-pointer relative"
        onClick={lambda -> None { startEdit(); }}>
        {msgImages.length > 0 and <div className="flex flex-wrap gap-1.5 mb-2">
            {msgImages.map(lambda (img: Any, i: int) -> Any {
                src = img.data_url or img;
                return <img key={String(i)} src={src} alt="attached" className="h-16 w-16 rounded-md object-cover border border-border" />;
            })}
        </div> or None}
        <span className="text-sm leading-relaxed text-foreground whitespace-pre-wrap">{msg.content}</span>
        <div className="absolute top-1 right-0 flex items-center gap-0.5 opacity-0 group-hover/user:opacity-100 transition-opacity">
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost"
                        className="text-muted-foreground hover:text-foreground"
                        onClick={lambda (e: Any) -> None { e.stopPropagation(); handleCopy(); }}>
                        {copied and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3 text-success" /> or <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-3" />}
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{copied and "Copied!" or "Copy"}</TooltipContent>
            </Tooltip>
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost"
                        className="text-muted-foreground hover:text-foreground"
                        onClick={lambda (e: Any) -> None { e.stopPropagation(); startEdit(); }}>
                        <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{"Edit & resend"}</TooltipContent>
            </Tooltip>
        </div>
    </div>;
}

def:pub AssistantMessage(props: Any) -> Any {
    msg = props.msg;
    onRevert = props.onRevert or None;
    onOpenDiff = props.onOpenDiff or None;
    isClaude = props.isClaude or False;
    has showThinking: bool = False;
    has isReverting: bool = False;
    has msgCopied: bool = False;
    updatedFiles = Array.from(Reflect.construct(Set, [msg.updatedFiles or []]));
    msgActivities = msg.activities or [];
    hasCheckpoint = Boolean(msg.checkpoint_ref);

    async def handleRevert() -> None {
        if not onRevert or isReverting { return; }
        isReverting = True;
        revertFn = onRevert;
        try {
            await revertFn.call(None, msg.checkpoint_ref);
        } except Exception as e {
            console.error("[AssistantMessage] Revert failed:", e);
        }
        isReverting = False;
    }

    def handleCopyMsg() -> None {
        navigator.clipboard.writeText(msg.content or "");
        msgCopied = True;
        setTimeout(lambda { msgCopied = False; }, 2000);
    }

    def handleFileDiffClick(filePath: str) -> None {
        if not onOpenDiff { return; }
        diffFn = onOpenDiff;
        diffFn.call(None, filePath, "last_commit");
    }

    return <div className="group relative py-1.5">
                <MarkdownMessage content={msg.content or ""} />
                <div className="flex items-center gap-0.5 mt-1.5 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="ghost" className="text-muted-foreground hover:text-foreground"
                                onClick={lambda -> None { handleCopyMsg(); }}>
                                {msgCopied and <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3 text-success" /> or <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-3" />}
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{msgCopied and "Copied!" or "Copy message"}</TooltipContent>
                    </Tooltip>
                </div>
                {<div className="flex flex-wrap gap-1.5 mt-2">
                    {updatedFiles.map(lambda (f: str, i: int) -> Any {
                        fParts = f.split("/");
                        fileName = fParts[fParts.length - 1];
                        return <Badge key={String(i)} variant="outline"
                            className={cn("text-success border-success/30 text-[10px] gap-1", ("hover:bg-success/10 cursor-pointer transition-colors" if onOpenDiff else ""))}
                            onClick={lambda -> None { handleFileDiffClick(f); }}>
                            {fileName}
                        </Badge>;
                    })}
                </div> if updatedFiles.length > 0 else None}
                {<div className="mt-2">
                    <Button variant="ghost" size="xs"
                        onClick={lambda -> None { showThinking = not showThinking; }}
                        className="h-auto px-0 text-[11px] gap-1 text-muted-foreground"
                    >
                        <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3" style={{
                            "transform": "rotate(90deg)" if showThinking else "rotate(0deg)",
                            "transition": "transform 0.2s ease"
                        }} />
                        <span>{("Hide" if showThinking else "Show") + " thinking (" + String(msgActivities.length) + " steps)"}</span>
                    </Button>
                    {showThinking and <div className="mt-1.5 ml-3 pl-2.5 border-l border-border/40 animate-in fade-in-0 duration-[120ms]">
                        <ActivityTimeline activities={msgActivities} animated={False} />
                    </div> or None}
                </div> if msgActivities.length > 0 else None}
                {hasCheckpoint and onRevert and <div className="flex items-center gap-1.5 mt-2">
                    <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="outline"
                                className="text-warning border-warning/30 hover:bg-warning/10"
                                onClick={lambda -> None { handleRevert(); }}
                                disabled={isReverting}>
                                {isReverting and <Spinner className="size-3" /> or <HugeiconsIcon icon={Undo03Icon} strokeWidth={2} className="size-3" />}
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{"Revert code to before this AI turn"}</TooltipContent>
                    </Tooltip>
                    <span className="text-[10px] text-muted-foreground">Revert to before this change</span>
                </div> or None}
    </div>;
}

"""Streaming message for Claude — shows live text + tool activity."""
def:pub ClaudeStreamingMessage(props: Any) -> Any {
    msg = props.msg;
    content = msg.content or "";
    msgActivities = msg.activities or [];

    return <div className="py-1">
        <div className="flex items-center gap-2 py-1">
            <Spinner className="size-3 text-claude" />
            <span className="text-xs font-medium text-claude">Claude is working...</span>
        </div>
        {msgActivities.length > 0 and <div className="mt-1">
            <ActivityTimeline activities={msgActivities} animated={True} />
        </div> or None}
        {content and <div className="mt-2">
            <MarkdownMessage content={content} />
            <span className="inline-block w-[6px] h-[14px] bg-claude animate-pulse rounded-sm ml-0.5 align-text-bottom" />
        </div> or <div className="mt-1">
            <span className="inline-block w-[6px] h-[14px] bg-claude animate-pulse rounded-sm" />
        </div>}
    </div>;
}


"""Completed build block — persists after AI finishes, shows activity timeline."""
def:pub CompletedBuildBlock(props: Any) -> Any {
    blockActivities = props.activities or [];
    colorClass = props.colorClass or "primary";
    has expanded: bool = True;

    return <div className="py-2">
        <Button variant="ghost" size="xs"
            onClick={lambda -> None { expanded = not expanded; }}
            className="h-auto px-0 gap-1.5 text-muted-foreground hover:text-foreground"
        >
            <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3.5 text-success" />
            <span className="text-xs font-medium text-success">Build completed</span>
            <span className="text-[10px] text-muted-foreground ml-0.5">{"(" + String(blockActivities.length) + " steps)"}</span>
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3 ml-1" style={{
                "transform": "rotate(90deg)" if expanded else "rotate(0deg)",
                "transition": "transform 0.2s ease"
            }} />
        </Button>
        {expanded and <div className="mt-1 ml-3 pl-2.5 border-l border-success/20 animate-in fade-in-0 duration-[120ms]">
            <ActivityTimeline activities={blockActivities} animated={False} />
        </div> or None}
    </div>;
}

"""Thread list item with rename/delete support."""
def:pub ThreadItem(props: Any) -> Any {
    thread = props.thread;
    isActive = props.isActive or False;
    onSelect = props.onSelect;
    onDelete = props.onDelete;
    onRename = props.onRename;
    onMerge = props.onMerge;
    has isRenaming: bool = False;
    has renameValue: str = "";
    renameRef = useRef(None);

    useEffect(lambda -> None {
        if isRenaming and renameRef.current {
            renameRef.current.focus();
        }
    }, [isRenaming]);

    def startRename() -> None {
        renameValue = thread.title or "New Chat";
        isRenaming = True;
    }

    def confirmRename() -> None {
        trimmed = renameValue.trim();
        if trimmed and trimmed != thread.title {
            renameHandler = onRename;
            renameHandler.call(None, thread.id, trimmed);
        }
        isRenaming = False;
    }

    def cancelRename() -> None {
        isRenaming = False;
    }

    title = thread.title or "New Chat";
    truncatedTitle = title.slice(0, 40) + "..." if title.length > 40 else title;
    hasBranch = thread.branch and thread.branch.length > 0;
    hasWorktree = thread.worktree_path and thread.worktree_path.length > 0;
    isMerged = thread.status == "merged";

    return <div
        className={cn("flex items-center gap-1 px-2.5 py-1.5 rounded-md cursor-pointer group transition-colors", ("bg-muted border border-claude/30" if isActive else "hover:bg-muted border border-transparent"))}
        onClick={lambda -> None {
            if not isRenaming {
                selectHandler = onSelect;
                selectHandler.call(None, thread.id);
            }
        }}
    >
        {isRenaming and <div className="flex items-center gap-1 flex-1 min-w-0">
            <input
                ref={renameRef}
                value={renameValue}
                onChange={lambda (e: Any) -> None { renameValue = e.target.value; }}
                onKeyDown={lambda (e: Any) -> None {
                    if e.key == "Enter" { confirmRename(); }
                    if e.key == "Escape" { cancelRename(); }
                }}
                className="flex-1 bg-card border border-border rounded px-1.5 py-0.5 text-[11px] text-foreground outline-none min-w-0"
                onClick={lambda (e: Any) -> None { e.stopPropagation(); }}
            />
            <Button size="icon-xs" variant="ghost" className="text-success hover:text-success" onClick={lambda (e: Any) -> None { e.stopPropagation(); confirmRename(); }}>
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-2.5" />
            </Button>
            <Button size="icon-xs" variant="ghost" className="text-muted-foreground" onClick={lambda (e: Any) -> None { e.stopPropagation(); cancelRename(); }}>
                <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-2.5" />
            </Button>
        </div> or <div className="flex items-center gap-1.5 flex-1 min-w-0">
            <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className={cn("size-3 flex-shrink-0", ("text-claude" if isActive else "text-muted-foreground"))} />
            <div className="flex flex-col min-w-0 flex-1">
                <span className={cn("text-[11px] truncate", ("text-foreground" if isActive else "text-muted-foreground"))}>{truncatedTitle}</span>
                {hasBranch and <div className="flex items-center gap-1">
                    <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className={cn("size-[9px]", ("text-success" if isMerged else "text-muted-foreground"))} />
                    <span className="text-[9px] text-muted-foreground truncate">{thread.branch}</span>
                    {isMerged and <Badge variant="outline" className="text-success border-success/30 text-[8px] h-[14px] px-1">merged</Badge> or None}
                    {hasWorktree and not isMerged and <Badge variant="outline" className="text-claude border-claude/30 text-[8px] h-[14px] px-1">wt</Badge> or None}
                </div> or None}
            </div>
            <DropdownMenu>
                <DropdownMenuTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost"
                        className="opacity-0 group-hover:opacity-100 transition-opacity text-muted-foreground"
                        onClick={lambda (e: Any) -> None { e.stopPropagation(); }}>
                        <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2} className="size-[11px]" />
                    </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={lambda (e: Any) -> None { e.stopPropagation(); startRename(); }}>
                        <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className="size-3" />
                        <span className="text-xs">Rename</span>
                    </DropdownMenuItem>
                    {hasWorktree and not isMerged and onMerge and <DropdownMenuItem onClick={lambda (e: Any) -> None {
                        e.stopPropagation();
                        mergeHandler = onMerge;
                        mergeHandler.call(None, thread.id);
                    }}>
                        <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-3 text-success" />
                        <span className="text-xs">Merge to main</span>
                    </DropdownMenuItem> or None}
                    <DropdownMenuItem variant="destructive" onClick={lambda (e: Any) -> None {
                        e.stopPropagation();
                        deleteHandler = onDelete;
                        deleteHandler.call(None, thread.id);
                    }}>
                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                        <span className="text-xs">Delete</span>
                    </DropdownMenuItem>
                </DropdownMenuContent>
            </DropdownMenu>
        </div>}
    </div>;
}


"""Thread list sidebar for Claude mode."""
def:pub ThreadList(props: Any) -> Any {
    claudeChat = props.claudeChat;
    threads = claudeChat.threads or [];
    activeThreadId = claudeChat.activeThreadId or "";
    has isExpanded: bool = True;

    return <div className="flex flex-col border-b border-border" style={{"maxHeight": "45%"}}>
        <div className="flex items-center justify-between px-3 py-1.5 flex-shrink-0">
            <Button variant="ghost" size="xs"
                className="h-auto px-0 gap-1.5 text-muted-foreground"
                onClick={lambda -> None { isExpanded = not isExpanded; }}
            >
                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-[11px]" style={{
                    "transform": "rotate(90deg)" if isExpanded else "rotate(0deg)",
                    "transition": "transform 0.15s ease"
                }} />
                <span className="text-[10px] font-semibold uppercase tracking-wider">Threads</span>
                {threads.length > 0 and <Badge variant="secondary" className="text-[9px] h-[14px] px-1">{String(threads.length)}</Badge> or None}
            </Button>
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost" className="text-claude hover:text-claude"
                        onClick={lambda -> None { claudeChat.startNewThread(); }}>
                        <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{"New thread"}</TooltipContent>
            </Tooltip>
        </div>
        {isExpanded and <ScrollArea className="flex-1 min-h-0 px-1.5 pb-1.5" style={{"maxHeight": "200px"}}>
            {threads.length == 0 and <div className="flex items-center justify-center py-3">
                <span className="text-[11px] text-muted-foreground">No threads yet</span>
            </div> or <div className="flex flex-col gap-0.5">
                {threads.map(lambda (t: Any) -> Any {
                    return <ThreadItem
                        key={t.id}
                        thread={t}
                        isActive={t.id == activeThreadId}
                        onSelect={claudeChat.loadThread}
                        onDelete={claudeChat.deleteThread}
                        onRename={claudeChat.renameThread}
                        onMerge={claudeChat.mergeThread}
                    />;
                })}
            </div>}
        </ScrollArea> or None}
    </div>;
}


def _activeThreadTitle(cc: Any) -> str {
    if not cc.activeThreadId { return "New Chat"; }
    threads = cc.threads or [];
    i = 0;
    while i < threads.length {
        t = threads[i];
        if t.id == cc.activeThreadId {
            return t.title or "New Chat";
        }
        i = i + 1;
    }
    return "New Chat";
}


def:pub ChatPanel(props: Any) -> Any {
    chat = props.chat;
    claudeChat = props.claudeChat or None;
    activeTab = props.activeTab or "";
    hasProject = props.hasProject or False;
    gitBranchList = props.branches or [];
    onOpenDiff = props.onOpenDiff or None;
    has inputValue: str = "";
    has pendingImages: list = [];
    inputRef = useRef(None);
    fileInputRef = useRef(None);

    hasClaude = Boolean(claudeChat);
    aiProvider = "jaccoder";
    if hasClaude { aiProvider = claudeChat.aiProvider or "jaccoder"; }

    activeChat = chat;
    if aiProvider == "claude" and claudeChat {
        activeChat = claudeChat;
    }

    useEffect(lambda {
        if inputRef.current { inputRef.current.focus(); }
    }, []);

    def handleSend() -> None {
        if (not inputValue.trim() and pendingImages.length == 0) or activeChat.isLoading { return; }
        text = inputValue;
        imgs = pendingImages.slice();
        inputValue = "";
        pendingImages = [];
        activeChat.sendMessage(text, imgs);
    }

    def handleKeyDown(e: Any) -> None {
        if e.key == "Enter" and not e.shiftKey {
            e.preventDefault();
            handleSend();
        }
        if e.key == "Escape" and activeChat.isLoading {
            e.preventDefault();
            if isClaude and claudeChat {
                claudeChat.interruptClaude();
            } else {
                if activeChat.stopAgent { activeChat.stopAgent(); }
            }
        }
    }

    def handlePaste(e: Any) -> None {
        items = e.clipboardData and e.clipboardData.items;
        if not items { return; }
        i = 0;
        while i < items.length {
            item = items[i];
            if item.type and item.type.startsWith("image/") {
                e.preventDefault();
                file = item.getAsFile();
                if file {
                    fname = file.name or "pasted-image";
                    reader = Reflect.construct(FileReader, []);
                    reader.onload = lambda (ev: Any) -> None {
                        dataUrl = ev.target.result;
                        pendingImages = lambda (prev: Any) -> Any { return prev.concat([{"data_url": dataUrl, "name": fname}]); };
                    };
                    reader.readAsDataURL(file);
                }
                return;
            }
            i = i + 1;
        }
    }

    def handleFileSelect(e: Any) -> None {
        files = e.target.files;
        if not files or files.length == 0 { return; }
        i = 0;
        while i < files.length {
            file = files[i];
            fname = file.name;
            reader = Reflect.construct(FileReader, []);
            reader.onload = lambda (ev: Any) -> None {
                dataUrl = ev.target.result;
                pendingImages = lambda (prev: Any) -> Any { return prev.concat([{"data_url": dataUrl, "name": fname}]); };
            };
            reader.readAsDataURL(file);
            i = i + 1;
        }
        e.target.value = "";
    }

    def removeImage(idx: int) -> None {
        pendingImages = pendingImages.filter(lambda (_: Any, i: int) -> bool { return i != idx; });
    }

    if not hasProject {
        return <div className="flex-1 flex items-center justify-center bg-background">
            <span className="text-[13px] text-muted-foreground">Select a project to start chatting</span>
        </div>;
    }

    activeFileName = "";
    if activeTab {
        parts = activeTab.split("/");
        activeFileName = parts[parts.length - 1];
    }

    placeholderText = "Describe what you want to build...";
    if activeTab { placeholderText = "Ask about " + activeFileName + "..."; }
    if aiProvider == "claude" { placeholderText = "Ask Claude Code..."; }

    isClaude = aiProvider == "claude";
    accentColor = "violet" if isClaude else "orange";

    return <div className="flex-1 flex flex-col overflow-hidden bg-card min-w-0">
        <div className="flex items-center justify-between px-3 h-10 flex-shrink-0 border-b border-border">
            <div className="flex items-center gap-2 min-w-0">
                <HugeiconsIcon icon={AiChat02Icon} strokeWidth={2} className={cn("size-3.5 flex-shrink-0", ("text-claude" if isClaude else "text-primary"))} />
                {isClaude and hasClaude and <DropdownMenu>
                    <DropdownMenuTrigger asChild={True}>
                        <Button variant="ghost" size="xs" className="gap-1.5 text-xs font-medium text-foreground min-w-0 max-w-[180px] px-1.5">
                            <span className="truncate">{_activeThreadTitle(claudeChat)}</span>
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-2.5 rotate-90 flex-shrink-0 text-muted-foreground" />
                        </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-[280px]">
                        <DropdownMenuItem onClick={lambda -> None { claudeChat.startNewThread(); }}>
                            <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-3 text-claude" />
                            <span className="text-xs">New Thread</span>
                        </DropdownMenuItem>
                        {(claudeChat.threads or []).length > 0 and <DropdownMenuSeparator /> or None}
                        {(claudeChat.threads or []).map(lambda (t: Any) -> Any {
                            isActiveThread = t.id == claudeChat.activeThreadId;
                            tTitle = t.title or "New Chat";
                            truncTitle = tTitle.slice(0, 35) + ("..." if tTitle.length > 35 else "");
                            return <DropdownMenuItem key={t.id}
                                className={cn(("bg-muted" if isActiveThread else ""))}
                                onClick={lambda -> None {
                                    loadFn = claudeChat.loadThread;
                                    loadFn.call(None, t.id);
                                }}>
                                <HugeiconsIcon icon={Message01Icon} strokeWidth={2} className="size-3 text-muted-foreground" />
                                <span className="text-xs truncate flex-1">{truncTitle}</span>
                                {t.branch and <Badge variant="outline" className="ml-auto text-[8px] h-[14px] px-1 text-muted-foreground">{t.branch}</Badge> or None}
                            </DropdownMenuItem>;
                        })}
                    </DropdownMenuContent>
                </DropdownMenu> or <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                    {"AI Chat"}
                </span>}
            </div>
            <div className="flex items-center gap-1.5">
                {hasClaude and claudeChat.claudeAvailable and <div className="flex items-center rounded-md border border-border bg-background">
                    <Button variant="ghost" size="xs"
                        className={cn("text-[10px] px-2 h-5 rounded-l-md rounded-r-none", ("bg-primary text-primary-foreground hover:bg-primary" if not isClaude else "bg-transparent text-muted-foreground"))}
                        onClick={lambda -> None { if isClaude { claudeChat.toggleProvider(); } }}>
                        {"JacCoder"}
                    </Button>
                    <Button variant="ghost" size="xs"
                        className={cn("text-[10px] px-2 h-5 rounded-r-md rounded-l-none", ("bg-claude text-claude-foreground hover:bg-claude" if isClaude else "bg-transparent text-muted-foreground"))}
                        onClick={lambda -> None { if not isClaude { claudeChat.toggleProvider(); } }}>
                        {"Claude"}
                    </Button>
                </div> or None}
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button size="icon-xs" variant="ghost" className="text-muted-foreground"
                            onClick={lambda -> None { activeChat.clearChat(); }}
                            disabled={activeChat.messages.length == 0}>
                            <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent>{"Clear chat"}</TooltipContent>
                </Tooltip>
            </div>
        </div>

        <div className="relative flex-1 min-h-0">
        <div ref={activeChat.scrollRef} className="absolute inset-0 overflow-y-auto overflow-x-hidden px-4 py-3" role="log" aria-label="Chat messages" aria-live="polite">
            {activeChat.messages.length == 0 and <div className="flex flex-col items-center justify-center h-full gap-4 px-4">
                <div className="w-14 h-14 rounded-2xl bg-muted/50 border border-border flex items-center justify-center">
                    <HugeiconsIcon icon={AiChat02Icon} strokeWidth={1.5} className={cn("size-7", ("text-claude" if isClaude else "text-primary"))} />
                </div>
                <div className="text-center space-y-1">
                    <p className="text-sm font-medium text-foreground">
                        {("Claude Code" if isClaude else "AI Assistant")}
                    </p>
                    <p className="text-[13px] text-muted-foreground max-w-[300px] leading-relaxed">
                        {("Ask Claude to edit files, run commands, or explain code." if isClaude
                          else "Describe what you want to build or change.")}
                    </p>
                </div>
                <div className="flex flex-col gap-2 w-full max-w-[300px]">
                    {_SUGGESTIONS.map(lambda (s: Any, i: int) -> Any {
                        return <Button key={String(i)} variant="outline" size="sm"
                            className="justify-start text-left h-auto py-2 px-3 text-[13px] text-muted-foreground hover:text-foreground"
                            onClick={lambda -> None {
                                inputValue = s.text;
                            }}>
                            <HugeiconsIcon icon={s.icon} strokeWidth={2} className="size-3.5 mr-2 flex-shrink-0" />
                            <span className="truncate">{s.label}</span>
                        </Button>;
                    })}
                </div>
            </div> or None}

            <div className="flex flex-col gap-2 min-w-0 max-w-full">
                {activeChat.messages.map(lambda (msg: Any, idx: int) -> Any {
                    if msg.role == "user" {
                        return <UserMessage key={String(idx)} msg={msg} msgIdx={idx} onResend={activeChat.resendMessage} isLoading={activeChat.isLoading} />;
                    }
                    if msg.role == "error" {
                        return <div key={String(idx)} className="py-1.5 pl-3 border-l-2 border-destructive/50">
                            <div className="flex items-center gap-1.5 mb-0.5">
                                <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-[13px] text-destructive" />
                                <span className="text-xs font-semibold text-destructive">Error</span>
                            </div>
                            <span className="text-sm leading-relaxed text-destructive/70 whitespace-pre-wrap">{msg.content}</span>
                        </div>;
                    }
                    if msg.isBuildBlock {
                        blockActivities = msg.activities or [];
                        if isClaude {
                            return <CompletedBuildBlock key={String(idx)} activities={blockActivities} colorClass="claude" />;
                        }
                        return <CompletedBuildBlock key={String(idx)} activities={blockActivities} colorClass="primary" />;
                    }
                    if msg.isStreaming {
                        if isClaude {
                            return <ClaudeStreamingMessage key={String(idx)} msg={msg} />;
                        }
                        return <div key={String(idx)} className="py-1">
                            <div className="flex items-center gap-2 py-1">
                                <Spinner className="size-3 text-primary" />
                                <span className="text-xs font-medium text-primary">Building...</span>
                            </div>
                            <ActivityTimeline activities={msg.activities or []} animated={True} />
                        </div>;
                    }
                    return <AssistantMessage key={String(idx)} msg={msg} isClaude={isClaude} onRevert={activeChat.revertToMessage if not isClaude else None} onOpenDiff={onOpenDiff} />;
                })}
            </div>
        </div>

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

        <div className="flex-shrink-0 px-3 pt-2 pb-3 border-t border-border bg-background min-w-0 overflow-hidden">
            <div className="rounded-xl border border-border bg-card px-3 pt-2 pb-2 focus-within:border-primary/50 focus-within:ring-1 focus-within:ring-primary/20 transition-colors min-w-0 overflow-hidden">
                {isClaude and hasClaude and claudeChat.envMode and <div className="flex items-center gap-1.5 mb-1.5 px-0.5">
                    <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-[11px] text-muted-foreground" />
                    {claudeChat.activeThreadId and <span className="text-[10px] text-muted-foreground">
                        {claudeChat.threadBranch or "main"}
                    </span> or None}
                    {not claudeChat.activeThreadId and claudeChat.envMode == "worktree" and <Select
                        value={claudeChat.threadBranch or "main"}
                        onValueChange={lambda (val: Any) -> None { if val { claudeChat.setThreadBranch(val); } }}
                    >
                        <SelectTrigger size="sm" className="w-[130px] h-[22px] text-[10px] bg-background border-border text-foreground">
                            <SelectValue placeholder="Base branch" />
                        </SelectTrigger>
                        <SelectContent>
                            {gitBranchList.map(lambda (b: Any) -> Any {
                                bName = b.name if b.name else String(b);
                                return <SelectItem key={bName} value={bName} className="text-[10px]">{bName}</SelectItem>;
                            })}
                        </SelectContent>
                    </Select> or None}
                    {not claudeChat.activeThreadId and claudeChat.envMode != "worktree" and <span className="text-[10px] text-muted-foreground">
                        {claudeChat.threadBranch or "main"}
                    </span> or None}
                    {claudeChat.threadWorktreePath and <Badge variant="outline" className="text-claude border-claude/30 text-[9px] h-[14px] px-1">worktree</Badge> or None}
                    <div className="flex-1" />
                    {not claudeChat.activeThreadId and not claudeChat.isLoading and <div className="flex items-center rounded-md border border-border">
                        <Button variant="ghost" size="xs"
                            className={cn("text-[9px] px-1.5 h-4 rounded-l-md rounded-r-none", ("bg-claude/20 text-claude" if claudeChat.envMode == "local" else "text-muted-foreground"))}
                            onClick={lambda -> None { claudeChat.setEnvMode("local"); }}>
                            {"Local"}
                        </Button>
                        <Button variant="ghost" size="xs"
                            className={cn("text-[9px] px-1.5 h-4 rounded-r-md rounded-l-none", ("bg-claude/20 text-claude" if claudeChat.envMode == "worktree" else "text-muted-foreground"))}
                            onClick={lambda -> None { claudeChat.setEnvMode("worktree"); }}>
                            {"Worktree"}
                        </Button>
                    </div> or None}
                </div> or None}
                {pendingImages.length > 0 and <div className="flex flex-wrap gap-1.5 mb-2">
                    {pendingImages.map(lambda (img: Any, i: int) -> Any {
                        return <div key={String(i)} className="relative group/img">
                            <img src={img.data_url} alt={img.name or "image"} className="h-14 w-14 rounded-md object-cover border border-border" />
                            <button
                                type="button"
                                onClick={lambda -> None { removeImage(i); }}
                                className="absolute -top-1 -right-1 size-4 rounded-full bg-destructive text-destructive-foreground flex items-center justify-center text-[10px] opacity-0 group-hover/img:opacity-100 transition-opacity">
                                <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-2.5" />
                            </button>
                        </div>;
                    })}
                </div> or None}
                <Textarea
                    ref={inputRef}
                    value={inputValue}
                    onChange={lambda (e: Any) { inputValue = e.currentTarget.value; }}
                    onKeyDown={handleKeyDown}
                    onPaste={handlePaste}
                    placeholder={placeholderText}
                    disabled={activeChat.isLoading}
                    className="min-h-[36px] max-h-[120px] w-full resize-none border-none !bg-transparent p-0 text-sm text-foreground placeholder:text-muted-foreground focus-visible:ring-0 focus-visible:ring-offset-0 focus-visible:outline-none rounded-none shadow-none"
                    rows={1}
                    aria-label="Message input"
                    name="Message-input"
                />
                <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    multiple={True}
                    onChange={handleFileSelect}
                    className="hidden"
                />
                <div className="flex items-center justify-between mt-1.5">
                    <div className="flex items-center gap-1">
                        <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost"
                                    className="text-muted-foreground hover:text-foreground"
                                    onClick={lambda -> None { if fileInputRef.current { fileInputRef.current.click(); } }}
                                    disabled={activeChat.isLoading}>
                                    <HugeiconsIcon icon={ImageAdd01Icon} strokeWidth={2} className="size-3.5" />
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Attach image"}</TooltipContent>
                        </Tooltip>
                        {activeTab and <Badge variant="outline" className="text-[10px] h-5 gap-1 text-muted-foreground">
                            {activeFileName}
                        </Badge> or None}
                    </div>
                    <div className="flex items-center gap-1.5">
                        {activeChat.isLoading and <Button size="icon-xs" variant="ghost"
                            className="text-destructive hover:text-destructive hover:bg-destructive/10 rounded-lg"
                            onClick={lambda -> None {
                                if isClaude and claudeChat {
                                    claudeChat.interruptClaude();
                                } else {
                                    if activeChat.stopAgent { activeChat.stopAgent(); }
                                }
                            }}
                            aria-label="Stop generation">
                            <HugeiconsIcon icon={StopIcon} strokeWidth={2} className="size-3.5" />
                        </Button> or <Button size="icon-sm"
                            className={cn("rounded-lg", ("bg-claude hover:bg-claude/90" if isClaude else "bg-primary hover:bg-primary/80"))}
                            onClick={lambda -> None { handleSend(); }}
                            disabled={not inputValue.trim() and pendingImages.length == 0}
                            aria-label="Send message">
                            <HugeiconsIcon icon={SentIcon} strokeWidth={2} className="size-3.5" />
                        </Button>}
                    </div>
                </div>
            </div>
        </div>
    </div>;
}
