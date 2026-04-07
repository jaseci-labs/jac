import from react { useEffect, useRef }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "...lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ComputerTerminal01Icon, ArrowDown01Icon, ArrowUp01Icon, Delete02Icon }

def:pub TerminalPanel(props: Any) -> Any {
    content = props.content or "";
    isCollapsed = props.isCollapsed or False;
    onToggle = props.onToggle;
    onClear = props.onClear;
    hideHeader = props.hideHeader or False;

    has terminalHeight: int = 178;
    has isDragging: bool = False;

    scrollRef = useRef(None);
    startYRef = useRef(0);
    startHRef = useRef(0);

    useEffect(lambda -> None {
        if scrollRef.current and not isCollapsed {
            viewport = scrollRef.current.querySelector("[data-viewport]");
            if viewport {
                viewport.scrollTop = viewport.scrollHeight;
            }
        }
    }, [content, isCollapsed]);

    def startResize(e: Any) -> None {
        e.preventDefault();
        e.stopPropagation();
        startYRef.current = e.clientY;
        startHRef.current = terminalHeight;
        isDragging = True;
        document.body.style.cursor = "row-resize";
        document.body.style.userSelect = "none";
    }

    def handleDragMove(e: Any) -> None {
        newH = startHRef.current - (e.clientY - startYRef.current);
        if newH < 80 { newH = 80; }
        if newH > 400 { newH = 400; }
        terminalHeight = newH;
    }

    def handleDragEnd(_: Any) -> None {
        isDragging = False;
        document.body.style.cursor = "";
        document.body.style.userSelect = "";
    }

    if hideHeader {
        return <div className="h-full bg-background overflow-hidden">
            <ScrollArea
                ref={scrollRef}
                className="h-full p-2"
            >
                <pre className="m-0 text-xs leading-[1.6] text-muted-foreground whitespace-pre-wrap break-all font-mono">
                    {content or "$ Waiting for output..."}
                </pre>
            </ScrollArea>
        </div>;
    }

    return <div className="border-t border-border bg-background flex-shrink-0">
        {isDragging and <div
            className="fixed inset-0 z-[9999] cursor-row-resize"
            onMouseMove={handleDragMove}
            onMouseUp={handleDragEnd}
        /> or None}
        <div
            className="h-1 bg-border hover:bg-primary/35 cursor-row-resize transition-colors"
            onMouseDown={startResize}
        />
        <div
            className={cn("flex items-center justify-between px-3 h-8 cursor-pointer select-none", (not isCollapsed and "border-b border-border" or ""))}
            onClick={onToggle}
        >
            <div className="flex items-center gap-2">
                <HugeiconsIcon icon={ComputerTerminal01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                <span className="text-[11px] font-semibold uppercase tracking-[0.06em] text-muted-foreground leading-none select-none">{"Terminal"}</span>
            </div>
            <div className="flex items-center gap-1">
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button
                            size="icon-xs"
                            variant="ghost"
                            onClick={lambda (e: Any) {
                                e.stopPropagation();
                                onClear();
                            }}
                        >
                            <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3 text-muted-foreground" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent side="top">{"Clear Terminal"}</TooltipContent>
                </Tooltip>
                {isCollapsed and <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3 text-muted-foreground" /> or <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-3 text-muted-foreground" />}
            </div>
        </div>
        {not isCollapsed and <ScrollArea
            ref={scrollRef}
            className="p-2"
            style={{"height": String(terminalHeight) + "px"}}
        >
            <pre className="m-0 text-xs leading-[1.6] text-muted-foreground whitespace-pre-wrap break-all font-mono">
                {content or "$ Waiting for output..."}
            </pre>
        </ScrollArea> or None}
    </div>;
}
