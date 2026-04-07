import from react { useState, useEffect, useRef, useCallback }
import from "..ui.dialog" { Dialog, DialogContent, DialogHeader, DialogTitle }
import from "..ui.input" { Input }
import from "..ui.badge" { Badge }
import from "..ui.scroll-area" { ScrollArea }
import from "..ui.spinner" { Spinner }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Search01Icon, FunctionIcon, PackageIcon, VariableIcon,
    SourceCodeSquareIcon, CodeIcon, Diamond01Icon, File01Icon,
    CircleIcon
}

glob _SYMBOL_KIND_LABELS: Any = {
    "1": "File", "2": "Module", "3": "Namespace",
    "4": "Package", "5": "Class", "6": "Method",
    "7": "Property", "8": "Field", "9": "Constructor",
    "10": "Enum", "11": "Interface", "12": "Function",
    "13": "Variable", "14": "Constant", "15": "String",
    "16": "Number", "17": "Boolean", "18": "Array",
    "19": "Object", "20": "Key", "21": "Null",
    "22": "EnumMember", "23": "Struct", "24": "Event",
    "25": "Operator", "26": "TypeParameter"
};

def _getSymbolIcon(kind: int) -> Any {
    if kind == 5 or kind == 23 { return <HugeiconsIcon icon={SourceCodeSquareIcon} strokeWidth={2} className="size-3.5 text-primary" />; }
    if kind == 6 or kind == 12 { return <HugeiconsIcon icon={FunctionIcon} strokeWidth={2} className="size-3.5 text-info" />; }
    if kind == 7 or kind == 8 { return <HugeiconsIcon icon={Diamond01Icon} strokeWidth={2} className="size-3.5 text-claude" />; }
    if kind == 10 { return <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className="size-3.5 text-warning" />; }
    if kind == 11 { return <HugeiconsIcon icon={CircleIcon} strokeWidth={2} className="size-3.5 text-success" />; }
    if kind == 13 { return <HugeiconsIcon icon={VariableIcon} strokeWidth={2} className="size-3.5 text-info" />; }
    if kind == 14 { return <HugeiconsIcon icon={PackageIcon} strokeWidth={2} className="size-3.5 text-warning" />; }
    if kind == 2 or kind == 9 { return <HugeiconsIcon icon={SourceCodeSquareIcon} strokeWidth={2} className="size-3.5 text-claude" />; }
    return <HugeiconsIcon icon={File01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground" />;
}

def _getKindLabel(kind: int) -> str {
    label = _SYMBOL_KIND_LABELS[String(kind)];
    if label { return label; }
    return "Symbol";
}

def:pub WorkspaceSymbolSearch(props: Any) -> Any {
    opened = props.opened or False;
    onClose = props.onClose;
    searchFn = props.searchWorkspaceSymbols;
    onNavigate = props.onNavigate;
    isInline = props.inline or False;

    has query: str = "";
    has results: list = [];
    has isSearching: bool = False;
    has selectedIndex: int = 0;

    debounceRef = useRef(None);
    inputRef = useRef(None);

    useEffect(lambda -> None {
        if isInline and inputRef.current {
            inputRef.current.focus();
        }
        if not isInline {
            if opened and inputRef.current {
                setTimeout(lambda { if inputRef.current { inputRef.current.focus(); } }, 100);
            }
            if not opened {
                query = "";
                results = [];
                selectedIndex = 0;
            }
        }
    }, [opened]);

    useEffect(lambda -> None {
        if debounceRef.current {
            clearTimeout(debounceRef.current);
        }
        if not query.trim() or not searchFn {
            results = [];
            return;
        }
        isSearching = True;
        debounceRef.current = setTimeout(lambda {
            fn = searchFn;
            fn.call(None, query, lambda(res: Any) {
                results = res or [];
                selectedIndex = 0;
                isSearching = False;
            });
        }, 300);
    }, [query]);

    def handleKeyDown(e: Any) -> None {
        if e.key == "ArrowDown" {
            e.preventDefault();
            maxIdx = results.length - 1;
            newIdx = selectedIndex + 1;
            if newIdx > maxIdx { newIdx = 0; }
            selectedIndex = newIdx;
        } elif e.key == "ArrowUp" {
            e.preventDefault();
            newIdx = selectedIndex - 1;
            if newIdx < 0 { newIdx = results.length - 1; }
            if newIdx < 0 { newIdx = 0; }
            selectedIndex = newIdx;
        } elif e.key == "Enter" {
            e.preventDefault();
            if results.length > 0 and selectedIndex < results.length {
                item = results[selectedIndex];
                if onNavigate {
                    navFn = onNavigate;
                    navFn.call(None, item.filePath, item.range.startLine, item.range.startColumn);
                }
                if onClose and not isInline {
                    closeFn = onClose;
                    closeFn.call(None);
                }
            }
        }
    }

    def handleItemClick(sym: Any) -> None {
        if onNavigate {
            navFn = onNavigate;
            navFn.call(None, sym.filePath, sym.range.startLine, sym.range.startColumn);
        }
        if onClose and not isInline {
            closeFn = onClose;
            closeFn.call(None);
        }
    }

    symbolList = <div>
        {not query.trim() and <div className="flex items-center justify-center py-8">
            <span className="text-sm text-muted-foreground">{"Type to search symbols"}</span>
        </div> or (results.length == 0 and not isSearching and <div className="flex items-center justify-center py-8">
            <span className="text-sm text-muted-foreground">{"No symbols found"}</span>
        </div> or <div className="flex flex-col gap-0.5">
            {results.map(lambda(sym: Any, idx: int) -> Any {
                isSelected = idx == selectedIndex;
                kindLabel = _getKindLabel(sym.kind);
                return <button
                    key={String(idx)}
                    onClick={lambda { handleItemClick(sym); }}
                    className="flex items-center gap-1.5 py-1.5 px-2 rounded text-left w-full cursor-pointer border-0 bg-transparent"
                    style={{
                        "background": ("rgba(249, 115, 22, 0.12)" if isSelected else "transparent")
                    }}
                >
                    {_getSymbolIcon(sym.kind)}
                    <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1">
                            <span className="text-xs font-medium truncate text-foreground">{sym.name}</span>
                            <Badge variant="secondary" className="shrink-0 text-[9px] h-4 px-1">{kindLabel}</Badge>
                        </div>
                        <span className="text-[10px] truncate block text-muted-foreground">
                            {sym.filePath + ":" + String(sym.range.startLine)}
                        </span>
                    </div>
                </button>;
            })}
        </div>)}
    </div>;

    if isInline {
        return <div className="flex flex-col h-full overflow-hidden bg-card">
            <div className="px-3 py-3 text-[11px] font-semibold uppercase tracking-wider border-b border-border text-muted-foreground">
                {"Search Symbols"}
            </div>
            <div className="px-3 py-2">
                <div className="relative">
                    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3.5 absolute left-2 top-1/2 -translate-y-1/2 text-muted-foreground" />
                    <Input
                        ref={inputRef}
                        placeholder="Search symbols..."
                        value={query}
                        onChange={lambda e: Any { query = e.target.value; }}
                        onKeyDown={handleKeyDown}
                        className="pl-7 h-7 text-xs bg-background text-foreground border-border"
                    />
                    {isSearching and <Spinner className="size-3 absolute right-2 top-1/2 -translate-y-1/2 text-primary" /> or None}
                </div>
            </div>
            <ScrollArea className="flex-1 px-2">
                {symbolList}
            </ScrollArea>
        </div>;
    }

    return <Dialog open={opened} onOpenChange={lambda(open: bool) { if not open { closeFn = onClose; closeFn.call(None); } }}>
        <DialogContent className="sm:max-w-lg p-0">
            <DialogHeader className="px-4 pt-4 pb-2 border-b border-border">
                <DialogTitle>
                    <div className="flex items-center gap-2">
                        <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-4 text-primary" />
                        <span className="text-sm font-semibold text-foreground">{"Workspace Symbols"}</span>
                    </div>
                </DialogTitle>
            </DialogHeader>
            <div className="px-4 pt-2">
                <div className="relative">
                    <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3.5 absolute left-2 top-1/2 -translate-y-1/2 text-muted-foreground" />
                    <Input
                        ref={inputRef}
                        placeholder="Search symbols across all files... (Ctrl+T)"
                        value={query}
                        onChange={lambda e: Any { query = e.target.value; }}
                        onKeyDown={handleKeyDown}
                        className="pl-7 text-sm bg-card text-foreground border-border"
                    />
                    {isSearching and <Spinner className="size-3.5 absolute right-2 top-1/2 -translate-y-1/2 text-primary" /> or None}
                </div>
            </div>
            <ScrollArea className="max-h-[400px] px-4 py-2">
                {symbolList}
            </ScrollArea>
        </DialogContent>
    </Dialog>;
}
