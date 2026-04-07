"""Terminal area with Output/Terminal tab switcher.
Wraps both the read-only log viewer (TerminalPanel) and interactive terminal (InteractiveTerminal)."""

import from react { useState, useRef }
import from "...lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ComputerTerminal01Icon, File02Icon }
import from "..ide.TerminalPanel" { TerminalPanel }
import from "..ide.InteractiveTerminal" { InteractiveTerminal }

"""Terminal area with Output/Terminal tabs and drag-to-resize."""
def:pub TerminalArea(props: Any) -> Any {
    content = props.content or "";
    isCollapsed = props.isCollapsed or False;
    onToggle = props.onToggle;
    onClear = props.onClear;
    userId = props.userId or "";
    projectId = props.projectId or "";
    controlledTab = props.activeTerminalTab or "";
    onTabChange = props.onTabChange;

    has internalTab: str = "output";
    activeTab = controlledTab or internalTab;

    def switchTab(tab: str) -> None {
        internalTab = tab;
        if onTabChange { onTabChange(tab); }
    }
    has termHeight: int = 200;
    has isDragging: bool = False;

    startYRef = useRef(0);
    startHRef = useRef(0);

    def startResize(e: Any) -> None {
        e.preventDefault();
        e.stopPropagation();
        startYRef.current = e.clientY;
        startHRef.current = termHeight;
        isDragging = True;
        document.body.style.cursor = "row-resize";
        document.body.style.userSelect = "none";
    }

    def handleDragMove(e: Any) -> None {
        newH = startHRef.current - (e.clientY - startYRef.current);
        if newH < 100 { newH = 100; }
        if newH > 600 { newH = 600; }
        termHeight = newH;
    }

    def handleDragEnd(_: Any) -> None {
        isDragging = False;
        document.body.style.cursor = "";
        document.body.style.userSelect = "";
    }

    if isCollapsed {
        return <div className="flex-shrink-0">
            <div
                className="h-[30px] flex items-center justify-between pl-3 pr-2 border-t border-border bg-card cursor-pointer select-none"
                onClick={onToggle}
            >
                <div className="flex items-center gap-2">
                    <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">Terminal</span>
                </div>
            </div>
        </div>;
    }

    return <div className="flex-shrink-0 flex flex-col border-t border-border" style={{"height": String(termHeight) + "px"}}>
        {isDragging and <div
            className="fixed inset-0 z-[9999] cursor-row-resize"
            onMouseMove={handleDragMove}
            onMouseUp={handleDragEnd}
        /> or None}
        <div
            className="h-1 bg-border hover:bg-primary/35 cursor-row-resize transition-colors flex-shrink-0"
            onMouseDown={startResize}
        />
        <div className="h-[30px] flex items-center justify-between pl-1 pr-2 bg-card border-b border-border flex-shrink-0">
            <div className="flex items-center gap-0">
                <button
                    className={cn(
                        "flex items-center gap-1 px-2.5 h-[30px] text-[11px] font-medium border-b-2 transition-colors",
                        ("border-primary text-foreground" if activeTab == "output" else "border-transparent text-muted-foreground hover:text-foreground")
                    )}
                    onClick={lambda { switchTab("output"); }}
                >
                    <HugeiconsIcon icon={File02Icon} strokeWidth={2} className="size-3" />
                    {"Output"}
                </button>
                <button
                    className={cn(
                        "flex items-center gap-1 px-2.5 h-[30px] text-[11px] font-medium border-b-2 transition-colors",
                        ("border-primary text-foreground" if activeTab == "terminal" else "border-transparent text-muted-foreground hover:text-foreground")
                    )}
                    onClick={lambda { switchTab("terminal"); }}
                >
                    <HugeiconsIcon icon={ComputerTerminal01Icon} strokeWidth={2} className="size-3" />
                    {"Terminal"}
                </button>
            </div>
            <div className="flex items-center gap-1">
                {onClear and activeTab == "output" and <button
                    className="text-[10px] text-muted-foreground hover:text-foreground px-1.5 py-0.5 rounded hover:bg-muted transition-colors"
                    onClick={onClear}
                >
                    {"Clear"}
                </button> or None}
                <button
                    className="text-[10px] text-muted-foreground hover:text-foreground px-1.5 py-0.5 rounded hover:bg-muted transition-colors"
                    onClick={onToggle}
                >
                    {"Collapse"}
                </button>
            </div>
        </div>
        <div className="flex-1 min-h-0 overflow-hidden">
            {activeTab == "output" and <TerminalPanel
                content={content}
                isCollapsed={False}
                onToggle={onToggle}
                onClear={onClear}
                hideHeader={True}
            /> or None}
            <InteractiveTerminal
                userId={userId}
                projectId={projectId}
                isVisible={activeTab == "terminal"}
            />
        </div>
    </div>;
}
