import from react { useMemo, useEffect, useRef, useState, useCallback }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "...utils.use_click_outside" { useClickOutside }
import from "...utils.hotkeys" { useHotkeys }
import from "...lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    File01Icon, Folder01Icon, FolderOpenIcon, ArrowRight01Icon, ArrowDown01Icon,
    Delete02Icon, PencilEdit01Icon, FileAddIcon, SourceCodeSquareIcon, CodeIcon, PaintBrushIcon,
    Settings01Icon, FileBracesIcon, PlusSignIcon, FolderAddIcon, Upload01Icon,
    Copy01Icon, Scissor01Icon, ClipboardIcon, FileValidationIcon,
    PlayIcon, CheckmarkBadge01Icon, Link01Icon, MoveIcon,
    EcoLabIcon, JavaScriptIcon
}

def buildTree(fileList: list) -> Any {
    tree_root = {"_children": {}, "_files": []};
    for filePath in fileList {
        parts = filePath.split("/");
        current = tree_root;
        i = 0;
        while i < parts.length - 1 {
            dirName = parts[i];
            if not current._children[dirName] {
                current._children[dirName] = {"_children": {}, "_files": []};
            }
            current = current._children[dirName];
            i += 1;
        }
        current._files.push(parts[parts.length - 1]);
    }
    return tree_root;
}

def _toImportPath(filePath: str) -> str {
    p = filePath;
    if p.endsWith(".cl.jac") {
        p = p.substring(0, p.length - 7);
    } elif p.endsWith(".jac") {
        p = p.substring(0, p.length - 4);
    }
    return "import from ." + p.split("/").join(".") + " {  }";
}

def:pub FileIcon(props: Any) -> Any {
    fileName = props.fileName or "";
    size = props.size or 14;
    lower = fileName.toLowerCase();
    sizeClass = "size-3.5";
    if size <= 13 {
        sizeClass = "size-3";
    }
    if lower.endsWith(".cl.jac") {
        return <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className={cn(sizeClass, "text-primary")} />;
    } elif lower.endsWith(".jac") {
        return <HugeiconsIcon icon={SourceCodeSquareIcon} strokeWidth={2} className={cn(sizeClass, "text-info")} />;
    } elif lower.endsWith(".json") {
        return <HugeiconsIcon icon={SourceCodeSquareIcon} strokeWidth={2} className={cn(sizeClass, "text-warning")} />;
    } elif lower.endsWith(".css") {
        return <HugeiconsIcon icon={PaintBrushIcon} strokeWidth={2} className={cn(sizeClass, "text-destructive")} />;
    } elif lower.endsWith(".toml") {
        return <HugeiconsIcon icon={Settings01Icon} strokeWidth={2} className={cn(sizeClass, "text-muted-foreground")} />;
    } elif lower.endsWith(".md") {
        return <HugeiconsIcon icon={FileBracesIcon} strokeWidth={2} className={cn(sizeClass, "text-muted-foreground")} />;
    } else {
        return <HugeiconsIcon icon={File01Icon} strokeWidth={2} className={cn(sizeClass, "text-muted-foreground")} />;
    }
}

def InlineInput(props: Any) -> Any {
    initialValue = props.initialValue or "";
    placeholder = props.placeholder or "";
    onConfirm = props.onConfirm;
    onCancel = props.onCancel;

    has value: str = initialValue;

    inputRef = useRef(None);

    useEffect(lambda {
        if inputRef.current {
            inputRef.current.focus();
            inputRef.current.select();
        }
    }, []);

    def handleKeyDown(e: Any) -> None {
        if e.key == "Enter" {
            e.preventDefault();
            if value.trim() {
                onConfirm(value.trim());
            } else {
                onCancel();
            }
        } elif e.key == "Escape" {
            e.preventDefault();
            onCancel();
        }
    }

    def handleBlur() -> None {
        if value.trim() {
            onConfirm(value.trim());
        } else {
            onCancel();
        }
    }

    return <div className="flex-1 px-1 py-0.5">
        <input
            ref={inputRef}
            value={value}
            placeholder={placeholder}
            onChange={lambda (e: Any) { value = e.target.value; }}
            onKeyDown={handleKeyDown}
            onBlur={handleBlur}
            className="w-full bg-background/80 text-foreground border border-primary/55 rounded px-[7px] py-0.5 text-xs focus:border-primary outline-none"
        />
    </div>;
}

def TreeNode(props: Any) -> Any {
    name = props.name;
    treeData = props.treeData;
    path = props.path or "";
    onFileClick = props.onFileClick;
    onContextMenu = props.onContextMenu;
    activeTab = props.activeTab or "";
    depth = props.depth or 0;
    renamingPath = props.renamingPath or "";
    onRenameConfirm = props.onRenameConfirm;
    onRenameCancel = props.onRenameCancel;
    creatingIn = props.creatingIn;
    onCreateConfirm = props.onCreateConfirm;
    onCreateCancel = props.onCreateCancel;
    onUploadFolder = props.onUploadFolder;
    uploadingFiles = props.isUploading or False;
    expandSignal = props.expandSignal or 0;
    collapseSignal = props.collapseSignal or 0;
    onDragMoveItem = props.onDragMoveItem;
    dragSourcePath = props.dragSourcePath or "";

    has isOpen: bool = False;
    has folderDragOver: bool = False;

    useEffect(lambda {
        if expandSignal > 0 { isOpen = True; }
    }, [expandSignal]);

    useEffect(lambda {
        if collapseSignal > 0 { isOpen = False; }
    }, [collapseSignal]);

    fullPath = (path + "/" + name) if path else name;

    dirNames = Object.keys(treeData._children or {}).sort();
    fileNames = (treeData._files or []).slice().sort();

    isCreatingHere = creatingIn == fullPath;
    folderIndent = String(depth * 16 + 8) + "px";
    childIndent  = String((depth + 1) * 16 + 8) + "px";

    isDragTarget = folderDragOver and dragSourcePath and dragSourcePath != fullPath and not dragSourcePath.startsWith(fullPath + "/");
    isFolderRenaming = renamingPath == fullPath;

    if isFolderRenaming {
        return <div>
            <div className="flex items-center gap-1 py-0.5" style={{"paddingLeft": folderIndent}}>
                <HugeiconsIcon icon={FolderOpenIcon} strokeWidth={2} className="size-3.5 text-warning" />
                <InlineInput
                    initialValue={name}
                    onConfirm={onRenameConfirm}
                    onCancel={onRenameCancel}
                />
            </div>
        </div>;
    }

    return <div>
        <button
            onClick={lambda { isOpen = not isOpen; }}
            draggable={True}
            onDragStart={lambda(e: Any) {
                e.dataTransfer.setData("text/x-jac-path", fullPath);
                e.dataTransfer.setData("text/x-jac-type", "folder");
                e.dataTransfer.effectAllowed = "move";
            }}
            onContextMenu={lambda (e: Any) {
                e.preventDefault();
                e.stopPropagation();
                handler = onContextMenu;
                handler.call(None, e, "folder", fullPath);
            }}
            onDragOver={lambda(e: Any) {
                e.preventDefault();
                e.stopPropagation();
                srcPath = e.dataTransfer.types.includes("text/x-jac-path");
                if srcPath {
                    e.dataTransfer.dropEffect = "move";
                    folderDragOver = True;
                    isOpen = True;
                } elif not uploadingFiles {
                    folderDragOver = True;
                    isOpen = True;
                }
            }}
            onDragLeave={lambda(e: Any) {
                e.preventDefault();
                e.stopPropagation();
                folderDragOver = False;
            }}
            onDrop={lambda(e: Any) {
                e.preventDefault();
                e.stopPropagation();
                folderDragOver = False;
                jacPath = e.dataTransfer.getData("text/x-jac-path");
                if jacPath and onDragMoveItem {
                    moveFn = onDragMoveItem;
                    moveFn.call(None, jacPath, fullPath);
                    return;
                }
                if not uploadingFiles and onUploadFolder {
                    uploadFn = onUploadFolder;
                    uploadFn.call(None, e.dataTransfer, fullPath);
                }
            }}
            className={cn("transition-colors duration-[120ms] rounded-[5px] hover:bg-accent/40 w-full text-left pt-1 pb-1 pr-2 bg-transparent border-none cursor-pointer", (isDragTarget and "bg-primary/10 ring-1 ring-primary/30" or ""))}
            style={{"paddingLeft": folderIndent}}
        >
            <div className="flex items-center gap-1">
                {isOpen and <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-3 text-muted-foreground" /> or <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3 text-muted-foreground" />}
                {isOpen and <HugeiconsIcon icon={FolderOpenIcon} strokeWidth={2} className="size-3.5 text-warning" /> or <HugeiconsIcon icon={Folder01Icon} strokeWidth={2} className="size-3.5 text-warning" />}
                <span className="text-[12px] text-muted-foreground truncate">{name}</span>
            </div>
        </button>

        {isOpen and <div>
            {isCreatingHere and <div className="flex items-center gap-1.5 py-0.5" style={{"paddingLeft": childIndent}}>
                <HugeiconsIcon icon={FileAddIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                <InlineInput
                    initialValue=""
                    placeholder="filename.cl.jac"
                    onConfirm={onCreateConfirm}
                    onCancel={onCreateCancel}
                />
            </div> or None}
            {dirNames.map(lambda (dirName: str) -> Any {
                return <TreeNode
                    key={dirName}
                    name={dirName}
                    treeData={treeData._children[dirName]}
                    path={fullPath}
                    onFileClick={onFileClick}
                    onContextMenu={onContextMenu}
                    activeTab={activeTab}
                    depth={depth + 1}
                    renamingPath={renamingPath}
                    onRenameConfirm={onRenameConfirm}
                    onRenameCancel={onRenameCancel}
                    creatingIn={creatingIn}
                    onCreateConfirm={onCreateConfirm}
                    onCreateCancel={onCreateCancel}
                    onUploadFolder={onUploadFolder}
                    isUploading={uploadingFiles}
                    expandSignal={expandSignal}
                    collapseSignal={collapseSignal}
                    onDragMoveItem={onDragMoveItem}
                    dragSourcePath={dragSourcePath}
                />;
            })}
            {fileNames.map(lambda (fileName: str) -> Any {
                filePath = fullPath + "/" + fileName;
                isActive = activeTab == filePath;
                isRenaming = renamingPath == filePath;

                if isRenaming {
                    return <div
                        key={fileName}
                        className="flex items-center gap-1.5 py-0.5"
                        style={{"paddingLeft": childIndent}}
                    >
                        <FileIcon fileName={fileName} size={13} />
                        <InlineInput
                            initialValue={fileName}
                            onConfirm={onRenameConfirm}
                            onCancel={onRenameCancel}
                        />
                    </div>;
                }

                return <button
                    key={fileName}
                    onClick={lambda { onFileClick(filePath); }}
                    draggable={True}
                    onDragStart={lambda(e: Any) {
                        e.dataTransfer.setData("text/x-jac-path", filePath);
                        e.dataTransfer.setData("text/x-jac-type", "file");
                        e.dataTransfer.effectAllowed = "move";
                    }}
                    onContextMenu={lambda (e: Any) {
                        e.preventDefault();
                        e.stopPropagation();
                        handler = onContextMenu;
                        handler.call(None, e, "file", filePath);
                    }}
                    className={("transition-colors duration-[120ms] rounded-[5px] bg-primary/[0.13] border-l-2 border-l-primary hover:bg-primary/20 w-full text-left pt-1 pb-1 pr-2 bg-transparent border-none cursor-pointer" if isActive else "transition-colors duration-[120ms] rounded-[5px] hover:bg-accent/40 w-full text-left pt-1 pb-1 pr-2 bg-transparent border-none cursor-pointer")}
                    style={{"paddingLeft": childIndent}}
                >
                    <div className="flex items-center gap-1.5">
                        <FileIcon fileName={fileName} size={13} />
                        <span className={("text-[12px] truncate font-medium text-foreground" if isActive else "text-[12px] truncate text-muted-foreground")}>
                            {fileName}
                        </span>
                    </div>
                </button>;
            })}
        </div> or None}
    </div>;
}

def:pub FileTree(props: Any) -> Any {
    fileList = props.files or [];
    onFileClick = props.onFileClick;
    onDeleteFile = props.onDeleteFile;
    onRenameFile = props.onRenameFile;
    onCreateFile = props.onCreateFile;
    onCreateDir = props.onCreateDir;
    onCopyFile = props.onCopyFile;
    onDuplicateFile = props.onDuplicateFile;
    onRunFile = props.onRunFile;
    onCheckFile = props.onCheckFile;
    onTestFile = props.onTestFile;
    onFormatFile = props.onFormatFile;
    onJsFile = props.onJsFile;
    onRevealActive = props.onRevealActive;
    activeTab = props.activeTab or "";
    newFileTrigger = props.newFileTrigger or 0;
    onUploadFolder = props.onUploadFolder;
    onTriggerFolderPicker = props.onTriggerFolderPicker;
    uploadingFiles = props.isUploading or False;
    revealSignal = props.revealSignal or 0;
    canEdit = True;
    if props.canEdit is not None {
        canEdit = props.canEdit;
    }

    has ctxVisible: bool = False;
    has ctxX: int = 0;
    has ctxY: int = 0;
    has ctxType: str = "";
    has ctxPath: str = "";
    has creatingDirIn: Any = None;

    has renamingPath: str = "";
    has creatingIn: Any = None;
    has isDragOver: bool = False;
    has expandSignal: int = 0;
    has collapseSignal: int = 1;
    has allExpanded: bool = False;

    has clipboardPath: str = "";
    has clipboardOp: str = "";
    has dragSourcePath: str = "";

    menuRef = useClickOutside(lambda -> None { ctxVisible = False; });
    prevNewFileTrigger = useRef(0);

    tree = useMemo(lambda { return buildTree(fileList); }, [fileList]);

    useEffect(lambda {
        if canEdit and newFileTrigger > 0 and newFileTrigger != prevNewFileTrigger.current {
            creatingIn = "__root__";
        }
        prevNewFileTrigger.current = newFileTrigger;
    }, [newFileTrigger, canEdit]);

    useEffect(lambda {
        if canEdit { return; }
        ctxVisible = False;
        renamingPath = "";
        creatingIn = None;
    }, [canEdit]);

    prevRevealRef = useRef(0);
    useEffect(lambda {
        if revealSignal > 0 and revealSignal != prevRevealRef.current {
            if activeTab {
                expandSignal = expandSignal + 1;
                allExpanded = True;
            }
        }
        prevRevealRef.current = revealSignal;
    }, [revealSignal]);

    def handleContextMenu(e: Any, itemType: str, itemPath: str) -> None {
        if not canEdit {
            ctxVisible = False;
            return;
        }
        ctxX = e.clientX;
        ctxY = e.clientY;
        ctxType = itemType;
        ctxPath = itemPath;
        ctxVisible = True;
    }

    def startRename() -> None {
        renamingPath = ctxPath;
        ctxVisible = False;
    }

    def startDelete() -> None {
        path = ctxPath;
        ctxVisible = False;
        onDeleteFile(path);
    }

    def startNewFile() -> None {
        if not canEdit {
            ctxVisible = False;
            return;
        }
        ctxVisible = False;
        if ctxType == "folder" {
            creatingIn = ctxPath;
        } else {
            creatingIn = "__root__";
        }
    }

    def startNewFolder() -> None {
        if not canEdit {
            ctxVisible = False;
            return;
        }
        ctxVisible = False;
        if ctxType == "folder" {
            creatingDirIn = ctxPath;
        } else {
            creatingDirIn = "__root__";
        }
    }

    def handleCut() -> None {
        clipboardPath = ctxPath;
        clipboardOp = "cut";
        ctxVisible = False;
    }

    def handleCopy() -> None {
        clipboardPath = ctxPath;
        clipboardOp = "copy";
        ctxVisible = False;
    }

    def handlePaste() -> None {
        if not clipboardPath or not clipboardOp { ctxVisible = False; return; }
        srcPath = clipboardPath;
        op = clipboardOp;
        ctxVisible = False;
        srcParts = srcPath.split("/");
        srcName = srcParts[srcParts.length - 1];
        destFolder = "";
        if ctxType == "folder" {
            destFolder = ctxPath;
        }
        destPath = (destFolder + "/" + srcName if destFolder else srcName);
        if destPath == srcPath {
            destPath = destPath + "-copy";
        }
        if op == "cut" {
            onRenameFile(srcPath, destPath);
            clipboardPath = "";
            clipboardOp = "";
        } elif op == "copy" {
            if onCopyFile { onCopyFile(srcPath, destPath); }
        }
    }

    def handleDuplicate() -> None {
        ctxVisible = False;
        if onDuplicateFile { onDuplicateFile(ctxPath); }
    }

    def handleCopyPath() -> None {
        ctxVisible = False;
        if navigator.clipboard {
            navigator.clipboard.writeText(ctxPath);
        }
    }

    def handleCopyImportPath() -> None {
        ctxVisible = False;
        importStr = _toImportPath(ctxPath);
        if navigator.clipboard {
            navigator.clipboard.writeText(importStr);
        }
    }

    def handleRunFile() -> None {
        ctxVisible = False;
        if onRunFile { onRunFile(ctxPath); }
    }

    def handleCheckFile() -> None {
        ctxVisible = False;
        if onCheckFile { onCheckFile(ctxPath); }
    }

    def handleTestFile() -> None {
        ctxVisible = False;
        if onTestFile { onTestFile(ctxPath); }
    }

    def handleFormatFile() -> None {
        ctxVisible = False;
        if onFormatFile { onFormatFile(ctxPath); }
    }

    def handleJsFile() -> None {
        ctxVisible = False;
        if onJsFile { onJsFile(ctxPath); }
    }

    def handleDragMoveItem(srcPath: str, destFolder: str) -> None {
        if not srcPath or srcPath == destFolder { return; }
        if destFolder and srcPath.startsWith(destFolder + "/") { return; }
        srcParts = srcPath.split("/");
        srcName = srcParts[srcParts.length - 1];
        newPath = (destFolder + "/" + srcName if destFolder else srcName);
        if newPath != srcPath {
            onRenameFile(srcPath, newPath);
        }
        dragSourcePath = "";
    }

    def handleCreateDirConfirm(name: str) -> None {
        if not canEdit or not name {
            creatingDirIn = None;
            return;
        }
        parentPath = creatingDirIn;
        creatingDirIn = None;
        fullPath = name;
        if parentPath and parentPath != "__root__" {
            fullPath = parentPath + "/" + name;
        }
        if onCreateDir { onCreateDir(fullPath); }
    }

    def handleCreateDirCancel() -> None {
        creatingDirIn = None;
    }

    def handleNewFileClick() -> None {
        if not canEdit { return; }
        creatingIn = "__root__";
    }

    def handleRenameConfirm(newName: str) -> None {
        oldPath = renamingPath;
        if not oldPath or not newName { renamingPath = ""; return; }
        parts = oldPath.split("/");
        parts[parts.length - 1] = newName;
        newPath = parts.join("/");
        renamingPath = "";
        if newPath != oldPath {
            onRenameFile(oldPath, newPath);
        }
    }

    def handleRenameCancel() -> None {
        renamingPath = "";
    }

    def handleCreateConfirm(name: str) -> None {
        if not canEdit {
            creatingIn = None;
            return;
        }
        if not name { creatingIn = None; return; }
        parentPath = creatingIn;
        creatingIn = None;
        fullPath = name;
        if parentPath and parentPath != "__root__" {
            fullPath = parentPath + "/" + name;
        }
        onCreateFile(fullPath);
    }

    def handleCreateCancel() -> None {
        creatingIn = None;
    }

    useHotkeys([
        ["Escape", lambda(e: Any) -> None { ctxVisible = False; }],
        ["F2", lambda(e: Any) -> None {
            if canEdit and activeTab {
                e.preventDefault();
                renamingPath = activeTab;
            }
        }],
        ["Delete", lambda(e: Any) -> None {
            if canEdit and activeTab {
                e.preventDefault();
                onDeleteFile(activeTab);
            }
        }],
        ["mod+c", lambda(e: Any) -> None {
            if canEdit and activeTab and not window.getSelection().toString() {
                clipboardPath = activeTab;
                clipboardOp = "copy";
            }
        }],
        ["mod+x", lambda(e: Any) -> None {
            if canEdit and activeTab and not window.getSelection().toString() {
                clipboardPath = activeTab;
                clipboardOp = "cut";
            }
        }]
    ]);

    dirNames = Object.keys(tree._children or {}).sort();
    fileNames = (tree._files or []).slice().sort();
    isCreatingAtRoot = creatingIn == "__root__";
    isCreatingDirAtRoot = creatingDirIn == "__root__";

    isJacFile = ctxPath and (ctxPath.endsWith(".jac") and not ctxPath.endsWith(".cl.jac"));
    isClJacFile = ctxPath and ctxPath.endsWith(".cl.jac");
    isAnyJacFile = ctxPath and ctxPath.endsWith(".jac");
    isTestFile = isJacFile and ctxPath.endsWith("_test.jac");

    return <div className="h-full relative flex flex-col bg-card border-r border-border">
        <div className="flex items-center justify-between px-3 py-2.5 border-b border-border flex-shrink-0">
            <span className="text-[11px] font-semibold uppercase tracking-[0.06em] text-muted-foreground leading-none select-none">Files</span>
            <div className="flex items-center gap-0.5">
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button
                            size="icon-xs"
                            variant="ghost"
                            disabled={not canEdit}
                            onClick={lambda(_e: Any) {
                                if allExpanded {
                                    collapseSignal = collapseSignal + 1;
                                    allExpanded = False;
                                } else {
                                    expandSignal = expandSignal + 1;
                                    allExpanded = True;
                                }
                            }}
                        >
                            <HugeiconsIcon icon={(ArrowDown01Icon if allExpanded else ArrowRight01Icon)} strokeWidth={2} className="size-3.5" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent>{(allExpanded and "Collapse all" or "Expand all")}</TooltipContent>
                </Tooltip>
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button
                            size="icon-xs"
                            variant="ghost"
                            disabled={not canEdit or uploadingFiles}
                            onClick={lambda(_e: Any) { if onTriggerFolderPicker { onTriggerFolderPicker(); } }}
                        >
                            <HugeiconsIcon icon={Upload01Icon} strokeWidth={2} className="size-3.5" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent>Upload folder</TooltipContent>
                </Tooltip>
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <Button
                            size="icon-xs"
                            variant="ghost"
                            disabled={not canEdit}
                            onClick={handleNewFileClick}
                            title={("New file" if canEdit else "Select a project first")}
                        >
                            <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-3.5" />
                        </Button>
                    </TooltipTrigger>
                    <TooltipContent>{("New file" if canEdit else "Select a project first")}</TooltipContent>
                </Tooltip>
            </div>
        </div>
        <ScrollArea className="flex-1 min-h-0">
            <div
                className={cn("p-1.5 min-h-full transition-colors", (isDragOver and "bg-primary/5 ring-1 ring-inset ring-primary/30" or ""))}
                onContextMenu={lambda (e: Any) {
                    e.preventDefault();
                    if not canEdit { return; }
                    handleContextMenu(e, "background", "");
                }}
                onDragOver={lambda(e: Any) {
                    e.preventDefault();
                    e.stopPropagation();
                    jacDrag = e.dataTransfer.types.includes("text/x-jac-path");
                    if jacDrag {
                        e.dataTransfer.dropEffect = "move";
                        isDragOver = True;
                    } elif canEdit and not uploadingFiles {
                        isDragOver = True;
                    }
                }}
                onDragLeave={lambda(e: Any) {
                    e.preventDefault();
                    e.stopPropagation();
                    isDragOver = False;
                }}
                onDrop={lambda(e: Any) {
                    e.preventDefault();
                    e.stopPropagation();
                    isDragOver = False;
                    jacPath = e.dataTransfer.getData("text/x-jac-path");
                    if jacPath {
                        handleDragMoveItem(jacPath, "");
                        return;
                    }
                    if canEdit and not uploadingFiles and onUploadFolder {
                        onUploadFolder(e.dataTransfer, "");
                    }
                }}
            >
                {not canEdit and <div className="flex items-center justify-center text-muted-foreground text-sm">
                    Select a project to browse and edit files.
                </div> or None}
                {canEdit and isCreatingAtRoot and <div className="flex items-center gap-1.5 px-2 py-0.5">
                    <HugeiconsIcon icon={FileAddIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                    <InlineInput
                        initialValue=""
                        placeholder="e.g. pages/Home.cl.jac"
                        onConfirm={handleCreateConfirm}
                        onCancel={handleCreateCancel}
                    />
                </div> or None}
                {canEdit and isCreatingDirAtRoot and <div className="flex items-center gap-1.5 px-2 py-0.5">
                    <HugeiconsIcon icon={FileAddIcon} strokeWidth={2} className="size-3.5 text-warning" />
                    <InlineInput
                        initialValue=""
                        placeholder="folder-name"
                        onConfirm={handleCreateDirConfirm}
                        onCancel={handleCreateDirCancel}
                    />
                </div> or None}

                {canEdit and dirNames.map(lambda (dirName: str) -> Any {
                    return <TreeNode
                        key={dirName}
                        name={dirName}
                        treeData={tree._children[dirName]}
                        path=""
                        onFileClick={onFileClick}
                        onContextMenu={handleContextMenu}
                        activeTab={activeTab}
                        depth={0}
                        renamingPath={renamingPath}
                        onRenameConfirm={handleRenameConfirm}
                        onRenameCancel={handleRenameCancel}
                        creatingIn={creatingIn}
                        onCreateConfirm={handleCreateConfirm}
                        onCreateCancel={handleCreateCancel}
                        onUploadFolder={onUploadFolder}
                        isUploading={uploadingFiles}
                        expandSignal={expandSignal}
                        collapseSignal={collapseSignal}
                        onDragMoveItem={handleDragMoveItem}
                        dragSourcePath={dragSourcePath}
                    />;
                }) or None}

                {canEdit and fileNames.map(lambda (fileName: str) -> Any {
                    isActive = activeTab == fileName;
                    isRenaming = renamingPath == fileName;

                    if isRenaming {
                        return <div key={fileName} className="flex items-center gap-1.5 px-2 py-0.5">
                            <FileIcon fileName={fileName} size={13} />
                            <InlineInput
                                initialValue={fileName}
                                onConfirm={handleRenameConfirm}
                                onCancel={handleRenameCancel}
                            />
                        </div>;
                    }

                    return <button
                        key={fileName}
                        onClick={lambda { onFileClick(fileName); }}
                        draggable={True}
                        onDragStart={lambda(e: Any) {
                            e.dataTransfer.setData("text/x-jac-path", fileName);
                            e.dataTransfer.setData("text/x-jac-type", "file");
                            e.dataTransfer.effectAllowed = "move";
                        }}
                        onContextMenu={lambda (e: Any) {
                            e.preventDefault();
                            e.stopPropagation();
                            handleContextMenu(e, "file", fileName);
                        }}
                        className={("transition-colors duration-[120ms] rounded-[5px] bg-primary/[0.13] border-l-2 border-l-primary hover:bg-primary/20 w-full text-left px-2 pt-1 pb-1 bg-transparent border-none cursor-pointer" if isActive else "transition-colors duration-[120ms] rounded-[5px] hover:bg-accent/40 w-full text-left px-2 pt-1 pb-1 bg-transparent border-none cursor-pointer")}
                    >
                        <div className="flex items-center gap-1.5">
                            <FileIcon fileName={fileName} size={13} />
                            <span className={("text-[12px] truncate font-medium text-foreground" if isActive else "text-[12px] truncate text-muted-foreground")}>
                                {fileName}
                            </span>
                        </div>
                    </button>;
                }) or None}
            </div>
        </ScrollArea>
        {ctxVisible and <div
            ref={menuRef}
            className="bg-popover ring-1 ring-foreground/10 rounded-lg p-1 min-w-[180px] shadow-md animate-in fade-in-0 zoom-in-95 duration-100"
            style={{
                "position": "fixed",
                "top": String(ctxY) + "px",
                "left": String(ctxX) + "px",
                "zIndex": 1000
            }}
        >
            {ctxType == "file" and isJacFile and onRunFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleRunFile}>
                <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-3.5 text-success" />
                <span className="flex-1">Run File</span>
                <span className="text-[10px] text-muted-foreground ml-4">jac run</span>
            </button> or None}
            {ctxType == "file" and isAnyJacFile and onCheckFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleCheckFile}>
                <HugeiconsIcon icon={CheckmarkBadge01Icon} strokeWidth={2} className="size-3.5 text-info" />
                <span className="flex-1">Check Syntax</span>
                <span className="text-[10px] text-muted-foreground ml-4">jac check</span>
            </button> or None}
            {ctxType == "file" and isTestFile and onTestFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleTestFile}>
                <HugeiconsIcon icon={EcoLabIcon} strokeWidth={2} className="size-3.5 text-warning" />
                <span className="flex-1">Run Tests</span>
                <span className="text-[10px] text-muted-foreground ml-4">jac test</span>
            </button> or None}
            {ctxType == "file" and isAnyJacFile and onFormatFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleFormatFile}>
                <HugeiconsIcon icon={PaintBrushIcon} strokeWidth={2} className="size-3.5 text-claude" />
                <span className="flex-1">Format</span>
                <span className="text-[10px] text-muted-foreground ml-4">jac format</span>
            </button> or None}
            {ctxType == "file" and isClJacFile and onJsFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleJsFile}>
                <HugeiconsIcon icon={JavaScriptIcon} strokeWidth={2} className="size-3.5 text-yellow-400" />
                <span className="flex-1">Convert to JS</span>
                <span className="text-[10px] text-muted-foreground ml-4">jac js</span>
            </button> or None}
            {ctxType == "file" and isAnyJacFile and <div className="bg-border -mx-1 my-1 h-px" /> or None}

            {(ctxType == "file" or ctxType == "folder") and <div>
                <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleCut}>
                    <HugeiconsIcon icon={Scissor01Icon} strokeWidth={2} className="size-3.5" />
                    <span className="flex-1">Cut</span>
                    <span className="text-[10px] text-muted-foreground ml-4">Ctrl+X</span>
                </button>
                <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleCopy}>
                    <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-3.5" />
                    <span className="flex-1">Copy</span>
                    <span className="text-[10px] text-muted-foreground ml-4">Ctrl+C</span>
                </button>
            </div> or None}
            {clipboardPath and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handlePaste}>
                <HugeiconsIcon icon={ClipboardIcon} strokeWidth={2} className="size-3.5" />
                <span className="flex-1">Paste</span>
                <span className="text-[10px] text-muted-foreground ml-4">Ctrl+V</span>
            </button> or None}
            {ctxType == "file" and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleDuplicate}>
                <HugeiconsIcon icon={FileValidationIcon} strokeWidth={2} className="size-3.5" />
                <span className="flex-1">Duplicate</span>
            </button> or None}

            <div className="bg-border -mx-1 my-1 h-px" />

            {(ctxType == "file" or ctxType == "folder") and <div>
                <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleCopyPath}>
                    <HugeiconsIcon icon={Link01Icon} strokeWidth={2} className="size-3.5" />
                    <span className="flex-1">Copy Path</span>
                </button>
            </div> or None}
            {ctxType == "file" and isAnyJacFile and <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={handleCopyImportPath}>
                <HugeiconsIcon icon={SourceCodeSquareIcon} strokeWidth={2} className="size-3.5 text-info" />
                <span className="flex-1">Copy Import Path</span>
            </button> or None}

            <div className="bg-border -mx-1 my-1 h-px" />

            <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={startNewFile}>
                <HugeiconsIcon icon={FileAddIcon} strokeWidth={2} className="size-3.5" />
                <span className="flex-1">New File</span>
            </button>
            <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={startNewFolder}>
                <HugeiconsIcon icon={FolderAddIcon} strokeWidth={2} className="size-3.5" />
                <span className="flex-1">New Folder</span>
            </button>

            {(ctxType == "file" or ctxType == "folder") and <div>
                <div className="bg-border -mx-1 my-1 h-px" />
                <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default hover:bg-accent hover:text-accent-foreground outline-none" onClick={startRename}>
                    <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className="size-3.5" />
                    <span className="flex-1">Rename</span>
                    <span className="text-[10px] text-muted-foreground ml-4">F2</span>
                </button>
                <button className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs w-full text-left cursor-default text-destructive hover:bg-destructive/10 hover:text-destructive outline-none" onClick={startDelete}>
                    <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3.5" />
                    <span className="flex-1">Delete</span>
                    <span className="text-[10px] text-muted-foreground ml-4">Del</span>
                </button>
            </div> or None}
        </div> or None}

    </div>;
}
