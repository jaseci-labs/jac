import from react { useState, useEffect, useRef, useCallback }
import from ..ui.input { Input }
import from ..ui.badge { Badge }
import from ..ui.button { Button }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.spinner { Spinner }
import from ...lib.utils { cn }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Search01Icon, File01Icon, Cancel01Icon, TextIcon,
    ArrowRight01Icon, SearchReplaceIcon, Tick02Icon
}
import from ...services.ideService { ideSearchFiles, ideReplaceInFiles }
import from ...utils.toast { notify }

def:pub SearchPanel(props: Any) -> Any {
    projectId = props.projectId or "";
    onNavigate = props.onNavigate;
    navHandler = onNavigate;

    has query: str = "";
    has replaceText: str = "";
    has showReplace: bool = False;
    has results: list = [];
    has isSearching: bool = False;
    has isReplacing: bool = False;
    has totalCount: int = 0;
    has caseSensitive: bool = False;
    has expandedFiles: Any = {};

    debounceRef = useRef(None);
    inputRef = useRef(None);

    useEffect(lambda -> None {
        if inputRef.current {
            inputRef.current.focus();
        }
    }, []);

    doSearch = useCallback(lambda(searchQuery: str, matchCase: bool) -> None {
        if not (searchQuery or "").trim() or not projectId {
            results = [];
            totalCount = 0;
            return;
        }
        isSearching = True;
        ideSearchFiles(projectId, searchQuery, matchCase).then(lambda(res: Any) {
            if res and res.success {
                results = res.results or [];
                totalCount = res.total or 0;
                fileMap = {};
                for r in res.results or [] {
                    if not fileMap[r.file] {
                        fileMap[r.file] = True;
                    }
                }
                expandedFiles = fileMap;
            } else {
                results = [];
                totalCount = 0;
            }
            isSearching = False;
        }).catch(lambda(err: Any) {
            results = [];
            totalCount = 0;
            isSearching = False;
        });
    }, [projectId]);

    useEffect(lambda -> None {
        if debounceRef.current {
            clearTimeout(debounceRef.current);
        }
        if not (query or "").trim() {
            results = [];
            totalCount = 0;
            return;
        }
        debounceRef.current = setTimeout(lambda {
            doSearch(query, caseSensitive);
        }, 400);
    }, [query, caseSensitive]);

    def handleNavigate(filePath: str, line: int) -> None {
        if navHandler {
            navHandler.call(None, filePath, line, 1);
        }
    }

    def toggleFile(filePath: str) -> None {
        newExpanded = Object.assign({}, expandedFiles);
        if newExpanded[filePath] {
            newExpanded[filePath] = undefined;
        } else {
            newExpanded[filePath] = True;
        }
        expandedFiles = newExpanded;
    }

    def clearSearch() -> None {
        query = "";
        replaceText = "";
        results = [];
        totalCount = 0;
        if inputRef.current {
            inputRef.current.focus();
        }
    }

    async def handleReplaceAll(fileFilter: str = "") -> None {
        if not (query or "").trim() or isReplacing { return; }
        isReplacing = True;
        res = await ideReplaceInFiles(projectId, query, replaceText, caseSensitive, fileFilter);
        isReplacing = False;
        if res and res.success {
            totalReplaced = res.total_replacements or 0;
            fileCount = 0;
            if res.replaced_files { fileCount = res.replaced_files.length; }
            notify(
                "Replace complete",
                String(totalReplaced) + " replacements in " + String(fileCount) + " files",
                "green"
            );
            doSearch(query, caseSensitive);
        } else {
            notify("Replace failed", (res and res.error) or "Unknown error", "red");
        }
    }

    grouped = {};
    fileOrder = [];
    for r in results {
        if not grouped[r.file] {
            grouped[r.file] = [];
            fileOrder.push(r.file);
        }
        grouped[r.file].push(r);
    }

    def highlightMatch(text: str, q: str) -> Any {
        if not (q or "").trim() or not text {
            return <span>{text or ""}</span>;
        }
        lowerText = text.toLowerCase();
        lowerQ = q.toLowerCase();
        idx = -1;
        if caseSensitive {
            idx = text.indexOf(q);
        } else {
            idx = lowerText.indexOf(lowerQ);
        }
        if idx == -1 {
            return <span>{text}</span>;
        }
        before = text.substring(0, idx);
        matchStr = text.substring(idx, idx + q.length);
        after = text.substring(idx + q.length);
        return <span>
            {before}
            <span className="bg-warning/40 text-warning-foreground rounded-sm px-px">{matchStr}</span>
            {after}
        </span>;
    }

    fileCount = fileOrder.length;

    return <div className="flex flex-col h-full overflow-hidden bg-card">
        <div className="px-3 pt-3 pb-2 flex flex-col gap-1.5">
            <div className="flex items-center gap-1">
                <Button size="icon-xs" variant="ghost"
                    className={cn("shrink-0", (showReplace and "text-primary" or "text-muted-foreground"))}
                    onClick={lambda -> None { showReplace = not showReplace; }}>
                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-2.5 transition-transform" style={{
                        "transform": "rotate(90deg)" if showReplace else "rotate(0deg)"
                    }} />
                </Button>
                <div className="flex flex-col gap-1.5 flex-1 min-w-0">
                    <div className="relative flex items-center gap-1">
                        <div className="relative flex-1">
                            <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3 absolute left-2 top-1/2 -translate-y-1/2 text-muted-foreground" />
                            <Input
                                ref={inputRef}
                                placeholder="Search"
                                value={query}
                                onChange={lambda e: Any { query = e.target.value; }}
                                className="pl-7 pr-7 h-[26px] text-xs bg-background text-foreground border-border"
                            />
                            {query and <button
                                onClick={clearSearch}
                                className="absolute right-1.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground bg-transparent border-0 cursor-pointer p-0.5"
                            >
                                <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-3" />
                            </button> or None}
                        </div>
                        <Button
                            variant={caseSensitive and "secondary" or "ghost"}
                            size="icon-xs"
                            onClick={lambda -> None { caseSensitive = not caseSensitive; }}
                            title="Match Case"
                            className={cn("shrink-0 h-[22px] w-[22px]", (caseSensitive and "text-primary bg-primary/15" or "text-muted-foreground"))}
                        >
                            <span className="text-[10px] font-bold">{"Aa"}</span>
                        </Button>
                    </div>
                    {showReplace and <div className="flex items-center gap-1">
                        <Input
                            placeholder="Replace"
                            value={replaceText}
                            onChange={lambda e: Any { replaceText = e.target.value; }}
                            className="flex-1 h-[26px] text-xs bg-background text-foreground border-border pl-2.5"
                        />
                        <Tooltip>
                            <TooltipTrigger asChild={True}>
                                <Button size="icon-xs" variant="ghost"
                                    className={cn("shrink-0 h-[22px] w-[22px]", (isReplacing and "text-muted-foreground" or "text-muted-foreground hover:text-foreground"))}
                                    onClick={lambda -> None { handleReplaceAll(); }}
                                    disabled={not (query or "").trim() or isReplacing}>
                                    {isReplacing and <Spinner className="size-3" /> or <HugeiconsIcon icon={SearchReplaceIcon} strokeWidth={2} className="size-3" />}
                                </Button>
                            </TooltipTrigger>
                            <TooltipContent>{"Replace All"}</TooltipContent>
                        </Tooltip>
                    </div> or None}
                </div>
            </div>
            {isSearching and <div className="flex items-center gap-1.5 px-1 pl-6">
                <Spinner className="size-3 text-primary" />
                <span className="text-[11px] text-muted-foreground">{"Searching..."}</span>
            </div> or None}
            {not isSearching and (query or "").trim() and totalCount > 0 and <div className="pl-6">
                <span className="text-[11px] text-muted-foreground">
                    {String(totalCount) + " results in " + String(fileCount) + " files"}
                </span>
            </div> or None}
            {not isSearching and (query or "").trim() and totalCount == 0 and results.length == 0 and <div className="pl-6">
                <span className="text-[11px] text-muted-foreground">{"No results found"}</span>
            </div> or None}
        </div>
        <ScrollArea className="flex-1">
            {not (query or "").trim() and <div className="flex flex-col items-center justify-center py-12 px-4 text-center">
                <HugeiconsIcon icon={Search01Icon} strokeWidth={1.5} className="size-8 text-muted-foreground/30 mb-2" />
                <span className="text-xs text-muted-foreground">{"Search across project files"}</span>
            </div> or <div className="flex flex-col">
                {fileOrder.map(lambda(filePath: str) -> Any {
                    fileResults = grouped[filePath];
                    isExpanded = expandedFiles[filePath];
                    fileResultCount = fileResults.length;
                    fParts = filePath.split("/");
                    fName = fParts[fParts.length - 1];
                    fDir = "";
                    if fParts.length > 1 {
                        fDir = fParts.slice(0, fParts.length - 1).join("/");
                    }
                    return <div key={filePath}>
                        <button
                            onClick={lambda { toggleFile(filePath); }}
                            className="flex items-center gap-1 w-full px-2 py-[3px] text-left bg-transparent hover:bg-accent/50 border-0 cursor-pointer"
                        >
                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-2.5 text-muted-foreground shrink-0 transition-transform" style={{
                                "transform": "rotate(90deg)" if isExpanded else "rotate(0deg)"
                            }} />
                            <HugeiconsIcon icon={File01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" />
                            <span className="text-xs text-foreground truncate">{fName}</span>
                            {fDir and <span className="text-[10px] text-muted-foreground truncate">{fDir}</span> or None}
                            <div className="flex-1" />
                            <Badge variant="secondary" className="text-[9px] h-4 min-w-[18px] justify-center px-1 shrink-0">
                                {String(fileResultCount)}
                            </Badge>
                        </button>
                        {isExpanded and <div className="flex flex-col">
                            {fileResults.map(lambda(item: Any, idx: int) -> Any {
                                navFile = item.file;
                                navLine = item.line;
                                lineContent = item.content or "";
                                trimmedContent = lineContent.trimStart();
                                displayContent = trimmedContent or ("Line " + String(navLine));
                                return <button
                                    key={String(idx)}
                                    onClick={lambda { handleNavigate(navFile, navLine); }}
                                    className="flex items-start gap-1.5 w-full pl-9 pr-2 py-1 text-left bg-transparent hover:bg-accent/50 border-0 cursor-pointer min-h-[24px]"
                                >
                                    <span className="text-[10px] text-muted-foreground shrink-0 w-5 text-right tabular-nums font-mono pt-px">
                                        {String(navLine)}
                                    </span>
                                    <span className="text-[11px] text-foreground font-mono whitespace-pre overflow-hidden text-ellipsis leading-relaxed">
                                        {highlightMatch(displayContent, query)}
                                    </span>
                                </button>;
                            })}
                        </div> or None}
                    </div>;
                })}
            </div>}
        </ScrollArea>
    </div>;
}
