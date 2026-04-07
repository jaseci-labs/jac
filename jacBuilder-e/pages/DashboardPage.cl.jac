"""Dashboard page — Lovable-inspired sidebar + home/projects/community views."""
import from react { useRef, useMemo, useState }
import from "@jac/runtime" { jacLogout, useNavigate }
import from ..components.ui.button { Button }
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.card { Card, CardContent }
import from ..components.ui.badge { Badge }
import from ..components.ui.alert { Alert }
import from ..components.ui.spinner { Spinner }
import from ..components.ui.skeleton { Skeleton }
import from ..components.ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription }
import from ..components.ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }
import from "..components.ui.alert-dialog" {
    AlertDialog, AlertDialogContent, AlertDialogHeader,
    AlertDialogTitle, AlertDialogDescription,
    AlertDialogFooter, AlertDialogCancel, AlertDialogAction
}
import from "..components.ui.sheet" { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription }
import from ..components.ui.field { Field, FieldLabel }
import from ..components.ui.tabs { Tabs, TabsList, TabsTrigger, TabsContent }
import from ..components.ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from ..components.ui.separator { Separator }
import from "..components.ui.scroll-area" { ScrollArea }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.checkbox { Checkbox }
import from ..components.ui.kbd { Kbd }
import from ..components.ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from "..components.ui.password-input" { PasswordInput }
import from ..utils.use_click_outside { useClickOutside }
import from ..lib.utils { cn }
import from ..utils.hotkeys { useHotkeys }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    PlusSignIcon, Delete02Icon, CodeIcon, CodesandboxIcon,
    Upload01Icon, Link01Icon, Search01Icon, GridTableIcon, PackageIcon,
    Globe02Icon, Share01Icon, PencilEdit01Icon, Settings01Icon, FloppyDiskIcon,
    Key01Icon, AiChat02Icon,
    RocketIcon, ArrowRight01Icon, SourceCodeSquareIcon, Layers01Icon,
    SmartPhone01Icon, PaintBoardIcon, Home01Icon, MoreHorizontalIcon,
    Clock01Icon, SortingIcon, ComputerTerminal01Icon, PlayIcon,
    Folder01Icon, FolderOpenIcon, GitBranchIcon
}
import from ..hooks.useDashboard { useDashboard }
import from ..hooks.useCommunity { useCommunity }
import from ..hooks.useUserSettings { useUserSettings }
import from ..hooks.useTheme { useTheme }
import from ..components.ide.CommunityGallery { CommunityGallery }
import from ..components.common.UserPopover { UserPopover }

glob _SKIP_DIRS: Any = {
    ".git": True, "node_modules": True, "__pycache__": True,
    ".jac": True, ".jac-ide": True, "__jac_gen__": True,
    "dist": True, "build": True, ".next": True
};
glob _SKIP_FILES: Any = {".DS_Store": True, "Thumbs.db": True, ".gitkeep": True};
glob _BIN_EXTS: Any = {
    ".png": True, ".jpg": True, ".jpeg": True, ".gif": True, ".ico": True, ".webp": True,
    ".woff": True, ".woff2": True, ".ttf": True, ".eot": True, ".otf": True,
    ".zip": True, ".tar": True, ".gz": True, ".bz2": True, ".7z": True, ".rar": True,
    ".exe": True, ".dll": True, ".so": True, ".dylib": True,
    ".pdf": True, ".mp3": True, ".mp4": True, ".wav": True, ".avi": True,
    ".pyc": True, ".pyo": True, ".class": True, ".o": True,
    ".jacpack": True, ".wasm": True
};
glob _MAX_SIZE: int = 2097152;

def _isSkipDir(n: str) -> bool { return Boolean(_SKIP_DIRS[n]); }

def _isSkipFile(n: str) -> bool {
    if Boolean(_SKIP_FILES[n]) { return True; }
    lower = n.toLowerCase();
    dotIdx = lower.lastIndexOf(".");
    if dotIdx >= 0 and Boolean(_BIN_EXTS[lower.substring(dotIdx)]) { return True; }
    return False;
}

async def _scanInputFiles(filesList: Any) -> Any {
    collected: list = [];
    skipped = 0;
    folderRoot = "";
    i = 0;
    while i < filesList.length {
        f = filesList[i];
        relPath = f.webkitRelativePath or f.name;
        parts = relPath.split("/");
        if parts.length > 1 and not folderRoot {
            folderRoot = parts[0];
        }
        if parts.length > 1 {
            parts = parts.slice(1);
        }
        skipIt = False;
        j = 0;
        while j < parts.length - 1 {
            if _isSkipDir(parts[j]) { skipIt = True; break; }
            j = j + 1;
        }
        if not skipIt and _isSkipFile(parts[parts.length - 1]) { skipIt = True; }
        if not skipIt and f.size > _MAX_SIZE { skipIt = True; }
        if skipIt {
            skipped = skipped + 1;
        } else {
            try {
                text = await f.text();
                collected.push({"path": parts.join("/"), "content": text});
            } except Exception as _e {
                skipped = skipped + 1;
            }
        }
        i = i + 1;
    }
    return {"files": collected, "skipped": skipped, "folderName": folderRoot};
}

def _isDashTauri() -> bool {
    return Boolean(globalThis.__TAURI_INTERNALS__);
}

def _dashInvoke(cmd: str, args: Any) -> Any {
    return globalThis.__TAURI_INTERNALS__.invoke(cmd, args);
}

async def _tauriScanDashFolder(dirPath: str, basePath: str, collected: list, skippedCount: Any) -> None {
    try {
        entries = await _dashInvoke("plugin:fs|read_dir", {"path": dirPath});
    } except Exception as _e {
        return;
    }
    i = 0;
    while i < entries.length {
        item = entries[i];
        i = i + 1;
        name = item.name;
        if not name { continue; }
        if item.isDirectory {
            if _isSkipDir(name) {
                skippedCount.value = skippedCount.value + 1;
                continue;
            }
            childBase = (basePath + "/" + name if basePath else name);
            childPath = dirPath + "/" + name;
            await _tauriScanDashFolder(childPath, childBase, collected, skippedCount);
        } else {
            if _isSkipFile(name) {
                skippedCount.value = skippedCount.value + 1;
                continue;
            }
            relPath = (basePath + "/" + name if basePath else name);
            fullPath = dirPath + "/" + name;
            try {
                content = await _dashInvoke("plugin:fs|read_text_file", {"path": fullPath});
                collected.push({"path": relPath, "content": content});
            } except Exception as _e2 {
                skippedCount.value = skippedCount.value + 1;
            }
        }
    }
}

async def _tauriPickAndScan() -> Any {
    selected = await _dashInvoke("plugin:dialog|open", {
        "directory": True,
        "multiple": False,
        "recursive": False,
        "title": "Select Folder"
    });
    if not selected { return None; }
    parts = selected.split("/");
    folderRoot = parts[parts.length - 1] or "";
    collected: list = [];
    skippedObj = {"value": 0};
    await _tauriScanDashFolder(selected, "", collected, skippedObj);
    return {"files": collected, "skipped": skippedObj.value, "folderName": folderRoot};
}

"""Dashboard: left sidebar navbar + project grid."""
def:pub DashboardPage() -> Any {
    navigate = useNavigate();
    community = useCommunity();
    dash = useDashboard(community.refresh);
    userSettings = useUserSettings();
    themeState = useTheme();
    has searchQuery: str = "";
    has currentSection: str = "home";
    has dashboardTab: str = "recent";
    has projectSort: str = "updated";
    has newGlobalKey: str = "";
    has newGlobalVal: str = "";
    has buildPrompt: str = "";
    has isScanning: bool = False;
    has folderDragOver: bool = False;
    has githubCloneUrl: str = "";

    folderInputRef = useRef(None);

    isNewUser = not dash.isLoading and dash.projects.length == 0;

    searchInputRef = useRef(None);
    buildInputRef = useRef(None);
    useHotkeys([["mod+k", lambda(e: Any) -> None {
        e.preventDefault();
        if searchInputRef.current { searchInputRef.current.focus(); }
    }]]);

    def handleLogout() -> None {
        jacLogout();
        localStorage.removeItem("jac_guest_creds");
        localStorage.removeItem("jac_display_name");
        navigate("/auth");
    }

    def handleBuildSubmit() -> None {
        if not buildPrompt.trim() or dash.isCreating { return; }
        quickCreateFn = dash.quickCreate;
        quickCreateFn.call(None, buildPrompt);
    }

    def formatDate(isoStr: str) -> str {
        if not isoStr { return "Never"; }
        try {
            d = Reflect.construct(Date, [isoStr]);
            return d.toLocaleDateString();
        } except Exception {
            return isoStr;
        }
    }

    def handleModalClose() -> None {
        setter = dash.setCreateModalOpen;
        setter.call(None, False);
        modeSetter = dash.setCreateMode;
        modeSetter.call(None, "template");
        folderFilesSetter = dash.setFolderFiles;
        folderFilesSetter.call(None, []);
        folderNameSetter = dash.setFolderName;
        folderNameSetter.call(None, "");
    }

    filteredProjects = dash.projects.filter(lambda p: Any -> Any {
        q = searchQuery;
        if not q { return True; }
        return p.name.toLowerCase().includes(q.toLowerCase());
    });

    sortedProjects = useMemo(lambda -> Any {
        arr = filteredProjects.slice();
        if projectSort == "name" {
            arr.sort(lambda a: Any, b: Any -> Any { return a.name.localeCompare(b.name); });
        } elif projectSort == "created" {
            arr.sort(lambda a: Any, b: Any -> Any {
                da = Reflect.construct(Date, [a.created_at or ""]);
                db = Reflect.construct(Date, [b.created_at or ""]);
                return db.getTime() - da.getTime();
            });
        } else {
            arr.sort(lambda a: Any, b: Any -> Any {
                da = Reflect.construct(Date, [a.updated_at or ""]);
                db = Reflect.construct(Date, [b.updated_at or ""]);
                return db.getTime() - da.getTime();
            });
        }
        return arr;
    }, [filteredProjects, projectSort]);

    recentProjects = useMemo(lambda -> Any {
        arr = dash.projects.slice();
        arr.sort(lambda a: Any, b: Any -> Any {
            da = Reflect.construct(Date, [a.updated_at or ""]);
            db = Reflect.construct(Date, [b.updated_at or ""]);
            return db.getTime() - da.getTime();
        });
        return arr.slice(0, 8);
    }, [dash.projects]);

    sidebarRecents = useMemo(lambda -> Any {
        arr = dash.projects.slice();
        arr.sort(lambda a: Any, b: Any -> Any {
            da = Reflect.construct(Date, [a.updated_at or ""]);
            db = Reflect.construct(Date, [b.updated_at or ""]);
            return db.getTime() - da.getTime();
        });
        return arr.slice(0, 5);
    }, [dash.projects]);

    displayName = (dash.user.display_name if dash.user and dash.user.display_name else "User");

    return <div className="flex h-screen bg-background">
        <aside className="bg-background border-r border-border flex flex-col h-screen overflow-hidden w-[280px] flex-shrink-0">

            <div className="px-4 border-b border-border flex items-center justify-between h-[52px] flex-shrink-0">
                <div className="flex items-center gap-2 cursor-pointer" onClick={lambda { navigate("/"); }}>
                    <img src="/static/assets/logo-builder.png" className="w-[26px] h-[26px] rounded-md" alt="logo" />
                    <div className="text-sm font-bold font-mono tracking-[-0.02em] leading-none">
                        <span className="text-primary">{"jac"}</span>
                        <span className="text-muted-foreground font-medium">{" builder"}</span>
                    </div>
                </div>
            </div>

            <div className="flex-1 min-h-0 flex flex-col overflow-hidden">
                <div className="px-3 pt-3 pb-1 flex-shrink-0">
                    <Button
                        variant="ghost" size="sm"
                        className={cn("w-full justify-start px-2.5 py-[7px] text-[13px]", (currentSection == "home" and "bg-primary/15 text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                        onClick={lambda { currentSection = "home"; }}
                    >
                        <div className="flex items-center gap-2 w-full">
                            <HugeiconsIcon icon={Home01Icon} strokeWidth={2} className={cn("size-4", (currentSection == "home" and "text-primary" or "text-muted-foreground"))} />
                            <span className="text-sm flex-1 text-left">{"Home"}</span>
                        </div>
                    </Button>
                </div>

                <div className="px-3 pt-3 pb-1 flex-shrink-0">
                    <span className="text-[10px] font-bold uppercase tracking-[0.09em] text-muted-foreground mb-1 block px-2.5">{"Projects"}</span>
                    <Button
                        variant="ghost" size="sm"
                        className={cn("w-full justify-start px-2.5 py-[7px] text-[13px]", (currentSection == "projects" and "bg-primary/15 text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                        onClick={lambda { currentSection = "projects"; }}
                    >
                        <div className="flex items-center gap-2 w-full">
                            <HugeiconsIcon icon={GridTableIcon} strokeWidth={2} className={cn("size-4", (currentSection == "projects" and "text-primary" or "text-muted-foreground"))} />
                            <span className="text-sm flex-1 text-left">{"All Projects"}</span>
                            <Badge variant="secondary" className="text-[10px] min-w-[20px] h-4 px-1.5">
                                {String(dash.projects.length)}
                            </Badge>
                        </div>
                    </Button>
                    <Button
                        variant="ghost" size="sm"
                        className={cn("w-full justify-start px-2.5 py-[7px] text-[13px]", (currentSection == "community" and "bg-primary/15 text-foreground" or "text-muted-foreground hover:bg-accent hover:text-foreground"))}
                        onClick={lambda { currentSection = "community"; }}
                    >
                        <div className="flex items-center gap-2 w-full">
                            <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className={cn("size-4", (currentSection == "community" and "text-primary" or "text-muted-foreground"))} />
                            <span className="text-sm flex-1 text-left">{"Community"}</span>
                            <Badge variant="secondary" className="text-[10px] min-w-[20px] h-4 px-1.5">
                                {String(community.itemCount)}
                            </Badge>
                        </div>
                    </Button>
                </div>

                {sidebarRecents.length > 0 and <ScrollArea className="flex-1 min-h-0">
                    <div className="px-3 pt-3 pb-2">
                        <span className="text-[10px] font-bold uppercase tracking-[0.09em] text-muted-foreground mb-1 block px-2.5">{"Recents"}</span>
                        {sidebarRecents.map(lambda p: Any -> Any {
                            return <Button
                                key={p.id}
                                variant="ghost" size="sm"
                                className="w-full justify-start px-2.5 py-[5px] text-xs text-muted-foreground hover:bg-accent hover:text-foreground"
                                onClick={lambda { navigate("/project/" + p.id); }}
                            >
                                <div className="flex items-center gap-2 w-full">
                                    <HugeiconsIcon icon={CodeIcon} strokeWidth={2} className="size-3.5 text-muted-foreground shrink-0" />
                                    <span className="text-xs truncate flex-1 text-left">{p.name}</span>
                                </div>
                            </Button>;
                        })}
                    </div>
                </ScrollArea>}

                <div className="px-3 pb-2 flex-shrink-0" />
            </div>

            <div className="border-t border-border flex-shrink-0">
                <UserPopover
                    displayName={displayName}
                    themeState={themeState}
                    onSettings={lambda { userSettings.openSettings(); }}
                    onLogout={lambda { handleLogout(); }}
                    version={String(globalThis.__JAC_IDE_VERSION__ or "0.0.0")}
                />
            </div>

        </aside>

        <main className="flex-1 overflow-auto">
            {currentSection == "community" and <CommunityGallery
                community={community}
                currentUserId={(dash.user.user_id if dash.user else "")}
            />}

            {currentSection == "home" and <div className="flex flex-col h-full bg-gradient-hero">
                <div className={cn("px-7 flex flex-col items-center justify-center", (isNewUser and "min-h-[55vh] pt-0 pb-0" or "pt-12 pb-8"))}>
                    <div className="max-w-[720px] w-full flex flex-col items-center text-center">
                        <h1 className={cn("font-semibold text-foreground", (isNewUser and "text-4xl mb-3" or "text-3xl mb-2"))}>
                            {"Ready to build, "}
                            <span className="text-primary">{displayName}</span>
                            {"?"}
                        </h1>
                        <p className={cn("text-foreground/70", (isNewUser and "text-base mb-8" or "text-sm mb-6"))}>
                            {(isNewUser and "Describe your idea and we'll generate a Jac app for you" or "Start a new project or continue where you left off")}
                        </p>
                        <div className={cn("w-full", (isNewUser and "max-w-[620px]" or "max-w-[560px]"))}>
                            <div
                                className={cn(
                                    "w-full flex flex-row items-center gap-3 gradient-border-input focus-within:border-primary/40 transition-all cursor-text",
                                    (isNewUser and "h-14 px-5 rounded-2xl shadow-lg" or "h-12 px-5 rounded-xl shadow-sm")
                                )}
                                onClick={lambda { if buildInputRef.current { buildInputRef.current.focus(); } }}
                            >
                                <HugeiconsIcon icon={AiChat02Icon} strokeWidth={2} className={cn("text-primary shrink-0", (isNewUser and "size-6" or "size-5"))} />
                                <input
                                    ref={buildInputRef}
                                    type="text"
                                    className={cn("flex-1 h-full min-w-0 bg-transparent text-foreground placeholder:text-muted-foreground outline-none border-none p-0 m-0 shadow-none", (isNewUser and "text-base" or "text-sm"))}
                                    placeholder="Describe what you want to build..."
                                    value={buildPrompt}
                                    onChange={lambda(e: Any) { buildPrompt = e.currentTarget.value; }}
                                    onKeyDown={lambda(e: Any) { if e.key == "Enter" { e.preventDefault(); handleBuildSubmit(); } }}
                                    disabled={dash.isCreating}
                                />
                                {dash.isCreating and <Spinner className="size-4 shrink-0" />}
                                {not dash.isCreating and <button
                                    className={cn("shrink-0 rounded-lg transition-colors", (isNewUser and "p-1.5" or "p-1"), ("text-primary hover:bg-primary/10 cursor-pointer" if buildPrompt.trim() else "text-muted-foreground/40"))}
                                    onClick={lambda(e: Any) { e.stopPropagation(); handleBuildSubmit(); }}
                                    disabled={not buildPrompt.trim()}
                                >
                                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className={cn((isNewUser and "size-5" or "size-4"))} />
                                </button>}
                            </div>
                        </div>
                        {isNewUser and <p className="text-xs text-foreground/50 mt-4">
                            {"or pick a template below to get started"}
                        </p>}
                    </div>
                </div>

                <div className="flex-1 px-5 pb-8">
                    <div className="max-w-[1000px] mx-auto bg-card/80 dark:bg-card/90 rounded-2xl border border-b-0 border-border/50 shadow-xl dashboard-content-panel">
                      <div className="px-6 pt-6 pb-8">
                        {dash.isLoading and <div className="flex flex-col gap-6">
                            <Skeleton className="h-9 w-[300px]" />
                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                                {[1, 2, 3, 4].map(lambda k: int -> Any {
                                    return <div key={String(k)} className="rounded-lg border border-border overflow-hidden">
                                        <Skeleton className="w-full h-[140px] rounded-none" />
                                        <div className="p-3 flex flex-col gap-2">
                                            <Skeleton className="h-4 w-3/4" />
                                            <Skeleton className="h-3 w-1/2" />
                                        </div>
                                    </div>;
                                })}
                            </div>
                        </div>}

                        {not dash.isLoading and isNewUser and <div>
                            <h2 className="text-lg font-semibold text-foreground mb-4">{"Start from a template"}</h2>
                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                                {dash.templates.filter(lambda t: Any -> Any { return t.type != "user"; }).map(lambda t: Any -> Any {
                                    tIcon = (t.id == "client" and SmartPhone01Icon or (t.id == "fullstack" and Layers01Icon or (t.id == "little-x" and AiChat02Icon or (t.id == "shadcn-themed" and PaintBoardIcon or (t.id == "backend-api" and ComputerTerminal01Icon or (t.id == "script" and PlayIcon or SourceCodeSquareIcon))))));
                                    tDesc = (t.id == "client" and "Frontend-only app" or (t.id == "fullstack" and "Full-stack with auth" or (t.id == "little-x" and "Social app example" or (t.id == "shadcn-themed" and "Themed UI starter" or (t.id == "backend-api" and "API server, no frontend" or (t.id == "script" and "Run once, see output" or (t.description or "Starter template")))))));
                                    return <button
                                        key={t.id}
                                        className="group flex items-start gap-3.5 p-4 rounded-xl border border-border bg-card hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer"
                                        onClick={lambda {
                                            setter = dash.setSelectedTemplate;
                                            setter.call(None, t.id);
                                            nameSetter = dash.setNewProjectName;
                                            nameSetter.call(None, "");
                                            modeSetter = dash.setCreateMode;
                                            modeSetter.call(None, "template");
                                            openSetter = dash.setCreateModalOpen;
                                            openSetter.call(None, True);
                                        }}
                                    >
                                        <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                            <HugeiconsIcon icon={tIcon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center gap-1.5">
                                                <span className="text-sm font-medium text-foreground">{t.name}</span>
                                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                            </div>
                                            <span className="text-xs text-muted-foreground mt-0.5 block">{tDesc}</span>
                                        </div>
                                    </button>;
                                })}
                                <button
                                    className="group flex items-start gap-3.5 p-4 rounded-xl border border-dashed border-border hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer bg-transparent"
                                    onClick={lambda {
                                        modeSetter = dash.setCreateMode;
                                        modeSetter.call(None, "folder");
                                        openSetter = dash.setCreateModalOpen;
                                        openSetter.call(None, True);
                                    }}
                                >
                                    <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                        <HugeiconsIcon icon={Folder01Icon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-1.5">
                                            <span className="text-sm font-medium text-foreground">{"Open Folder"}</span>
                                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                        </div>
                                        <span className="text-xs text-muted-foreground mt-0.5 block">{"Create project from local folder"}</span>
                                    </div>
                                </button>
                                <button
                                    className="group flex items-start gap-3.5 p-4 rounded-xl border border-dashed border-border hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer bg-transparent"
                                    onClick={lambda {
                                        modeSetter = dash.setCreateMode;
                                        modeSetter.call(None, "import");
                                        openSetter = dash.setCreateModalOpen;
                                        openSetter.call(None, True);
                                    }}
                                >
                                    <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                        <HugeiconsIcon icon={Upload01Icon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-1.5">
                                            <span className="text-sm font-medium text-foreground">{"Import JacPack"}</span>
                                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                        </div>
                                        <span className="text-xs text-muted-foreground mt-0.5 block">{"From .jacpack file or URL"}</span>
                                    </div>
                                </button>
                                <button
                                    className="group flex items-center gap-3 p-3 rounded-xl border border-border bg-card hover:bg-accent/50 hover:border-primary/20 transition-all duration-200 cursor-pointer text-left"
                                    onClick={lambda {
                                        dash.setCreateMode("github");
                                        openSetter = dash.setCreateModalOpen;
                                        openSetter.call(None, True);
                                    }}
                                >
                                    <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                        <HugeiconsIcon icon={GitBranchIcon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-1.5">
                                            <span className="text-sm font-medium text-foreground">{"Import from GitHub"}</span>
                                            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                        </div>
                                        <span className="text-xs text-muted-foreground mt-0.5 block">{"Clone a GitHub repository"}</span>
                                    </div>
                                </button>
                            </div>
                        </div>}

                        {not dash.isLoading and not isNewUser and <Tabs value={dashboardTab} onValueChange={lambda v: Any { dashboardTab = v or "recent"; }}>
                            <TabsList className="mb-5">
                                <TabsTrigger value="recent">{"Recently viewed"}</TabsTrigger>
                                <TabsTrigger value="projects">{"My projects"}</TabsTrigger>
                                <TabsTrigger value="templates">{"Templates"}</TabsTrigger>
                            </TabsList>

                            <TabsContent value="recent">
                                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                                    {recentProjects.map(lambda p: Any -> Any {
                                        return <ProjectCard
                                            key={p.id}
                                            project={p}
                                            thumbnail={dash.thumbnails[p.id]}
                                            onOpen={lambda { navigate("/project/" + p.id); }}
                                            onRename={lambda { dash.openRenameModal(p); }}
                                            onShare={lambda { dash.openShareModal(p); }}
                                            onDelete={lambda { dash.openDeleteConfirm(p); }}
                                            formatDate={formatDate}
                                        />;
                                    })}
                                </div>
                            </TabsContent>

                            <TabsContent value="projects">
                                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                                    {dash.projects.map(lambda p: Any -> Any {
                                        return <ProjectCard
                                            key={p.id}
                                            project={p}
                                            thumbnail={dash.thumbnails[p.id]}
                                            onOpen={lambda { navigate("/project/" + p.id); }}
                                            onRename={lambda { dash.openRenameModal(p); }}
                                            onShare={lambda { dash.openShareModal(p); }}
                                            onDelete={lambda { dash.openDeleteConfirm(p); }}
                                            formatDate={formatDate}
                                        />;
                                    })}
                                    <Card
                                        className="cursor-pointer group border-dashed border-2 border-border bg-transparent hover:border-primary/40 hover:bg-primary/5 transition-all duration-200 overflow-hidden"
                                        onClick={lambda {
                                            modeSetter = dash.setCreateMode;
                                            modeSetter.call(None, "template");
                                            openSetter = dash.setCreateModalOpen;
                                            openSetter.call(None, True);
                                        }}
                                    >
                                        <div className="relative w-full h-[140px] flex items-center justify-center">
                                            <div className="flex flex-col items-center gap-2">
                                                <div className="size-10 rounded-xl bg-primary/10 group-hover:bg-primary/20 flex items-center justify-center transition-colors duration-200">
                                                    <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-5 text-primary" />
                                                </div>
                                                <span className="text-xs text-muted-foreground group-hover:text-foreground transition-colors">{"New Project"}</span>
                                            </div>
                                        </div>
                                    </Card>
                                </div>
                            </TabsContent>

                            <TabsContent value="templates">
                                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                                    {dash.templates.filter(lambda t: Any -> Any { return t.type != "user"; }).map(lambda t: Any -> Any {
                                        tIcon = (t.id == "client" and SmartPhone01Icon or (t.id == "fullstack" and Layers01Icon or (t.id == "little-x" and AiChat02Icon or (t.id == "shadcn-themed" and PaintBoardIcon or (t.id == "backend-api" and ComputerTerminal01Icon or (t.id == "script" and PlayIcon or SourceCodeSquareIcon))))));
                                        tDesc = (t.id == "client" and "Frontend-only app" or (t.id == "fullstack" and "Full-stack with auth" or (t.id == "little-x" and "Social app example" or (t.id == "shadcn-themed" and "Themed UI starter" or (t.id == "backend-api" and "API server, no frontend" or (t.id == "script" and "Run once, see output" or (t.description or "Starter template")))))));
                                        return <button
                                            key={t.id}
                                            className="group flex items-start gap-3.5 p-4 rounded-xl border border-border bg-card hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer"
                                            onClick={lambda {
                                                setter = dash.setSelectedTemplate;
                                                setter.call(None, t.id);
                                                nameSetter = dash.setNewProjectName;
                                                nameSetter.call(None, "");
                                                modeSetter = dash.setCreateMode;
                                                modeSetter.call(None, "template");
                                                openSetter = dash.setCreateModalOpen;
                                                openSetter.call(None, True);
                                            }}
                                        >
                                            <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                                <HugeiconsIcon icon={tIcon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-1.5">
                                                    <span className="text-sm font-medium text-foreground">{t.name}</span>
                                                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                                </div>
                                                <span className="text-xs text-muted-foreground mt-0.5 block">{tDesc}</span>
                                            </div>
                                        </button>;
                                    })}
                                    {dash.templates.filter(lambda t: Any -> Any { return t.type == "user"; }).map(lambda t: Any -> Any {
                                        return <button
                                            key={t.id}
                                            className="group flex items-start gap-3.5 p-4 rounded-xl border border-border bg-card hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer"
                                            onClick={lambda {
                                                setter = dash.setSelectedTemplate;
                                                setter.call(None, t.id);
                                                nameSetter = dash.setNewProjectName;
                                                nameSetter.call(None, "");
                                                modeSetter = dash.setCreateMode;
                                                modeSetter.call(None, "template");
                                                openSetter = dash.setCreateModalOpen;
                                                openSetter.call(None, True);
                                            }}
                                        >
                                            <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                                <HugeiconsIcon icon={Upload01Icon} strokeWidth={1.5} className="size-5 text-primary shrink-0" />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-1.5">
                                                    <span className="text-sm font-medium text-foreground">{t.name}</span>
                                                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                                </div>
                                                <span className="text-xs text-muted-foreground mt-0.5 block">{"User template"}</span>
                                            </div>
                                        </button>;
                                    })}
                                    <button
                                        className="group flex items-start gap-3.5 p-4 rounded-xl border border-dashed border-border hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer bg-transparent"
                                        onClick={lambda {
                                            modeSetter = dash.setCreateMode;
                                            modeSetter.call(None, "folder");
                                            openSetter = dash.setCreateModalOpen;
                                            openSetter.call(None, True);
                                        }}
                                    >
                                        <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                            <HugeiconsIcon icon={Folder01Icon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center gap-1.5">
                                                <span className="text-sm font-medium text-foreground">{"Open Folder"}</span>
                                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                            </div>
                                            <span className="text-xs text-muted-foreground mt-0.5 block">{"Create project from local folder"}</span>
                                        </div>
                                    </button>
                                    <button
                                        className="group flex items-start gap-3.5 p-4 rounded-xl border border-dashed border-border hover:border-primary/40 hover:bg-accent/50 transition-colors duration-150 text-left cursor-pointer bg-transparent"
                                        onClick={lambda {
                                            modeSetter = dash.setCreateMode;
                                            modeSetter.call(None, "import");
                                            openSetter = dash.setCreateModalOpen;
                                            openSetter.call(None, True);
                                        }}
                                    >
                                        <div className="size-10 rounded-lg bg-muted flex items-center justify-center shrink-0 group-hover:bg-primary/10 transition-colors duration-150">
                                            <HugeiconsIcon icon={Upload01Icon} strokeWidth={1.5} className="size-5 text-muted-foreground group-hover:text-primary transition-colors duration-150" />
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center gap-1.5">
                                                <span className="text-sm font-medium text-foreground">{"Import JacPack"}</span>
                                                <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-3.5 text-muted-foreground opacity-0 -translate-x-1 group-hover:opacity-100 group-hover:translate-x-0 transition-all duration-150" />
                                            </div>
                                            <span className="text-xs text-muted-foreground mt-0.5 block">{"From .jacpack file or URL"}</span>
                                        </div>
                                    </button>
                                </div>
                            </TabsContent>
                        </Tabs>}
                      </div>
                    </div>
                </div>
            </div>}

            {currentSection == "projects" and <div className="p-7">
                {dash.isLoading and <div className="flex flex-col gap-6 max-w-[960px] mx-auto">
                    <div className="flex items-start justify-between">
                        <Skeleton className="h-8 w-[180px]" />
                        <Skeleton className="h-9 w-[130px]" />
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                        {[1, 2, 3, 4, 5, 6].map(lambda k: int -> Any {
                            return <div key={String(k)} className="rounded-lg border border-border overflow-hidden">
                                <Skeleton className="w-full h-[140px] rounded-none" />
                                <div className="p-3 flex flex-col gap-2">
                                    <Skeleton className="h-4 w-3/4" />
                                    <Skeleton className="h-3 w-1/2" />
                                </div>
                            </div>;
                        })}
                    </div>
                </div>}
                {not dash.isLoading and <div className="flex flex-col gap-5 max-w-[960px] mx-auto">
                    <div className="flex items-center justify-between gap-4">
                        <div className="flex items-center gap-3">
                            <h2 className="text-xl font-semibold text-foreground">{"Projects"}</h2>
                            <Badge variant="secondary" className="text-xs">{String(dash.projects.length)}</Badge>
                        </div>
                        <div className="flex items-center gap-2">
                            <div className="relative">
                                <HugeiconsIcon icon={Search01Icon} strokeWidth={2} className="size-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                                <Input
                                    ref={searchInputRef}
                                    placeholder="Search projects..."
                                    value={searchQuery}
                                    onChange={lambda e: Any { searchQuery = e.target.value; }}
                                    className="pl-8 h-8 text-xs w-[200px]"
                                />
                            </div>
                            <Select value={projectSort} onValueChange={lambda v: Any { projectSort = v or "updated"; }}>
                                <SelectTrigger className="h-8 w-[140px] text-xs">
                                    <HugeiconsIcon icon={SortingIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="updated">{"Last edited"}</SelectItem>
                                    <SelectItem value="name">{"Name"}</SelectItem>
                                    <SelectItem value="created">{"Created"}</SelectItem>
                                </SelectContent>
                            </Select>
                            <Button
                                size="sm"
                                onClick={lambda {
                                    modeSetter = dash.setCreateMode;
                                    modeSetter.call(None, "template");
                                    openSetter = dash.setCreateModalOpen;
                                    openSetter.call(None, True);
                                }}
                            >
                                <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-4" />
                                {"New Project"}
                            </Button>
                        </div>
                    </div>

                    {sortedProjects.length == 0 and searchQuery and
                        <Empty className="h-[280px]">
                            <EmptyHeader>
                                <EmptyMedia variant="icon">
                                    <HugeiconsIcon icon={Search01Icon} strokeWidth={1.5} className="size-5" />
                                </EmptyMedia>
                                <EmptyTitle>{"No projects match \"" + searchQuery + "\""}</EmptyTitle>
                                <EmptyDescription>{"Try a different search term"}</EmptyDescription>
                            </EmptyHeader>
                        </Empty>
                    }

                    {sortedProjects.length == 0 and not searchQuery and
                        <div className="flex flex-col items-center pt-8 pb-12">
                            <div className="flex flex-col items-center text-center mb-8 max-w-md">
                                <div className="size-14 rounded-2xl bg-primary/10 flex items-center justify-center mb-4">
                                    <HugeiconsIcon icon={RocketIcon} strokeWidth={1.5} className="size-7 text-primary" />
                                </div>
                                <h3 className="text-lg font-semibold text-foreground mb-2">{"Start building with Jac"}</h3>
                                <p className="text-sm text-muted-foreground leading-relaxed">
                                    {"Pick a template to create your first project, or import an existing one."}
                                </p>
                            </div>
                            <Button
                                onClick={lambda {
                                    modeSetter = dash.setCreateMode;
                                    modeSetter.call(None, "template");
                                    openSetter = dash.setCreateModalOpen;
                                    openSetter.call(None, True);
                                }}
                            >
                                <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-4" />
                                {"Create Project"}
                            </Button>
                        </div>
                    }

                    {sortedProjects.length > 0 and <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                        {sortedProjects.map(lambda p: Any -> Any {
                            return <ProjectCard
                                key={p.id}
                                project={p}
                                thumbnail={dash.thumbnails[p.id]}
                                onOpen={lambda { navigate("/project/" + p.id); }}
                                onRename={lambda { dash.openRenameModal(p); }}
                                onShare={lambda { dash.openShareModal(p); }}
                                onDelete={lambda { dash.openDeleteConfirm(p); }}
                                formatDate={formatDate}
                            />;
                        })}

                        <Card
                            className="cursor-pointer group border-dashed border-2 border-border bg-transparent hover:border-primary/40 hover:bg-primary/5 transition-all duration-200 overflow-hidden"
                            onClick={lambda {
                                modeSetter = dash.setCreateMode;
                                modeSetter.call(None, "template");
                                openSetter = dash.setCreateModalOpen;
                                openSetter.call(None, True);
                            }}
                        >
                            <div className="relative w-full h-[140px] flex items-center justify-center">
                                <div className="flex flex-col items-center gap-2">
                                    <div className="size-10 rounded-xl bg-primary/10 group-hover:bg-primary/20 flex items-center justify-center transition-colors duration-200">
                                        <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-5 text-primary" />
                                    </div>
                                    <span className="text-xs text-muted-foreground group-hover:text-foreground transition-colors">{"New Project"}</span>
                                </div>
                            </div>
                        </Card>
                    </div>}
                </div>}
            </div>}
        </main>

        <Dialog open={dash.createModalOpen} onOpenChange={lambda v: Any { if not v { handleModalClose(); } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"New Project"}</DialogTitle>
                </DialogHeader>
                <Tabs
                    value={dash.createMode}
                    onValueChange={lambda v: Any {
                        setter = dash.setCreateMode;
                        setter.call(None, v or "template");
                    }}
                >
                    <TabsList className="w-full mb-4">
                        <TabsTrigger value="template" className="flex-1">{"Template"}</TabsTrigger>
                        <TabsTrigger value="folder" className="flex-1">{"Folder"}</TabsTrigger>
                        <TabsTrigger value="import" className="flex-1">{"Import"}</TabsTrigger>
                        <TabsTrigger value="github" className="flex-1">{"GitHub"}</TabsTrigger>
                    </TabsList>

                    <TabsContent value="template">
                        <div className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                                <Label>{"Project Name"}</Label>
                                <Input
                                    placeholder="my-jac-app"
                                    value={dash.newProjectName}
                                    onChange={lambda e: Any { dash.setNewProjectName(e.target.value); }}
                                    disabled={dash.isCreating}
                                />
                            </div>
                            <div className="flex flex-col gap-2">
                                <Label>{"Template"}</Label>
                                <Select
                                    value={dash.selectedTemplate or ""}
                                    onValueChange={lambda v: Any {
                                        setter = dash.setSelectedTemplate;
                                        setter.call(None, v or "");
                                    }}
                                >
                                    <SelectTrigger className="w-full">
                                        <SelectValue placeholder="Choose a template" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {dash.templates.map(lambda t: Any -> Any {
                                            return <SelectItem key={t.id} value={t.id}>{t.name}</SelectItem>;
                                        })}
                                    </SelectContent>
                                </Select>
                            </div>
                            {dash.createError and <Alert variant="destructive">{dash.createError}</Alert>}
                            <Button
                                className="w-full"
                                disabled={not dash.newProjectName or not dash.selectedTemplate or dash.isCreating}
                                onClick={lambda { dash.createProject(dash.newProjectName, dash.selectedTemplate); }}
                            >
                                {dash.isCreating and <Spinner className="size-4" /> or None}
                                {"Create Project"}
                            </Button>
                        </div>
                    </TabsContent>

                    <TabsContent value="folder">
                        <div className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                                <Label>{"Project Name"}</Label>
                                <Input
                                    placeholder={dash.folderName or "my-project"}
                                    value={dash.newProjectName}
                                    onChange={lambda e: Any { dash.setNewProjectName(e.target.value); }}
                                    disabled={dash.isCreating or isScanning}
                                />
                            </div>
                            <input
                                ref={folderInputRef}
                                type="file"
                                webkitdirectory=""
                                directory=""
                                multiple={True}
                                style={{"display": "none"}}
                                onChange={lambda(e: Any) {
                                    filesList = e.target.files;
                                    if not filesList or filesList.length == 0 { return; }
                                    isScanning = True;
                                    _scanInputFiles(filesList).then(lambda(result: Any) {
                                        filesSetter = dash.setFolderFiles;
                                        filesSetter.call(None, result.files);
                                        nameSetter = dash.setFolderName;
                                        nameSetter.call(None, result.folderName or "");
                                        if result.folderName and not dash.newProjectName {
                                            projNameSetter = dash.setNewProjectName;
                                            projNameSetter.call(None, result.folderName);
                                        }
                                        isScanning = False;
                                    });
                                }}
                            />
                            <div
                                className={cn(
                                    "border-2 border-dashed rounded-lg p-6 text-center transition-colors cursor-pointer",
                                    (folderDragOver and "border-primary bg-primary/5" or "border-border hover:border-primary/40 hover:bg-accent/30")
                                )}
                                onClick={lambda {
                                    if isScanning or dash.isCreating { return; }
                                    if _isDashTauri() {
                                        isScanning = True;
                                        _tauriPickAndScan().then(lambda(result: Any) {
                                            if result {
                                                filesSetter = dash.setFolderFiles;
                                                filesSetter.call(None, result.files);
                                                nameSetter = dash.setFolderName;
                                                nameSetter.call(None, result.folderName or "");
                                                if result.folderName and not dash.newProjectName {
                                                    projNameSetter = dash.setNewProjectName;
                                                    projNameSetter.call(None, result.folderName);
                                                }
                                            }
                                            isScanning = False;
                                        });
                                        return;
                                    }
                                    if folderInputRef.current {
                                        folderInputRef.current.value = "";
                                        folderInputRef.current.click();
                                    }
                                }}
                                onDragOver={lambda(e: Any) {
                                    e.preventDefault();
                                    e.stopPropagation();
                                    folderDragOver = True;
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
                                    items = e.dataTransfer.items;
                                    if not items or items.length == 0 { return; }
                                    firstItem = items[0];
                                    if not firstItem.webkitGetAsEntry {
                                        if _isDashTauri() {
                                            isScanning = True;
                                            _tauriPickAndScan().then(lambda(result: Any) {
                                                if result {
                                                    filesSetter = dash.setFolderFiles;
                                                    filesSetter.call(None, result.files);
                                                    nameSetter = dash.setFolderName;
                                                    nameSetter.call(None, result.folderName or "");
                                                    if result.folderName and not dash.newProjectName {
                                                        projNameSetter = dash.setNewProjectName;
                                                        projNameSetter.call(None, result.folderName);
                                                    }
                                                }
                                                isScanning = False;
                                            });
                                        }
                                        return;
                                    }
                                    fsEnt = firstItem.webkitGetAsEntry();
                                    if not fsEnt or not fsEnt.isDirectory { return; }
                                    rootName = fsEnt.name;
                                    nameSetter = dash.setFolderName;
                                    nameSetter.call(None, rootName);
                                    if not dash.newProjectName {
                                        projNameSetter = dash.setNewProjectName;
                                        projNameSetter.call(None, rootName);
                                    }
                                    isScanning = True;
                                    filesList = e.dataTransfer.files;
                                    _scanInputFiles(filesList).then(lambda(result: Any) {
                                        filesSetter = dash.setFolderFiles;
                                        filesSetter.call(None, result.files);
                                        isScanning = False;
                                    });
                                }}
                            >
                                {isScanning and <div className="flex flex-col items-center gap-2">
                                    <Spinner className="size-6" />
                                    <span className="text-sm text-muted-foreground">{"Scanning files..."}</span>
                                </div> or <div className="flex flex-col items-center gap-2">
                                    <HugeiconsIcon icon={FolderOpenIcon} strokeWidth={1.5} className="size-8 text-muted-foreground" />
                                    <span className="text-sm text-muted-foreground">{"Drag folder here or click to browse"}</span>
                                    <span className="text-xs text-muted-foreground/70">{".git, node_modules, binaries auto-filtered"}</span>
                                </div>}
                            </div>
                            {dash.folderFiles.length > 0 and <div className="text-sm text-muted-foreground">
                                {String(dash.folderFiles.length) + " files ready"}
                                {dash.folderName and <span className="text-xs ml-1.5">{" from " + dash.folderName + "/"}</span> or None}
                            </div> or None}
                            {dash.createError and <Alert variant="destructive">{dash.createError}</Alert>}
                            <Button
                                className="w-full"
                                disabled={dash.folderFiles.length == 0 or dash.isCreating or isScanning}
                                onClick={lambda {
                                    projName = dash.newProjectName or dash.folderName or "my-project";
                                    dash.createFromFolder(projName, dash.folderFiles);
                                }}
                            >
                                {dash.isCreating and <Spinner className="size-4" /> or None}
                                {"Create Project"}
                            </Button>
                        </div>
                    </TabsContent>

                    <TabsContent value="import">
                        <div className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                                <Label>{"Project Name"}</Label>
                                <Input
                                    placeholder="my-imported-app"
                                    value={dash.newProjectName}
                                    onChange={lambda e: Any { dash.setNewProjectName(e.target.value); }}
                                    disabled={dash.isCreating}
                                />
                            </div>
                            <div className="flex flex-col gap-2">
                                <Label>{"JacPack URL"}</Label>
                                <div className="relative">
                                    <HugeiconsIcon icon={Link01Icon} strokeWidth={2} className="size-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-muted-foreground pointer-events-none" />
                                    <Input
                                        placeholder="https://example.com/app.jacpack"
                                        value={dash.jacpackUrl}
                                        onChange={lambda e: Any {
                                            setter = dash.setJacpackUrl;
                                            setter.call(None, e.target.value);
                                        }}
                                        disabled={dash.isCreating or Boolean(dash.jacpackFile)}
                                        className="pl-8"
                                    />
                                </div>
                                {dash.jacpackFile and <span className="text-xs text-muted-foreground">{"Clear uploaded file to use URL instead"}</span>}
                            </div>
                            <div className="flex flex-col gap-2">
                                <Label>{"Or upload a file"}</Label>
                                <input
                                    id="jacpack-file-input"
                                    type="file"
                                    accept=".jacpack"
                                    style={{"display": "none"}}
                                    onChange={lambda e: Any {
                                        f = e.target.files and e.target.files[0];
                                        if f {
                                            setter = dash.setJacpackFile;
                                            setter.call(None, f);
                                        }
                                    }}
                                />
                                <Button
                                    variant={not dash.jacpackFile and "outline" or "default"}
                                    size="sm"
                                    disabled={dash.isCreating}
                                    onClick={lambda {
                                        el = document.getElementById("jacpack-file-input");
                                        if el { el.click(); }
                                    }}
                                >
                                    <HugeiconsIcon icon={Upload01Icon} strokeWidth={2} className="size-4" />
                                    {(dash.jacpackFile.name if dash.jacpackFile else "Upload .jacpack file")}
                                </Button>
                                {dash.jacpackFile and <Button
                                    variant="ghost" size="sm"
                                    onClick={lambda {
                                        setter = dash.setJacpackFile;
                                        setter.call(None, None);
                                        el = document.getElementById("jacpack-file-input");
                                        if el { el.value = ""; }
                                    }}
                                >
                                    {"Clear file"}
                                </Button>}
                            </div>
                            {dash.createError and <Alert variant="destructive">{dash.createError}</Alert>}
                            <Button
                                className="w-full"
                                disabled={not dash.newProjectName or (not dash.jacpackUrl and not dash.jacpackFile) or dash.isCreating}
                                onClick={lambda { dash.importProject(dash.newProjectName, dash.jacpackUrl, dash.jacpackFile); }}
                            >
                                {dash.isCreating and <Spinner className="size-4" /> or None}
                                {"Import Project"}
                            </Button>
                        </div>
                    </TabsContent>

                    <TabsContent value="github">
                        <div className="flex flex-col gap-4">
                            <div className="flex flex-col gap-2">
                                <Label>{"Clone URL"}</Label>
                                <Input
                                    placeholder="https://github.com/user/repo.git"
                                    value={githubCloneUrl}
                                    onChange={lambda e: Any { githubCloneUrl = e.target.value; }}
                                    disabled={dash.isCreating}
                                />
                            </div>
                            <div className="flex flex-col gap-2">
                                <Label>{"Project Name"}</Label>
                                <Input
                                    placeholder="my-project"
                                    value={dash.newProjectName}
                                    onChange={lambda e: Any { dash.setNewProjectName(e.target.value); }}
                                    disabled={dash.isCreating}
                                />
                            </div>
                            {dash.createError and <Alert variant="destructive">{dash.createError}</Alert>}
                            <Button
                                className="w-full"
                                disabled={not githubCloneUrl or not dash.newProjectName or dash.isCreating}
                                onClick={lambda { dash.importFromGithub(dash.newProjectName, githubCloneUrl); }}
                            >
                                {dash.isCreating and <Spinner className="size-4" /> or None}
                                {"Clone Repository"}
                            </Button>
                        </div>
                    </TabsContent>
                </Tabs>
            </DialogContent>
        </Dialog>

        <Dialog open={dash.shareModalOpen} onOpenChange={lambda v: Any { if not v { dash.closeShareModal(); } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Share to Community"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    <div className="flex flex-col gap-2">
                        <Label>{"Name"}</Label>
                        <Input
                            placeholder="My Awesome App"
                            value={dash.shareName}
                            onChange={lambda e: Any {
                                setter = dash.setShareName;
                                setter.call(None, e.target.value);
                            }}
                            disabled={dash.isSharing}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label>{"Description"}</Label>
                        <Textarea
                            placeholder="A short description of your project..."
                            value={dash.shareDescription}
                            onChange={lambda e: Any {
                                setter = dash.setShareDescription;
                                setter.call(None, e.target.value);
                            }}
                            disabled={dash.isSharing}
                            rows={3}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label>{"Tags (comma-separated)"}</Label>
                        <Input
                            placeholder="web, demo, api"
                            value={dash.shareTags}
                            onChange={lambda e: Any {
                                setter = dash.setShareTags;
                                setter.call(None, e.target.value);
                            }}
                            disabled={dash.isSharing}
                        />
                    </div>
                    <div className="flex items-center gap-2">
                        <Checkbox
                            id="share-agree"
                            checked={dash.shareAgreed}
                            onCheckedChange={lambda v: Any {
                                setter = dash.setShareAgreed;
                                setter.call(None, Boolean(v));
                            }}
                            disabled={dash.isSharing}
                        />
                        <label htmlFor="share-agree" className="text-sm text-muted-foreground cursor-pointer">
                            {"I agree this project will be publicly visible to all users"}
                        </label>
                    </div>
                    {dash.shareError and <Alert variant="destructive">{dash.shareError}</Alert>}
                    <Button
                        className="w-full"
                        disabled={not dash.shareName or not dash.shareAgreed or dash.isSharing}
                        onClick={lambda {
                            pId = (dash.shareTarget.id if dash.shareTarget else "");
                            dash.shareProject(pId, dash.shareName, dash.shareDescription, dash.shareTags);
                        }}
                    >
                        {dash.isSharing and <Spinner className="size-4" /> or None}
                        <HugeiconsIcon icon={Globe02Icon} strokeWidth={2} className="size-4" />
                        {"Share with Community"}
                    </Button>
                </div>
            </DialogContent>
        </Dialog>

        <Dialog open={dash.renameModalOpen} onOpenChange={lambda v: Any { if not v { dash.closeRenameModal(); } }}>
            <DialogContent className="sm:max-w-sm">
                <DialogHeader>
                    <DialogTitle>{"Rename Project"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    <div className="flex flex-col gap-2">
                        <Label>{"New Name"}</Label>
                        <Input
                            placeholder="my-project"
                            value={dash.renameName}
                            onChange={lambda e: Any {
                                setter = dash.setRenameName;
                                setter.call(None, e.target.value);
                            }}
                            disabled={dash.isRenaming}
                        />
                    </div>
                    {dash.renameError and <Alert variant="destructive">{dash.renameError}</Alert>}
                    <Button
                        className="w-full"
                        disabled={not dash.renameName or dash.isRenaming}
                        onClick={lambda {
                            pId = (dash.renameTarget.id if dash.renameTarget else "");
                            dash.renameProject(pId, dash.renameName);
                        }}
                    >
                        {dash.isRenaming and <Spinner className="size-4" /> or None}
                        {"Save"}
                    </Button>
                </div>
            </DialogContent>
        </Dialog>

        <AlertDialog open={dash.deleteConfirmOpen} onOpenChange={lambda v: Any { if not v { dash.closeDeleteConfirm(); } }}>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>{"Delete Project"}</AlertDialogTitle>
                    <AlertDialogDescription>
                        {"Are you sure you want to delete "}
                        <span className="font-semibold text-foreground">{(dash.deleteConfirmTarget.name if dash.deleteConfirmTarget else "")}</span>
                        {"? This action cannot be undone."}
                    </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel disabled={dash.isDeleting} onClick={lambda { dash.closeDeleteConfirm(); }}>
                        {"Cancel"}
                    </AlertDialogCancel>
                    <AlertDialogAction variant="destructive" disabled={dash.isDeleting} onClick={lambda { dash.confirmDelete(); }}>
                        {("Deleting..." if dash.isDeleting else "Delete")}
                    </AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>

        <Sheet open={userSettings.settingsOpen} onOpenChange={lambda v: Any { if not v { userSettings.closeSettings(); } }}>
            <SheetContent side="right" className="sm:max-w-md">
                <SheetHeader>
                    <SheetTitle>
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={Key01Icon} strokeWidth={2} className="size-4 text-primary" />
                            {"User Settings"}
                        </div>
                    </SheetTitle>
                    <SheetDescription>{"Global environment variables apply to all your projects when running preview"}</SheetDescription>
                </SheetHeader>
                <ScrollArea className="flex-1 px-4">
                    <div className="flex flex-col gap-3">
                        <div className="flex items-center justify-end">
                            <Button
                                size="sm"
                                variant="secondary"
                                disabled={userSettings.globalVarsSaving}
                                onClick={lambda { userSettings.saveGlobalVars(); }}
                            >
                                {userSettings.globalVarsSaving and <Spinner className="size-3" /> or <HugeiconsIcon icon={FloppyDiskIcon} strokeWidth={2} className="size-3" />}
                                {"Save"}
                            </Button>
                        </div>
                        <Separator />
                        {userSettings.globalVarsLoading and <Spinner className="size-4 text-primary" />}
                        {userSettings.globalVars.map(lambda (v: Any) -> Any {
                            vkey = v.key;
                            return <div key={vkey} className="flex items-center gap-2">
                                <span
                                    className="text-xs font-mono text-muted-foreground shrink-0 truncate min-w-[120px]"
                                >{vkey}</span>
                                <PasswordInput
                                    value={v.value}
                                    onChange={lambda (e: Any) -> None { userSettings.updateGlobalVar(vkey, e.target.value); }}
                                    className="flex-1 text-xs font-mono"
                                />
                                <Button
                                    variant="ghost" size="icon-xs"
                                    className="text-destructive hover:text-destructive shrink-0"
                                    onClick={lambda { userSettings.deleteGlobalVar(vkey); }}
                                >
                                    <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                                </Button>
                            </div>;
                        })}
                        {userSettings.globalVars.length == 0 and not userSettings.globalVarsLoading and <span className="text-xs text-muted-foreground">{"No global variables set."}</span>}
                        <div className="flex items-end gap-2 mt-2">
                            <Field className="flex-1 min-w-[100px]">
                                <FieldLabel className="text-[11px] text-muted-foreground">{"Key"}</FieldLabel>
                                <Input
                                    placeholder="OPENAI_API_KEY"
                                    value={newGlobalKey}
                                    onChange={lambda (e: Any) -> None { newGlobalKey = e.target.value; }}
                                    className="h-7 text-xs"
                                />
                            </Field>
                            <Field className="flex-[2] min-w-[140px]">
                                <FieldLabel className="text-[11px] text-muted-foreground">{"Value"}</FieldLabel>
                                <Input
                                    placeholder="sk-..."
                                    value={newGlobalVal}
                                    onChange={lambda (e: Any) -> None { newGlobalVal = e.target.value; }}
                                    className="h-7 text-xs"
                                />
                            </Field>
                            <Button
                                variant="ghost" size="sm"
                                className="text-primary"
                                onClick={lambda {
                                    userSettings.addGlobalVar(newGlobalKey, newGlobalVal);
                                    newGlobalKey = "";
                                    newGlobalVal = "";
                                }}
                                disabled={not newGlobalKey}
                            >
                                <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-3.5" />
                                {"Add"}
                            </Button>
                        </div>
                        {userSettings.globalVarsError and <span className="text-xs text-destructive mt-1">{userSettings.globalVarsError}</span>}
                        <span className="text-xs text-muted-foreground mt-2 italic">{"Restart preview to apply environment variable changes."}</span>
                    </div>
                </ScrollArea>
            </SheetContent>
        </Sheet>

    </div>;
}

"""Reusable project card with custom action menu."""
def:pub ProjectCard(props: Any) -> Any {
    p = props.project;
    thumbnail = props.thumbnail;
    onOpen = props.onOpen;
    onRename = props.onRename;
    onShare = props.onShare;
    onDelete = props.onDelete;
    formatDate = props.formatDate;

    menuOpen = useState(False);
    isMenuOpen = menuOpen[0];
    _setMenuOpen = menuOpen[1];
    menuRef = useRef(None);

    def handleClickOutside() -> None {
        _setMenuOpen.call(None, False);
    }

    useClickOutside(menuRef, handleClickOutside);

    return <Card
        className="cursor-pointer transition-colors duration-150 hover:bg-muted hover:border-primary/35 overflow-hidden group/card"
        onClick={lambda { if not isMenuOpen { openFn = onOpen; openFn.call(None); } }}
    >
        <div className="relative w-full h-[140px] bg-background flex items-center justify-center border-b border-border">
            <div className="absolute inset-0 overflow-hidden">
                {thumbnail
                    and <img src={thumbnail} className="w-full h-full object-cover" alt="" />
                    or <img src="/static/assets/logo-builder.png" className="w-9 h-9 object-contain grayscale opacity-30 absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" alt="" />
                }
            </div>
            <div className="absolute top-2 right-2 z-[2] opacity-0 group-hover/card:opacity-100 transition-opacity">
                <div className="relative" ref={menuRef}>
                    <Button
                        variant="secondary" size="icon-xs"
                        className="size-7 shadow-sm"
                        onClick={lambda(e: Any) {
                            e.stopPropagation();
                            _setMenuOpen.call(None, lambda(prev: Any) -> Any { return not prev; });
                        }}
                    >
                        <HugeiconsIcon icon={MoreHorizontalIcon} strokeWidth={2} className="size-4" />
                    </Button>
                    {isMenuOpen and <div
                        className="absolute top-full right-0 mt-1 z-50 min-w-[160px] rounded-lg p-1 shadow-lg ring-1 ring-foreground/10 bg-popover text-popover-foreground animate-in fade-in-0 zoom-in-95"
                        onClick={lambda(e: Any) { e.stopPropagation(); }}
                    >
                        <button
                            className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground cursor-default"
                            onClick={lambda { _setMenuOpen.call(None, False); openFn = onOpen; openFn.call(None); }}
                        >
                            <HugeiconsIcon icon={CodesandboxIcon} strokeWidth={2} className="size-4" />
                            {"Open"}
                        </button>
                        <button
                            className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground cursor-default"
                            onClick={lambda { _setMenuOpen.call(None, False); renameFn = onRename; renameFn.call(None); }}
                        >
                            <HugeiconsIcon icon={PencilEdit01Icon} strokeWidth={2} className="size-4" />
                            {"Rename"}
                        </button>
                        <button
                            className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground cursor-default"
                            onClick={lambda { _setMenuOpen.call(None, False); shareFn = onShare; shareFn.call(None); }}
                        >
                            <HugeiconsIcon icon={Share01Icon} strokeWidth={2} className="size-4" />
                            {"Share"}
                        </button>
                        <div className="h-px bg-border -mx-1 my-1" />
                        <button
                            className="flex w-full items-center gap-1.5 rounded-md px-2 py-1.5 text-sm text-destructive hover:bg-destructive/10 cursor-default"
                            onClick={lambda { _setMenuOpen.call(None, False); deleteFn = onDelete; deleteFn.call(None); }}
                        >
                            <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-4" />
                            {"Delete"}
                        </button>
                    </div>}
                </div>
            </div>
        </div>
        <CardContent className="flex flex-col gap-1.5 p-3.5">
            <div className="flex items-center gap-1.5">
                <div className="size-2 rounded-full bg-primary flex-shrink-0" />
                <span className="text-sm font-semibold text-foreground truncate">{p.name}</span>
            </div>
            <span className="text-xs text-muted-foreground">{"Updated " + formatDate(p.updated_at)}</span>
        </CardContent>
    </Card>;
}
