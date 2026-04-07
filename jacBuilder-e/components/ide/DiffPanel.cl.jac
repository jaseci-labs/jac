"""Diff panel — per-file side-by-side diff view like VS Code."""

import from react { useState, useEffect }
import from "..ui.scroll-area" { ScrollArea }
import from "..ui.badge" { Badge }
import from "..ui.button" { Button }
import from "..ui.spinner" { Spinner }
import from "..ui.select" { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from "..ui.tooltip" { Tooltip, TooltipTrigger, TooltipContent }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GitCompareIcon, Refresh01Icon, File01Icon, AlertCircleIcon,
    ArrowLeft01Icon, ArrowRight01Icon, Tick02Icon
}

def _splitDiffByFile(allLines: list) -> list {
    if not allLines or allLines.length == 0 { return []; }
    files: list = [];
    currentPath = "";
    currentLines: list = [];
    line = "";
    bIdx = 0;
    i = 0;
    while i < allLines.length {
        line = allLines[i];
        if line.startsWith("diff --git ") {
            if currentPath {
                files.push({"path": currentPath, "lines": currentLines});
            }
            bIdx = line.indexOf(" b/");
            currentPath = "";
            if bIdx >= 0 { currentPath = line.slice(bIdx + 3); }
            currentLines = [];
        } else {
            currentLines.push(line);
        }
        i = i + 1;
    }
    if currentPath {
        files.push({"path": currentPath, "lines": currentLines});
    }
    return files;
}

def _doFlush(removes: list, adds: list, leftOut: list, rightOut: list) -> dict {
    maxLen = Math.max(removes.length, adds.length);
    j = 0;
    while j < maxLen {
        if j < removes.length {
            leftOut.push(removes[j]);
        } else {
            leftOut.push({"num": "", "content": "", "type": "blank"});
        }
        if j < adds.length {
            rightOut.push(adds[j]);
        } else {
            rightOut.push({"num": "", "content": "", "type": "blank"});
        }
        j = j + 1;
    }
    return {"removes": [], "adds": []};
}

def _buildSideBySide(fileLines: list) -> dict {
    left: list = [];
    right: list = [];
    leftNum = 0;
    rightNum = 0;
    removes: list = [];
    adds: list = [];
    line = "";
    content = "";
    atParts: list = [];
    rangePart = "";
    ranges: list = [];
    oldPart = "";
    newPart = "";
    parsedLeft = 0;
    parsedRight = 0;
    flushed: dict = {};
    isSkip = False;

    i = 0;
    while i < fileLines.length {
        line = fileLines[i];
        isSkip = line.startsWith("---") or line.startsWith("+++") or line.startsWith("index ");

        if not isSkip {
            if line.startsWith("@@") {
                flushed = _doFlush(removes, adds, left, right);
                removes = flushed.removes;
                adds = flushed.adds;
                atParts = line.split("@@");
                rangePart = "";
                if atParts.length >= 2 { rangePart = atParts[1].trim(); }
                ranges = rangePart.split(" ");
                oldPart = "";
                newPart = "";
                if ranges.length > 0 { oldPart = ranges[0]; }
                if ranges.length > 1 { newPart = ranges[1]; }
                parsedLeft = parseInt(oldPart.replace("-", ""));
                parsedRight = parseInt(newPart.replace("+", ""));
                leftNum = (parsedLeft - 1) if not isNaN(parsedLeft) else 0;
                rightNum = (parsedRight - 1) if not isNaN(parsedRight) else 0;
                left.push({"num": "", "content": line, "type": "hunk"});
                right.push({"num": "", "content": line, "type": "hunk"});
            } elif line.startsWith("-") {
                leftNum = leftNum + 1;
                removes.push({"num": String(leftNum), "content": line.slice(1), "type": "removed"});
            } elif line.startsWith("+") {
                rightNum = rightNum + 1;
                adds.push({"num": String(rightNum), "content": line.slice(1), "type": "added"});
            } else {
                flushed = _doFlush(removes, adds, left, right);
                removes = flushed.removes;
                adds = flushed.adds;
                leftNum = leftNum + 1;
                rightNum = rightNum + 1;
                content = line;
                if line.startsWith(" ") { content = line.slice(1); }
                left.push({"num": String(leftNum), "content": content, "type": "context"});
                right.push({"num": String(rightNum), "content": content, "type": "context"});
            }
        }

        i = i + 1;
    }

    flushed = _doFlush(removes, adds, left, right);
    return {"left": left, "right": right};
}

def DiffCell(props: Any) -> Any {
    line = props.line;

    if not line { return <div className="h-[22px]" />; }

    lineType = line.type or "context";
    num = line.num or "";
    content = line.content or "";

    rowCls = "bg-transparent";
    textCls = "text-foreground";
    numCls = "text-muted-foreground";

    if lineType == "removed" {
        rowCls = "bg-destructive/15";
        textCls = "text-destructive";
        numCls = "text-destructive/70";
    } elif lineType == "added" {
        rowCls = "bg-success/15";
        textCls = "text-success";
        numCls = "text-success/70";
    } elif lineType == "hunk" {
        rowCls = "bg-info/10";
        textCls = "text-info";
        numCls = "text-info/70";
    } elif lineType == "blank" {
        rowCls = "bg-muted/40";
    }

    return <div className={cn("flex font-mono items-center h-[22px] leading-[22px]", rowCls)}>
        <span className={cn("text-[10px] w-8 text-right pr-1 select-none flex-shrink-0 leading-[22px]", numCls)}>
            {num}
        </span>
        <span className={cn("text-[11px] whitespace-pre pl-1 leading-[22px]", (textCls if lineType != "blank" else "text-transparent"))}>
            {content}
        </span>
    </div>;
}

def DiffFileTabs(props: Any) -> Any {
    files = props.files or [];
    selectedIdx = props.selectedIdx or 0;
    onSelect = props.onSelect;
    if files.length == 0 { return None; }

    return <div className="flex flex-wrap gap-1 px-3 py-1.5 border-b border-border bg-muted/30">
        {files.map(lambda (f: Any, i: int) -> Any {
            pathParts = (f.path or "").split("/");
            fileName = pathParts[pathParts.length - 1];
            additions = f.additions or 0;
            deletions = f.deletions or 0;
            isSelected = i == selectedIdx;
            selectFn = onSelect;

            return <button key={String(i)}
                className={cn(
                    "inline-flex items-center gap-1 px-2 py-1 rounded-md text-[11px] font-medium transition-colors cursor-pointer",
                    (isSelected and "bg-background text-foreground shadow-sm border border-border" or "text-muted-foreground hover:text-foreground hover:bg-accent")
                )}
                title={f.path or ""}
                onClick={lambda -> None { selectFn.call(None, i); }}>
                <HugeiconsIcon icon={File01Icon} strokeWidth={2} className="size-3 shrink-0" />
                <span className="truncate max-w-[140px]">{fileName}</span>
                {additions > 0 and <span className="text-success text-[10px] font-mono">{"+" + String(additions)}</span> or None}
                {deletions > 0 and <span className="text-destructive text-[10px] font-mono">{"-" + String(deletions)}</span> or None}
            </button>;
        })}
    </div>;
}

def:pub DiffPanel(props: Any) -> Any {
    git = props.git;
    initialMode = props.initialMode or "last_commit";
    has diffData: Any = None;
    has isLoadingDiff: bool = False;
    has diffMode: str = initialMode;
    has diffError: str = "";
    has selectedFileIdx: int = 0;

    useEffect(lambda -> None {
        loadDiff();
    }, [diffMode]);

    async def loadDiff() -> None {
        if not git { return; }
        isLoadingDiff = True;
        diffError = "";
        selectedFileIdx = 0;
        try {
            result = None;
            if diffMode == "working" {
                result = await git.getWorkingDiff();
            } elif diffMode == "staged" {
                result = await git.getStagedDiff();
            } elif diffMode == "last_commit" {
                result = await git.getLastCommitDiff();
            } else {
                result = await git.getDiff();
            }
            if result and result.success {
                diffData = result;
            } elif result {
                diffError = result.error or "Failed to load diff";
                diffData = None;
            }
        } except Exception as e {
            console.error("[DiffPanel] Error loading diff:", e);
            diffError = String(e);
            diffData = None;
        }
        isLoadingDiff = False;
    }

    diffText = "";
    diffFiles: list = [];
    if diffData {
        diffText = diffData.diff_text or "";
        diffFiles = diffData.files or [];
    }

    _newline = String.fromCharCode(10);
    allDiffLines = diffText.split(_newline) if diffText else [];
    parsedFiles = _splitDiffByFile(allDiffLines);

    sideBySide = {"left": [], "right": []};
    safeIdx = selectedFileIdx;
    if safeIdx >= parsedFiles.length { safeIdx = 0; }
    if parsedFiles.length > 0 {
        sideBySide = _buildSideBySide(parsedFiles[safeIdx].lines);
    }

    leftLines = sideBySide.left or [];
    rightLines = sideBySide.right or [];

    selectedPath = "";
    if safeIdx < parsedFiles.length {
        selectedPath = parsedFiles[safeIdx].path or "";
    }

    def handleFileSelect(idx: int) -> None {
        selectedFileIdx = idx;
    }

    def handlePrevFile() -> None {
        if selectedFileIdx > 0 {
            selectedFileIdx = selectedFileIdx - 1;
        }
    }

    def handleNextFile() -> None {
        if selectedFileIdx < diffFiles.length - 1 {
            selectedFileIdx = selectedFileIdx + 1;
        }
    }

    return <div className="flex flex-col h-full bg-card rounded-lg overflow-hidden">
        <div className="flex items-center justify-between px-3 h-9 flex-shrink-0 border-b border-border bg-muted/30">
            <div className="flex items-center gap-1.5">
                <HugeiconsIcon icon={GitCompareIcon} strokeWidth={2} className="size-3.5 text-primary" />
                <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{"Diff"}</span>
                {diffFiles.length > 0 and not isLoadingDiff and <Badge variant="secondary" className="ml-1 text-[10px] h-4 px-1.5">
                    {String(diffFiles.length) + " file" + ("s" if diffFiles.length != 1 else "")}
                </Badge> or None}
            </div>
            <div className="flex items-center gap-1">
                {diffFiles.length > 1 and <div className="flex items-center gap-0.5 mr-1">
                    <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="ghost"
                                onClick={lambda -> None { handlePrevFile(); }}
                                disabled={selectedFileIdx <= 0}>
                                <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} className="size-3" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{"Previous file"}</TooltipContent>
                    </Tooltip>
                    <span className="text-[9px] text-muted-foreground font-mono">{String(safeIdx + 1) + "/" + String(diffFiles.length)}</span>
                    <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button size="icon-xs" variant="ghost"
                                onClick={lambda -> None { handleNextFile(); }}
                                disabled={selectedFileIdx >= diffFiles.length - 1}>
                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent>{"Next file"}</TooltipContent>
                    </Tooltip>
                </div> or None}
                <Select value={diffMode} onValueChange={lambda (val: str) -> None { if val { diffMode = val; } }}>
                    <SelectTrigger size="sm" className="w-[120px] h-6 text-[11px] bg-card border-border text-foreground">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="last_commit">{"Last Commit"}</SelectItem>
                        <SelectItem value="working">{"Working"}</SelectItem>
                        <SelectItem value="staged">{"Staged"}</SelectItem>
                    </SelectContent>
                </Select>
                <Button size="icon-xs" variant="ghost"
                    onClick={lambda -> None { loadDiff(); }}
                    disabled={isLoadingDiff}>
                    {isLoadingDiff and <Spinner className="size-2.5" /> or <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />}
                </Button>
            </div>
        </div>

        <DiffFileTabs files={diffFiles} selectedIdx={safeIdx} onSelect={handleFileSelect} />

        {diffError and not isLoadingDiff and <div className="flex items-center gap-2 px-3 py-2.5 bg-destructive/10 border-b border-destructive/20">
            <HugeiconsIcon icon={AlertCircleIcon} strokeWidth={2} className="size-4 text-destructive shrink-0" />
            <span className="text-xs text-destructive/80">{diffError}</span>
        </div> or None}

        {leftLines.length == 0 and not isLoadingDiff and not diffError and <div className="flex-1 flex flex-col items-center justify-center py-12">
            <div className="size-12 rounded-xl bg-muted flex items-center justify-center mb-3">
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={1.5} className="size-6 text-success" />
            </div>
            <p className="text-sm font-medium text-foreground mb-1">{"No changes"}</p>
            <p className="text-xs text-muted-foreground">{"Everything is up to date"}</p>
        </div> or None}

        {isLoadingDiff and <div className="flex-1 flex flex-col items-center justify-center">
            <Spinner className="size-5 text-primary" />
            <span className="text-xs text-muted-foreground mt-2">{"Loading diff..."}</span>
        </div> or None}

        {leftLines.length > 0 and not isLoadingDiff and <div className="flex flex-col flex-1 min-h-0">
            <div className="flex h-7 flex-shrink-0 border-b border-border bg-muted/30">
                <div className="flex-1 flex items-center px-3 border-r border-border">
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-destructive">{"Original"}</span>
                    {selectedPath and <span className="text-[10px] text-muted-foreground ml-2 truncate font-mono">{selectedPath}</span> or None}
                </div>
                <div className="flex-1 flex items-center px-3">
                    <span className="text-[10px] font-semibold uppercase tracking-wider text-success">{"Modified"}</span>
                    {selectedPath and <span className="text-[10px] text-muted-foreground ml-2 truncate font-mono">{selectedPath}</span> or None}
                </div>
            </div>
            <ScrollArea className="flex-1 min-h-0">
                {leftLines.map(lambda(leftLine: Any, idx: int) -> Any {
                    rightLine = rightLines[idx];
                    return <div key={String(idx)} className="flex">
                        <div className="flex-1 min-w-0 border-r border-border overflow-hidden">
                            <DiffCell line={leftLine} />
                        </div>
                        <div className="flex-1 min-w-0 overflow-hidden">
                            <DiffCell line={rightLine} />
                        </div>
                    </div>;
                })}
            </ScrollArea>
        </div> or None}
    </div>;
}
