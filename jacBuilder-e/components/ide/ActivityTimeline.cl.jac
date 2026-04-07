"""Activity timeline — Claude Code-style tool calls with human-readable labels,
collapsible thinking blocks, agent narration, and IN/OUT cards."""

import from react { useState }
import from "...lib.utils" { cn }
import from "..ui.hover-card" { HoverCard, HoverCardTrigger, HoverCardContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Tick02Icon, Alert02Icon, AlertCircleIcon,
    PlayIcon, Loading01Icon, File01Icon, Tick02Icon as FileCheckIcon,
    ComputerTerminal01Icon, Search01Icon, PencilEdit01Icon, ViewIcon,
    Globe02Icon, AiChat02Icon, CodeIcon, Diamond01Icon,
    BubbleChatIcon, Wrench01Icon, File02Icon
}
import from .DiffBlock { DiffBlock }

"""Get icon for a tool category (human-readable name)."""
def _getCategoryIcon(category: str, size: str, isDone: bool) -> Any {
    doneCls = " opacity-60" if isDone else "";
    if category == "Read" {
        return <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className={cn(size, "text-info" + doneCls)} />;
    } elif category == "Edit" or category == "Write" {
        return <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className={cn(size, "text-warning" + doneCls)} />;
    } elif category == "Bash" {
        return <HugeiconsIcon icon={ComputerTerminal01Icon} strokeWidth={2} className={cn(size, "text-success" + doneCls)} />;
    } elif category == "Search" or category == "Find" {
        return <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className={cn(size, "text-claude" + doneCls)} />;
    } elif category == "List" {
        return <HugeiconsIcon icon={File01Icon} strokeWidth={2} className={cn(size, "text-muted-foreground" + doneCls)} />;
    } elif category == "Jac docs" or category == "Check" or category == "Run" or category == "Validate" {
        return <HugeiconsIcon icon={Diamond01Icon} strokeWidth={2} className={cn(size, "text-info" + doneCls)} />;
    } elif category == "Agent" {
        return <HugeiconsIcon icon={AiChat02Icon} strokeWidth={2} className={cn(size, "text-destructive" + doneCls)} />;
    } elif category == "Git" {
        return <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className={cn(size, "text-orange-400" + doneCls)} />;
    } elif category == "Web search" or category == "Web fetch" {
        return <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className={cn(size, "text-info" + doneCls)} />;
    } elif category == "Think" {
        return <HugeiconsIcon icon={BubbleChatIcon} strokeWidth={2} className={cn(size, "text-purple-400" + doneCls)} />;
    } elif category == "Symbol" or category == "Analyze" {
        return <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className={cn(size, "text-cyan-400" + doneCls)} />;
    } elif category == "Scaffold" {
        return <HugeiconsIcon icon={File02Icon} strokeWidth={2} className={cn(size, "text-success" + doneCls)} />;
    } elif category == "Todos" {
        return <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className={cn(size, "text-blue-400" + doneCls)} />;
    } elif category == "Question" {
        return <HugeiconsIcon icon={BubbleChatIcon} strokeWidth={2} className={cn(size, "text-amber-400" + doneCls)} />;
    } else {
        return <HugeiconsIcon icon={Wrench01Icon} strokeWidth={2} className={cn(size, "text-muted-foreground" + doneCls)} />;
    }
}


"""Render a collapsible thinking block."""
def ThinkingBlock(props: Any) -> Any {
    act = props.act;
    animated = props.animated or False;
    has expanded: bool = False;

    durationMs = act.duration_ms or 0;
    durationLabel = "";
    if durationMs >= 1000 {
        durationLabel = String(Math.round(durationMs / 1000)) + "s";
    } elif durationMs > 0 {
        durationLabel = "<1s";
    }

    headerLabel = "Thought" + (" for " + durationLabel if durationLabel else "") + ("" if act.closed else "...");

    return <div className={cn("flex flex-col", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
        <div className="flex items-center gap-1.5 py-0.5 cursor-pointer select-none" onClick={lambda -> None { expanded = not expanded; }}>
            <span className="size-2 rounded-full bg-purple-400 shrink-0"></span>
            <span className="text-xs font-mono text-purple-400">{headerLabel}</span>
            <HugeiconsIcon icon={PlayIcon} strokeWidth={2.5} className={cn("size-2 text-muted-foreground transition-transform", ("rotate-90" if expanded else ""))} />
        </div>
        {expanded and <div className="ml-4 pl-2 border-l border-purple-400/20 py-1">
            <span className="text-[11px] font-mono text-muted-foreground whitespace-pre-wrap break-all">{act.fullContent or act.message or ""}</span>
        </div> or None}
    </div>;
}


"""Render a tool call card with optional IN/OUT expansion."""
def ToolCallCard(props: Any) -> Any {
    act = props.act;
    animated = props.animated or False;
    has showDetail: bool = False;

    cardCategory = act.category or act.tool or "Tool";
    cardLabel = act.label or "";
    cardDone = act.status == "done";
    cardRunning = act.status == "running";
    cardArgs = act.args or {};
    cardResult = act.result or "";
    cardSummary = act.summary or "";
    cardDurationMs = act.duration_ms or 0;

    cardDurStr = "";
    if cardDurationMs > 0 {
        if cardDurationMs >= 1000 {
            cardDurStr = String((cardDurationMs / 1000).toFixed(1)) + "s";
        } else {
            cardDurStr = String(cardDurationMs) + "ms";
        }
    }

    cardIcon = _getCategoryIcon(cardCategory, "size-3", cardDone);

    hasDetail = Object.keys(cardArgs).length > 0 or cardResult.length > 0;

    return <div className={cn("flex flex-col", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
        <div className={cn("flex items-center gap-1.5 py-1 min-w-0", ("cursor-pointer" if hasDetail else "cursor-default"))} onClick={lambda -> None { if hasDetail { showDetail = not showDetail; } }}>
            {cardIcon}
            <span className={cn("text-xs font-semibold shrink-0", ("text-muted-foreground" if cardDone else "text-foreground"))}>{cardCategory}</span>
            {cardLabel and <span className={cn("text-xs font-mono", ("text-muted-foreground opacity-70" if cardDone else "text-foreground/80"))}>{cardLabel}</span> or None}
            {cardSummary and <span className="text-[10px] font-mono text-success/80 bg-success/10 rounded px-1 py-px">{cardSummary}</span> or None}
            {cardRunning and <HugeiconsIcon icon={Loading01Icon} strokeWidth={2} className="size-2.5 animate-spin text-primary ml-auto" /> or None}
            {cardDurStr and <span className="text-[11px] font-mono text-muted-foreground opacity-50 ml-auto">{cardDurStr}</span> or None}
            {hasDetail and <HugeiconsIcon icon={PlayIcon} strokeWidth={2.5} className={cn("size-2 text-muted-foreground transition-transform ml-1", ("rotate-90" if showDetail else ""))} /> or None}
        </div>
        {showDetail and <div className="ml-4 mt-0.5 mb-1 min-w-0 overflow-hidden">
            {(cardCategory == "Edit" or cardCategory == "Write") and (cardArgs.OLD or cardArgs.NEW or cardArgs.CONTENT) and <div>
                <DiffBlock
                    oldStr={cardArgs.OLD or ""}
                    newStr={cardArgs.NEW or cardArgs.CONTENT or ""}
                    fileName={cardArgs.FILE or cardArgs.PATH or ""}
                    isWrite={cardCategory == "Write"}
                />
                {cardResult and <div className="rounded-md bg-muted/40 border border-border/50 p-2 mt-1">
                    <span className="text-[10px] font-semibold text-muted-foreground uppercase">result</span>
                    <span className="text-[11px] font-mono text-foreground/70 break-all whitespace-pre-wrap max-h-[80px] overflow-y-auto block mt-0.5">{cardResult.substring(0, 500)}</span>
                </div> or None}
            </div> or <div className="rounded-md bg-muted/40 border border-border/50 p-2 space-y-1.5">
                {Object.keys(cardArgs).length > 0 and <div className="flex flex-col gap-0.5">
                    {Object.keys(cardArgs).map(lambda (argKey: str) -> Any {
                        return <div key={argKey} className="flex gap-1.5 items-start">
                            <span className="text-[10px] font-semibold text-muted-foreground uppercase shrink-0 mt-0.5">{argKey}</span>
                            <span className="text-[11px] font-mono text-foreground/80 break-all">{String(cardArgs[argKey]).substring(0, 300)}</span>
                        </div>;
                    })}
                </div> or None}
                {cardResult and <div className="flex flex-col gap-0.5 pt-1 border-t border-border/30">
                    <span className="text-[10px] font-semibold text-muted-foreground uppercase">result</span>
                    <span className="text-[11px] font-mono text-foreground/70 break-all whitespace-pre-wrap max-h-[120px] overflow-y-auto">{cardResult.substring(0, 500)}</span>
                </div> or None}
            </div>}
        </div> or None}
    </div>;
}


def:pub ActivityTimeline(props: Any) -> Any {
    activities = props.activities or [];
    animated = props.animated or False;

    if activities.length == 0 { return None; }

    return <div className="flex flex-col gap-1 min-w-0">
        {activities.map(lambda (act: Any, idx: int) -> Any {
            actType = act.type or "";

            if actType == "file_promoted" {
                fpParts = (act.path or "").split("/");
                fpName = fpParts[fpParts.length - 1];
                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5 mt-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <HugeiconsIcon icon={FileCheckIcon} strokeWidth={2} className="size-2.5 text-success" />
                    <span className="text-xs font-mono text-success">{fpName}</span>
                </div>;
            } elif actType == "file_promoted_with_warning" {
                fwParts = (act.path or "").split("/");
                fwName = fwParts[fwParts.length - 1];
                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="size-2.5 text-warning" />
                    <span className="text-xs font-mono text-warning">{fwName}</span>
                </div>;
            } elif actType == "file_failed" {
                ffParts = (act.path or "").split("/");
                ffName = ffParts[ffParts.length - 1];
                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <HugeiconsIcon icon={AlertCircleIcon} strokeWidth={2} className="size-2.5 text-destructive" />
                    <span className="text-xs font-mono text-destructive">{ffName + " - fixing..."}  </span>
                </div>;
            } elif actType == "agent_text" {
                return <div key={String(idx)} className={cn("py-1", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <span className="text-xs text-foreground/90 leading-relaxed">{act.message or ""}</span>
                </div>;
            } elif actType == "llm_thought" {
                return <ThinkingBlock key={String(idx)} act={act} animated={animated} />;
            } elif actType == "llm_tool_call" {
                return <ToolCallCard key={String(idx)} act={act} animated={animated} />;
            } elif actType == "llm_steps_done" {
                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-2.5 text-green-400" />
                    <span className="text-xs font-mono text-green-400">{act.message or "done"}</span>
                </div>;
            } elif actType == "thinking" {
                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    <HugeiconsIcon icon={AiChat02Icon} strokeWidth={2} className="size-2.5 text-claude" />
                    <span className="text-xs font-mono text-claude">{act.message or "thinking..."}</span>
                </div>;
            } elif actType == "activity" {
                actToolName = act.tool or "";
                actLabel = act.message or act.detail or actToolName or "";
                actDone = (act.status or "") == "done";
                actErr = (act.status or "") == "error";
                actDurationMs = act.duration_ms or 0;

                actDurStr = "";
                if actDurationMs > 0 {
                    if actDurationMs >= 1000 {
                        actDurStr = String((actDurationMs / 1000).toFixed(1)) + "s";
                    } else {
                        actDurStr = String(actDurationMs) + "ms";
                    }
                }

                actIcon = <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-2.5 text-muted-foreground" />;
                actTextCls = "text-muted-foreground";
                if actErr {
                    actIcon = <HugeiconsIcon icon={AlertCircleIcon} strokeWidth={2} className="size-2.5 text-destructive" />;
                    actTextCls = "text-destructive";
                } elif actDone {
                    actIcon = <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-2.5 text-muted-foreground" />;
                    actTextCls = "text-muted-foreground";
                } else {
                    actIcon = <HugeiconsIcon icon={Loading01Icon} strokeWidth={2} className="size-2.5 animate-spin text-primary" />;
                    actTextCls = "text-foreground";
                }

                return <div key={String(idx)} className={cn("flex items-center gap-1.5 py-0.5", ("animate-in fade-in-0 slide-in-from-left-2 duration-[200ms]" if animated else ""))}>
                    {actIcon}
                    <span className={cn("text-xs font-mono", actTextCls, ("opacity-70" if actDone else ""))}>{actLabel}</span>
                    {actDurStr and <span className="text-[11px] font-mono text-muted-foreground opacity-50">{actDurStr}</span> or None}
                </div>;
            } else {
                return None;
            }
        })}
    </div>;
}
