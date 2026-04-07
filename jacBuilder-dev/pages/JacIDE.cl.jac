import from react { useState, useEffect, useRef }
import from "@jac/runtime" { useNavigate }
import from ..components.ui.button { Button }
import from ..components.ui.kbd { Kbd }
import from ..components.ui.spinner { Spinner }
import from ..components.ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }
import from ..components.ui.input { Input }
import from ..components.ui.label { Label }
import from ..components.ui.textarea { Textarea }
import from ..components.ui.checkbox { Checkbox }
import from ..components.ui.alert { Alert }
import from ..components.ui.separator { Separator }
import from ..components.ui.breadcrumb { Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbPage, BreadcrumbSeparator }
import from ..lib.utils { cn }
import from ..utils.hotkeys { useHotkeys }
import from ..utils.toast { notify }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@monaco-editor/react" { Editor, DiffEditor }

import from ..hooks.useIDE { useIDE }
import from ..hooks.useIDEModals { useIDEModals }
import from "..components.ui.resizable" { ResizablePanelGroup, ResizablePanel, ResizableHandle }
import from ..hooks.useEditorSetup { useEditorSetup }
import from ..hooks.useChatMode { useChatMode }
import from ..hooks.useProjectSettings { useProjectSettings }
import from ..hooks.useLSP { useLSP }
import from ..hooks.useGit { useGit }
import from ..hooks.useTheme { useTheme }
import from ..components.ide.ActivityBar { ActivityBar }
import from ..components.ide.StatusBar { StatusBar }
import from ..components.ide.RunPanel { RunPanel }
import from ..components.ide.SettingsPanel { SettingsPanel }
import from ..components.ide.FileTree { FileTree }
import from ..components.ide.EditorTabs { EditorTabs }
import from ..components.ide.TerminalPanel { TerminalPanel }
import from ..components.ide.TerminalArea { TerminalArea }
import from ..components.ide.IDEPreviewPanel { IDEPreviewPanel }
import from ..components.ide.CommandPalette { CommandPalette }
import from ..components.ide.IDEModals { IDEModals }
import from ..components.ide.ChatPanel { ChatPanel }
import from ..components.ide.WorkspaceSymbolSearch { WorkspaceSymbolSearch }
import from ..components.ide.SearchPanel { SearchPanel }
import from ..components.ide.GitPanel { GitPanel }
import from ..components.ide.ExportPanel { ExportPanel }
import from ..hooks.useFolderUpload { useFolderUpload }
import from ..components.ui.progress { Progress }
import from ..services.ideService { idePreviewScreenshot, ideExportVersionDownload, ideExportZipDownload, communitySubmit, runInTerminal }

def:pub JacIDE() -> Any {
    ide = useIDE();
    modals = useIDEModals(ide);
    lspRef = useRef(None);
    themeState = useTheme();
    editor = useEditorSetup(ide, lspRef, themeState.resolvedTheme);
    chat = useChatMode(ide);
    navigate = useNavigate();
    settings = useProjectSettings(ide.projectId);
    workspacePath = (ide.project.repo_path if ide.project and ide.project.repo_path else "");
    lsp = useLSP(ide.userId, ide.projectId, workspacePath, editor.monacoRef, editor.monacoReady, ide.files, navigateToSymbol);
    git = useGit(ide.projectId);
    folderUpload = useFolderUpload(ide.projectId, lambda {
        ide.refreshFiles();
        git.refresh();
        notify("Upload complete", "Folder uploaded successfully", "green");
    });

    monacoThemeName = "jac-theme-light" if themeState.resolvedTheme == "light" else "jac-theme-dark";

    has terminalCollapsed: bool = False;
    has activeTerminalTab: str = "output";
    has terminalContent: str = "";
    has showPreview: bool = True;
    has newFileTrigger: int = 0;
    has shareModalOpen: bool = False;
    has shareName: str = "";
    has shareDescription: str = "";
    has shareTags: str = "";
    has shareAgreed: bool = False;
    has isSharing: bool = False;
    has shareError: str = "";
    has symbolSearchOpen: bool = False;
    has revealSignal: int = 0;

    has activeSidebarView: str = "chat";
    has sidebarCollapsed: bool = False;
    has cursorLine: int = 1;
    has cursorColumn: int = 1;

    useEffect(lambda -> None {
        lspRef.current = lsp;
    }, [lsp.lspReady]);

    prevTabsRef = useRef([]);
    useEffect(lambda -> None {
        if not lsp.lspReady { return; }
        prevPaths = {};
        for p in prevTabsRef.current {
            prevPaths[p] = True;
        }
        currentPaths = {};
        for tab in ide.openTabs {
            currentPaths[tab.path] = True;
            if not prevPaths[tab.path] and not tab.isBinary and not tab.isDiff {
                lsp.sendDidOpen(tab.path, tab.content or "");
            }
        }
        for p in prevTabsRef.current {
            if not currentPaths[p] and not p.startsWith("diff://") {
                lsp.sendDidClose(p);
            }
        }
        newPaths = [];
        for tab in ide.openTabs {
            newPaths.push(tab.path);
        }
        prevTabsRef.current = newPaths;
    }, [ide.openTabs, lsp.lspReady]);

    activeTabData = None;
    for tab in ide.openTabs {
        if tab.path == ide.activeTab {
            activeTabData = tab;
            break;
        }
    }
    isImageTab = activeTabData and activeTabData.isBinary;
    isDiffTab = activeTabData and activeTabData.isDiff;

    chatWasLoadingRef = useRef(False);
    useEffect(lambda -> None {
        if chatWasLoadingRef.current and not chat.isLoading {
            git.refresh();
        }
        chatWasLoadingRef.current = chat.isLoading;
    }, [chat.isLoading]);

    useEffect(lambda -> None {
        if ide.isSetup and ide.versions and ide.versions.length > 0 {
            git.refresh();
        }
    }, [ide.versions]);

    useEffect(lambda -> None {
        terminalContent = ide.terminalContent;
    }, [ide.terminalContent]);

    useEffect(lambda -> None {
        if ide.projectType == "script" {
            showPreview = False;
            return;
        }
        if ide.previewStatus == "running" or ide.previewStatus == "starting" {
            showPreview = True;
        }
    }, [ide.previewStatus, ide.projectType]);

    promptSentRef = useRef(False);
    useEffect(lambda -> None {
        if promptSentRef.current { return; }
        if not ide.projectId or not chat.historyLoaded { return; }
        params = Reflect.construct(URLSearchParams, [window.location.search]);
        prompt = params.get("prompt");
        if not prompt { return; }
        promptSentRef.current = True;
        activeSidebarView = "chat";
        window.history.replaceState({}, "", window.location.pathname);
        sendFn = chat.sendMessage;
        setTimeout(lambda { sendFn.call(None, prompt); }, 300);
    }, [ide.projectId, chat.historyLoaded]);

    useHotkeys([
        ["shift+?", lambda(e: Any) -> None { modals.openShortcuts(); }],
        ["mod+t", lambda(e: Any) -> None { symbolSearchOpen = True; }],
        ["mod+b", lambda(e: Any) -> None { sidebarCollapsed = not sidebarCollapsed; }],
        ["mod+shift+e", lambda(e: Any) -> None { handleViewChange("files"); }],
        ["mod+shift+f", lambda(e: Any) -> None { handleViewChange("search"); }],
        ["mod+shift+g", lambda(e: Any) -> None { handleViewChange("git"); }],
        ["mod+shift+d", lambda(e: Any) -> None { handleViewChange("run"); }],
        ["mod+shift+a", lambda(e: Any) -> None { handleViewChange("chat"); }],
        ["mod+shift+x", lambda(e: Any) -> None { handleViewChange("export"); }],
        ["mod+shift+r", lambda(e: Any) -> None {
            e.preventDefault();
            if ide.activeTab {
                activeSidebarView = "files";
                sidebarCollapsed = False;
                revealSignal = revealSignal + 1;
            }
        }]
    ]);

    def saveFileWithLsp() -> None {
        tab = ide.activeTab;
        ide.saveFile();
        if lsp.lspReady and tab {
            lsp.sendDidSave(tab);
        }
    }

    def navigateToSymbol(filePath: str, line: int, column: int) -> None {
        if activeSidebarView == "chat" {
            activeSidebarView = "files";
        }
        ide.openFile(filePath);
        setTimeout(lambda {
            if editor.editorRef.current {
                editor.editorRef.current.revealLineInCenter(line);
                editor.editorRef.current.setPosition({"lineNumber": line, "column": column});
                editor.editorRef.current.focus();
            }
        }, 200);
    }

    def togglePreview() -> None {
        showPreview = not showPreview;
    }

    def triggerNewFile() -> None {
        newFileTrigger = newFileTrigger + 1;
    }

    def handleViewChange(viewId: str) -> None {
        if viewId == activeSidebarView and not sidebarCollapsed {
            sidebarCollapsed = True;
        } else {
            activeSidebarView = viewId;
            sidebarCollapsed = False;
            if viewId == "export" { ide.refreshVersions(); }
        }
    }

    def switchToView(viewId: str) -> None {
        activeSidebarView = viewId;
        sidebarCollapsed = False;
    }

    def openShareModal() -> None {
        shareName = (ide.project.name if ide.project else "");
        shareDescription = "";
        shareTags = "";
        shareAgreed = False;
        shareError = "";
        shareModalOpen = True;
    }

    async def handleShare() -> None {
        if not shareName.trim() {
            shareError = "Name is required";
            return;
        }
        isSharing = True;
        shareError = "";
        exportResult = await ideExportVersionDownload(ide.projectId, "");
        if not exportResult or not exportResult.success {
            shareError = (exportResult.error if exportResult and exportResult.error else "Failed to export project");
            isSharing = False;
            return;
        }
        tags: list = [];
        if shareTags.trim() {
            rawTags = shareTags.split(",");
            for rawTag in rawTags {
                t = rawTag.trim();
                if t { tags.push(t); }
            }
        }
        result = await communitySubmit(shareName.trim(), shareDescription.trim(), tags, exportResult.content_base64 or "");
        if result and result.success {
            shareModalOpen = False;
            notify("Shared!", "Project shared to community", "green");
        } else {
            shareError = (result.error if result and result.error else "Failed to share project");
        }
        isSharing = False;
    }

    async def handleExportJacpack(versionId: str) -> None {
        result = await ideExportVersionDownload(ide.projectId, versionId);
        if result and result.success {
            fileName = result.file_name or ("export-" + (versionId[0:8] if versionId else String(Date.now())) + ".jacpack");
            contentBase64 = result.content_base64 or "";
            mimeType = result.mime_type or "application/octet-stream";
            if contentBase64 {
                _triggerDownload(fileName, contentBase64, mimeType);
                notify("Export ready", fileName, "info");
            }
        } else {
            err = result.error if result and result.error else "Export failed";
            notify("Export failed", err, "red");
        }
    }

    async def handleExportZip(versionId: str) -> None {
        result = await ideExportZipDownload(ide.projectId);
        if result and result.success {
            fileName = result.file_name or "project.zip";
            contentBase64 = result.content_base64 or "";
            mimeType = result.mime_type or "application/zip";
            if contentBase64 {
                _triggerDownload(fileName, contentBase64, mimeType);
                notify("Export ready", fileName, "info");
            }
        } else {
            err = result.error if result and result.error else "Export failed";
            notify("Export failed", err, "red");
        }
    }

    def handleEditorMount(editorInstance: Any, monacoInstance: Any) -> None {
        editor.handleEditorDidMount(editorInstance, monacoInstance);
        editorInstance.onDidChangeCursorPosition(lambda(e: Any) -> None {
            cursorLine = e.position.lineNumber;
            cursorColumn = e.position.column;
        });
    }

    def handleScreenshot() -> None {
        idePreviewScreenshot(ide.projectId).then(lambda(res: Any) {
            if res and res.success {
                notify("Screenshot captured", "Thumbnail saved", "green");
            }
        });
    }

    def handleRun() -> None {
        if ide.projectType == "script" {
            # On K8s the terminal execs into the sandbox pod, so we need
            # to ensure the pod is running first. startPreview is idempotent
            # and for script projects (no .cl.jac) it just starts the API
            # server which we can ignore. The terminal runs jac run separately.
            ide.startPreview();
            # Give the terminal a moment to connect, then send the command
            setTimeout(lambda {
                runInTerminal(ide.userId, ide.projectId, "jac run main.jac");
            }, 1000);
            notify("Script started", "Running in terminal", "green");
        } else {
            ide.startPreview();
        }
    }

    async def handleOpenDiff(filePath: str, mode: str) -> None {
        if not filePath or not mode { return; }
        diffPath = "diff://" + mode + "/" + filePath;
        for tab in ide.openTabs {
            if tab.path == diffPath {
                ide.setActiveTab(diffPath);
                return;
            }
        }
        originalContent = "";
        modifiedContent = "";
        origResult = None;
        modResult = None;
        if mode == "working" {
            origResult = await git.showFile("HEAD", filePath);
            if origResult and origResult.success { originalContent = origResult.content or ""; }
            modResult = await git.readWorkingFile(filePath);
            if modResult and modResult.success { modifiedContent = modResult.content or ""; }
        } elif mode == "staged" {
            origResult = await git.showFile("HEAD", filePath);
            if origResult and origResult.success { originalContent = origResult.content or ""; }
            modResult = await git.showFile(":", filePath);
            if modResult and modResult.success { modifiedContent = modResult.content or ""; }
        } elif mode == "last_commit" {
            origResult = await git.showFile("HEAD~1", filePath);
            if origResult and origResult.success { originalContent = origResult.content or ""; }
            modResult = await git.showFile("HEAD", filePath);
            if modResult and modResult.success { modifiedContent = modResult.content or ""; }
        }
        # Ensure LSP knows about the file for syntax features in diff view
        lsp.sendDidOpen(filePath, modifiedContent or originalContent);
        diffData = {
            "originalContent": originalContent,
            "modifiedContent": modifiedContent,
            "filePath": filePath,
            "mode": mode
        };
        ide.openDiffTab(diffPath, diffData);
    }

    async def handleChatOpenDiff(filePath: str, mode: str) -> None {
        if activeSidebarView == "chat" {
            activeSidebarView = "git";
        }
        await handleOpenDiff(filePath, mode);
    }

    hasProject = Boolean(ide.project);
    hasActiveTab = Boolean(ide.activeTab);

    gitChangedCount = 0;
    if git.status and git.status.files {
        gitChangedCount = git.status.files.length;
    }

    isScriptProject = ide.projectType == "script";
    isBackendProject = ide.projectType == "backend";

    # Compute API URL from apiPort (in dev mode, API runs on port+1)
    computedApiUrl = "";
    if ide.apiPort and ide.apiPort > 0 {
        computedApiUrl = "http://localhost:" + String(ide.apiPort);
    }

    isChatView = activeSidebarView == "chat" and not sidebarCollapsed;
    showEditor = not isChatView;
    showPreviewSecondary = showPreview and not isChatView and not isScriptProject;
    showPreviewMain = isChatView and not isScriptProject;

    if ide.isLoading and not ide.isSetup {
        return <div className="flex items-center justify-center h-screen bg-background">
            <div className="flex flex-col items-center gap-4">
                <Spinner className="size-6 text-primary" />
                <span className="text-sm text-muted-foreground">{"Setting up workspace..."}</span>
            </div>
        </div>;
    }

    return <div className="flex flex-col h-screen overflow-hidden bg-background text-foreground">

        <div className="flex flex-1 overflow-hidden">

            <ActivityBar
                activeView={activeSidebarView}
                onViewChange={handleViewChange}
                sidebarCollapsed={sidebarCollapsed}
                previewStatus={ide.previewStatus}
                gitChangedCount={gitChangedCount}
            />

            {not sidebarCollapsed and <ResizablePanelGroup direction="horizontal" className="" key={isChatView and "chat-layout" or "default-layout"}>

                <ResizablePanel
                    defaultSize={isChatView and "30%" or "18%"}
                    minSize={isChatView and "22%" or "15%"}
                    maxSize={isChatView and "45%" or "35%"}
                    className="flex flex-col bg-card overflow-hidden min-w-0"
                >
                    {activeSidebarView == "files" and <FileTree
                        files={ide.files}
                        onFileClick={ide.openFile}
                        onDeleteFile={modals.handleDeleteFile}
                        onRenameFile={ide.renameFile}
                        onCreateFile={ide.createFile}
                        onCreateDir={ide.createDir}
                        onCopyFile={ide.copyFile}
                        onDuplicateFile={ide.duplicateFile}
                        onRunFile={lambda(path: str) { terminalCollapsed = False; activeTerminalTab = "terminal"; runInTerminal(ide.userId, ide.projectId, "jac run " + path); }}
                        onCheckFile={lambda(path: str) { terminalCollapsed = False; activeTerminalTab = "terminal"; runInTerminal(ide.userId, ide.projectId, "jac check " + path); }}
                        onTestFile={lambda(path: str) { terminalCollapsed = False; activeTerminalTab = "terminal"; runInTerminal(ide.userId, ide.projectId, "jac test " + path + " -v"); }}
                        onFormatFile={lambda(path: str) { terminalCollapsed = False; activeTerminalTab = "terminal"; runInTerminal(ide.userId, ide.projectId, "jac format " + path); }}
                        onJsFile={lambda(path: str) { terminalCollapsed = False; activeTerminalTab = "terminal"; runInTerminal(ide.userId, ide.projectId, "jac js " + path); }}
                        activeTab={ide.activeTab}
                        newFileTrigger={newFileTrigger}
                        canEdit={hasProject}
                        onUploadFolder={folderUpload.uploadFromDataTransfer}
                        onTriggerFolderPicker={folderUpload.triggerFolderPicker}
                        isUploading={folderUpload.isUploading}
                        revealSignal={revealSignal}
                    /> or None}
                    {activeSidebarView == "search" and <SearchPanel
                        projectId={ide.projectId}
                        onNavigate={navigateToSymbol}
                    /> or None}
                    {activeSidebarView == "git" and hasProject and <GitPanel git={git} onOpenDiff={handleOpenDiff} /> or None}
                    {activeSidebarView == "run" and <RunPanel
                        previewStatus={ide.previewStatus}
                        onRun={handleRun}
                        onStop={ide.stopPreview}
                        hasProject={hasProject}
                        showPreview={showPreview}
                        onTogglePreview={togglePreview}
                        onOpenPreview={ide.openPreview}
                        deploymentStatus={ide.deploymentStatus}
                        deploymentUrl={ide.deploymentUrl}
                        onDeploy={ide.deployProject}
                        onDestroyDeploy={ide.destroyDeployment}
                        sandboxStatus={ide.sandboxStatus}
                        sandboxUrl={ide.sandboxUrl}
                        onSandboxDeploy={ide.sandboxDeploy}
                        onDestroySandbox={ide.destroySandbox}
                        onScreenshot={handleScreenshot}
                        projectType={ide.projectType}
                    /> or None}
                    {activeSidebarView == "chat" and <ChatPanel
                        chat={chat}
                        activeTab={ide.activeTab}
                        hasProject={hasProject}
                        onOpenDiff={handleChatOpenDiff}
                    /> or None}
                    {activeSidebarView == "export" and <ExportPanel
                        versions={ide.versions}
                        hasProject={hasProject}
                        onCaptureVersion={lambda -> Any {
                            return ide.captureVersion().then(lambda(_: Any) {
                                ide.refreshVersions();
                                notify("Checkpoint saved", "Version captured", "green");
                            });
                        }}
                        onExportJacpack={handleExportJacpack}
                        onExportZip={handleExportZip}
                        onRefresh={lambda { ide.refreshVersions(); }}
                    /> or None}
                    {activeSidebarView == "settings" and <SettingsPanel
                        settings={hasProject and settings or None}
                        showMinimap={editor.showMinimap}
                        onToggleMinimap={editor.toggleMinimap}
                        wordWrap={editor.wordWrap}
                        onToggleWordWrap={editor.toggleWordWrap}
                        theme={themeState.theme}
                        onThemeChange={themeState.setTheme}
                    /> or None}
                </ResizablePanel>

                <ResizableHandle className="w-1 bg-border hover:bg-primary/35 transition-colors" />

                <ResizablePanel defaultSize={isChatView and "70%" or "82%"} minSize={isChatView and "55%" or "65%"} className="flex flex-col overflow-hidden">
                    {showEditor and showPreviewSecondary and <ResizablePanelGroup direction="horizontal">
                        <ResizablePanel defaultSize={"55%"} minSize={"30%"} className="flex flex-col overflow-hidden bg-card">
                            <EditorTabs
                                tabs={ide.openTabs}
                                activeTab={ide.activeTab}
                                onTabClick={ide.setActiveTab}
                                onTabClose={ide.closeTab}
                                onSave={saveFileWithLsp}
                                isDirty={activeTabData and activeTabData.isDirty}
                                showMinimap={editor.showMinimap}
                                onToggleMinimap={editor.toggleMinimap}
                                wordWrap={editor.wordWrap}
                                onToggleWordWrap={editor.toggleWordWrap}
                            />

                            {ide.activeTab and not isDiffTab and <Breadcrumb className="h-[22px] pl-3 pr-3 bg-background border-b border-border flex-shrink-0 flex items-center">
                                <BreadcrumbList className="text-[11px] gap-1 flex-nowrap">
                                    {ide.activeTab.split("/").map(lambda(part: str, i: int, arr: Any) -> Any {
                                        isLast = i == arr.length - 1;
                                        if isLast {
                                            return <BreadcrumbItem key={String(i)}>
                                                <BreadcrumbPage className="text-[11px]">{part}</BreadcrumbPage>
                                            </BreadcrumbItem>;
                                        }
                                        return <BreadcrumbItem key={String(i)}>
                                            <span className="text-[11px] text-muted-foreground">{part}</span>
                                            <BreadcrumbSeparator>
                                                <span className="text-[11px] text-muted-foreground">{"/"}</span>
                                            </BreadcrumbSeparator>
                                        </BreadcrumbItem>;
                                    })}
                                </BreadcrumbList>
                            </Breadcrumb> or None}

                            {isDiffTab and <DiffHeaderBar diffData={activeTabData.diffData} /> or None}

                            <div className="flex-1 overflow-hidden">
                                {isDiffTab and <DiffEditor
                                    key={ide.activeTab}
                                    height="100%"
                                    width="100%"
                                    original={activeTabData.diffData.originalContent}
                                    modified={activeTabData.diffData.modifiedContent}
                                    keepCurrentOriginalModel={True}
                                    keepCurrentModifiedModel={True}
                                    language={editor.getLanguage()}
                                    theme={monacoThemeName}
                                    options={{
                                        "automaticLayout": True,
                                        "readOnly": True,
                                        "renderSideBySide": True,
                                        "fontSize": 13,
                                        "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                        "scrollBeyondLastLine": False,
                                        "minimap": {"enabled": False},
                                        "padding": {"top": 12}
                                    }}
                                /> or (isImageTab and <div className="flex items-center justify-center h-full bg-background">
                                    <img
                                        src={"data:" + activeTabData.mimeType + ";base64," + activeTabData.content}
                                        alt={ide.activeTab}
                                        className="max-w-full max-h-full object-contain"
                                    />
                                </div> or (ide.activeTab and <Editor
                                    height="100%"
                                    width="100%"
                                    path={("file://" + workspacePath + "/" + ide.activeTab) if workspacePath and ide.activeTab else ide.activeTab}
                                    language={editor.getLanguage()}
                                    value={editor.editorContent}
                                    onChange={editor.handleEditorChange}
                                    theme={monacoThemeName}
                                    onMount={handleEditorMount}
                                    options={{
                                        "automaticLayout": True,
                                        "minimap": {"enabled": editor.showMinimap},
                                        "fontSize": 13,
                                        "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                        "lineNumbers": "on",
                                        "scrollBeyondLastLine": False,
                                        "tabSize": 4,
                                        "insertSpaces": True,
                                        "wordWrap": ("on" if editor.wordWrap else "off"),
                                        "renderWhitespace": "selection",
                                        "bracketPairColorization": {"enabled": True},
                                        "padding": {"top": 12}
                                    }}
                                /> or <div className="flex items-center justify-center h-full bg-background">
                                    <div className="flex flex-col items-center gap-6">
                                        <div className="flex flex-col items-center gap-1">
                                            <span className="text-xl font-light text-muted-foreground">{"Jac Builder Studio"}</span>
                                            <span className="text-xs text-muted-foreground">{"Open a file to start editing"}</span>
                                        </div>
                                        <div className="flex flex-col gap-2 min-w-[220px]">
                                            <WelcomeHint keys={["Ctrl", "K"]} label="Open command palette" />
                                            <WelcomeHint keys={["Ctrl", "S"]} label="Save file" />
                                            <WelcomeHint keys={["Ctrl", "B"]} label="Toggle sidebar" />
                                            <WelcomeHint keys={["Shift", "?"]} label="Keyboard shortcuts" />
                                        </div>
                                    </div>
                                </div>))}
                            </div>

                            <TerminalArea
                                content={terminalContent}
                                isCollapsed={terminalCollapsed}
                                onToggle={lambda { terminalCollapsed = not terminalCollapsed; }}
                                onClear={lambda { terminalContent = ""; }}
                                userId={ide.userId}
                                projectId={ide.projectId}
                                activeTerminalTab={activeTerminalTab}
                                onTabChange={lambda(tab: str) { activeTerminalTab = tab; }}
                            />
                        </ResizablePanel>
                        <ResizableHandle className="w-1.5 bg-border hover:bg-primary/35 transition-colors" />
                        <ResizablePanel defaultSize={"45%"} minSize={"20%"}>
                            <IDEPreviewPanel
                                previewUrl={ide.previewUrl}
                                apiUrl={computedApiUrl}
                                previewStatus={ide.previewStatus}
                                refreshKey={ide.previewRefreshKey}
                                onOpenExternal={ide.openPreview}
                                onRun={handleRun}
                                onScreenshot={handleScreenshot}
                                projectType={ide.projectType}
                            />
                        </ResizablePanel>
                    </ResizablePanelGroup> or (showEditor and <div className="flex-1 flex flex-col overflow-hidden bg-card">
                        <EditorTabs
                            tabs={ide.openTabs}
                            activeTab={ide.activeTab}
                            onTabClick={ide.setActiveTab}
                            onTabClose={ide.closeTab}
                            onSave={saveFileWithLsp}
                            isDirty={activeTabData and activeTabData.isDirty}
                            showMinimap={editor.showMinimap}
                            onToggleMinimap={editor.toggleMinimap}
                            wordWrap={editor.wordWrap}
                            onToggleWordWrap={editor.toggleWordWrap}
                        />

                        {ide.activeTab and not isDiffTab and <div className="flex items-center h-[22px] pl-3 pr-3 bg-background border-b border-border flex-shrink-0 gap-0.5">
                            {ide.activeTab.split("/").map(lambda(part: str, i: int, arr: Any) -> Any {
                                isLast = i == arr.length - 1;
                                return <span key={String(i)} className="flex items-center gap-0.5">
                                    <span className={cn("text-[11px] leading-none", ("text-foreground" if isLast else "text-muted-foreground"))}>{part}</span>
                                    {not isLast and <span className="text-[11px] leading-none text-muted-foreground">{"/"}</span> or None}
                                </span>;
                            })}
                        </div> or None}

                        {isDiffTab and <DiffHeaderBar diffData={activeTabData.diffData} /> or None}

                        <div className="flex-1 overflow-hidden">
                            {isDiffTab and <DiffEditor
                                key={ide.activeTab}
                                height="100%"
                                width="100%"
                                original={activeTabData.diffData.originalContent}
                                modified={activeTabData.diffData.modifiedContent}
                                keepCurrentOriginalModel={True}
                                keepCurrentModifiedModel={True}
                                language={editor.getLanguage()}
                                theme={monacoThemeName}
                                options={{
                                    "automaticLayout": True,
                                    "readOnly": True,
                                    "renderSideBySide": True,
                                    "fontSize": 13,
                                    "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                    "scrollBeyondLastLine": False,
                                    "minimap": {"enabled": False},
                                    "padding": {"top": 12}
                                }}
                            /> or (isImageTab and <div className="flex items-center justify-center h-full bg-background">
                                <img
                                    src={"data:" + activeTabData.mimeType + ";base64," + activeTabData.content}
                                    alt={ide.activeTab}
                                    className="max-w-full max-h-full object-contain"
                                />
                            </div> or (ide.activeTab and <Editor
                                height="100%"
                                width="100%"
                                path={("file://" + workspacePath + "/" + ide.activeTab) if workspacePath and ide.activeTab else ide.activeTab}
                                language={editor.getLanguage()}
                                value={editor.editorContent}
                                onChange={editor.handleEditorChange}
                                theme={monacoThemeName}
                                onMount={handleEditorMount}
                                options={{
                                    "automaticLayout": True,
                                    "minimap": {"enabled": editor.showMinimap},
                                    "fontSize": 13,
                                    "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                    "lineNumbers": "on",
                                    "scrollBeyondLastLine": False,
                                    "tabSize": 4,
                                    "insertSpaces": True,
                                    "wordWrap": ("on" if editor.wordWrap else "off"),
                                    "renderWhitespace": "selection",
                                    "bracketPairColorization": {"enabled": True},
                                    "padding": {"top": 12}
                                }}
                            /> or <div className="flex items-center justify-center h-full bg-background">
                                <div className="flex flex-col items-center gap-6">
                                    <div className="flex flex-col items-center gap-1">
                                        <span className="text-xl font-light text-muted-foreground">{"Jac Builder Studio"}</span>
                                        <span className="text-xs text-muted-foreground">{"Open a file to start editing"}</span>
                                    </div>
                                    <div className="flex flex-col gap-2 min-w-[220px]">
                                        <WelcomeHint keys={["Ctrl", "K"]} label="Open command palette" />
                                        <WelcomeHint keys={["Ctrl", "S"]} label="Save file" />
                                        <WelcomeHint keys={["Ctrl", "B"]} label="Toggle sidebar" />
                                        <WelcomeHint keys={["Shift", "?"]} label="Keyboard shortcuts" />
                                    </div>
                                </div>
                            </div>))}
                        </div>

                        <TerminalArea
                            content={terminalContent}
                            isCollapsed={terminalCollapsed}
                            onToggle={lambda { terminalCollapsed = not terminalCollapsed; }}
                            onClear={lambda { terminalContent = ""; }}
                            userId={ide.userId}
                            projectId={ide.projectId}
                            activeTerminalTab={activeTerminalTab}
                            onTabChange={lambda(tab: str) { activeTerminalTab = tab; }}
                        />
                    </div> or (showPreviewMain and <div className="flex-1 flex flex-col overflow-hidden">
                        <IDEPreviewPanel
                            previewUrl={ide.previewUrl}
                            apiUrl={computedApiUrl}
                            previewStatus={ide.previewStatus}
                            refreshKey={ide.previewRefreshKey}
                            onOpenExternal={ide.openPreview}
                            onRun={handleRun}
                            onScreenshot={handleScreenshot}
                            projectType={ide.projectType}
                        />
                        <TerminalArea
                            content={terminalContent}
                            isCollapsed={terminalCollapsed}
                            onToggle={lambda { terminalCollapsed = not terminalCollapsed; }}
                            onClear={lambda { terminalContent = ""; }}
                            userId={ide.userId}
                            projectId={ide.projectId}
                            activeTerminalTab={activeTerminalTab}
                            onTabChange={lambda(tab: str) { activeTerminalTab = tab; }}
                        />
                    </div> or None))}
                </ResizablePanel>

            </ResizablePanelGroup> or <div className="flex-1 flex overflow-hidden">
                {showEditor and showPreviewSecondary and <ResizablePanelGroup direction="horizontal">
                    <ResizablePanel defaultSize={"55%"} minSize={"30%"} className="flex flex-col overflow-hidden bg-card">
                        <EditorTabs
                            tabs={ide.openTabs}
                            activeTab={ide.activeTab}
                            onTabClick={ide.setActiveTab}
                            onTabClose={ide.closeTab}
                            onSave={saveFileWithLsp}
                            isDirty={activeTabData and activeTabData.isDirty}
                            showMinimap={editor.showMinimap}
                            onToggleMinimap={editor.toggleMinimap}
                            wordWrap={editor.wordWrap}
                            onToggleWordWrap={editor.toggleWordWrap}
                        />
                        {isDiffTab and <DiffHeaderBar diffData={activeTabData.diffData} /> or None}
                        <div className="flex-1 overflow-hidden">
                            {isDiffTab and <DiffEditor
                                key={ide.activeTab}
                                height="100%"
                                width="100%"
                                original={activeTabData.diffData.originalContent}
                                modified={activeTabData.diffData.modifiedContent}
                                keepCurrentOriginalModel={True}
                                keepCurrentModifiedModel={True}
                                language={editor.getLanguage()}
                                theme={monacoThemeName}
                                options={{
                                    "automaticLayout": True,
                                    "readOnly": True,
                                    "renderSideBySide": True,
                                    "fontSize": 13,
                                    "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                    "scrollBeyondLastLine": False,
                                    "minimap": {"enabled": False},
                                    "padding": {"top": 12}
                                }}
                            /> or (ide.activeTab and not isDiffTab and <Editor
                                height="100%"
                                width="100%"
                                path={("file://" + workspacePath + "/" + ide.activeTab) if workspacePath and ide.activeTab else ide.activeTab}
                                language={editor.getLanguage()}
                                value={editor.editorContent}
                                onChange={editor.handleEditorChange}
                                theme={monacoThemeName}
                                onMount={handleEditorMount}
                                options={{
                                    "automaticLayout": True,
                                    "minimap": {"enabled": editor.showMinimap},
                                    "fontSize": 13,
                                    "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                    "lineNumbers": "on",
                                    "scrollBeyondLastLine": False,
                                    "tabSize": 4,
                                    "insertSpaces": True,
                                    "wordWrap": ("on" if editor.wordWrap else "off"),
                                    "renderWhitespace": "selection",
                                    "bracketPairColorization": {"enabled": True},
                                    "padding": {"top": 12}
                                }}
                            /> or None)}
                        </div>
                        <TerminalArea
                            content={terminalContent}
                            isCollapsed={terminalCollapsed}
                            onToggle={lambda { terminalCollapsed = not terminalCollapsed; }}
                            onClear={lambda { terminalContent = ""; }}
                            userId={ide.userId}
                            projectId={ide.projectId}
                            activeTerminalTab={activeTerminalTab}
                            onTabChange={lambda(tab: str) { activeTerminalTab = tab; }}
                        />
                    </ResizablePanel>
                    <ResizableHandle className="w-1.5 bg-border hover:bg-primary/35 transition-colors" />
                    <ResizablePanel defaultSize={"45%"} minSize={"20%"}>
                        <IDEPreviewPanel
                            previewUrl={ide.previewUrl}
                            apiUrl={computedApiUrl}
                            previewStatus={ide.previewStatus}
                            refreshKey={ide.previewRefreshKey}
                            onOpenExternal={ide.openPreview}
                            onRun={handleRun}
                            onScreenshot={handleScreenshot}
                            projectType={ide.projectType}
                        />
                    </ResizablePanel>
                </ResizablePanelGroup> or (showEditor and <div className="flex-1 flex flex-col overflow-hidden bg-card">
                    <EditorTabs
                        tabs={ide.openTabs}
                        activeTab={ide.activeTab}
                        onTabClick={ide.setActiveTab}
                        onTabClose={ide.closeTab}
                        onSave={saveFileWithLsp}
                        isDirty={activeTabData and activeTabData.isDirty}
                        showMinimap={editor.showMinimap}
                        onToggleMinimap={editor.toggleMinimap}
                        wordWrap={editor.wordWrap}
                        onToggleWordWrap={editor.toggleWordWrap}
                    />
                    {isDiffTab and <DiffHeaderBar diffData={activeTabData.diffData} /> or None}
                    <div className="flex-1 overflow-hidden">
                        {isDiffTab and <DiffEditor
                            key={ide.activeTab}
                            height="100%"
                            width="100%"
                            original={activeTabData.diffData.originalContent}
                            modified={activeTabData.diffData.modifiedContent}
                            keepCurrentOriginalModel={True}
                            keepCurrentModifiedModel={True}
                            language={editor.getLanguage()}
                            theme={monacoThemeName}
                            options={{
                                "automaticLayout": True,
                                "readOnly": True,
                                "renderSideBySide": True,
                                "fontSize": 13,
                                "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                "scrollBeyondLastLine": False,
                                "minimap": {"enabled": False},
                                "padding": {"top": 12}
                            }}
                        /> or (ide.activeTab and not isDiffTab and <Editor
                            height="100%"
                            width="100%"
                            path={("file://" + workspacePath + "/" + ide.activeTab) if workspacePath and ide.activeTab else ide.activeTab}
                            language={editor.getLanguage()}
                            value={editor.editorContent}
                            onChange={editor.handleEditorChange}
                            theme={monacoThemeName}
                            onMount={handleEditorMount}
                            options={{
                                "automaticLayout": True,
                                "minimap": {"enabled": editor.showMinimap},
                                "fontSize": 13,
                                "fontFamily": "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
                                "lineNumbers": "on",
                                "scrollBeyondLastLine": False,
                                "tabSize": 4,
                                "insertSpaces": True,
                                "wordWrap": ("on" if editor.wordWrap else "off"),
                                "renderWhitespace": "selection",
                                "bracketPairColorization": {"enabled": True},
                                "padding": {"top": 12}
                            }}
                        /> or None)}
                    </div>
                    <TerminalArea
                        content={terminalContent}
                        isCollapsed={terminalCollapsed}
                        onToggle={lambda { terminalCollapsed = not terminalCollapsed; }}
                        onClear={lambda { terminalContent = ""; }}
                        userId={ide.userId}
                        projectId={ide.projectId}
                        activeTerminalTab={activeTerminalTab}
                        onTabChange={lambda(tab: str) { activeTerminalTab = tab; }}
                    />
                </div> or None)}
            </div>}

        </div>

        <StatusBar
            projectName={ide.project.name if ide.project and ide.project.name else ""}
            gitBranch={git.currentBranch or ""}
            gitDirty={gitChangedCount}
            cursorLine={cursorLine}
            cursorColumn={cursorColumn}
            previewStatus={ide.previewStatus}
            showPreview={showPreview}
            deploymentStatus={ide.deploymentStatus}
            deploymentUrl={ide.deploymentUrl}
            hasProject={Boolean(ide.projectId)}
            onBackClick={lambda -> None { navigate("/dashboard"); }}
            onBranchClick={lambda -> None { switchToView("git"); }}
            onTogglePreview={togglePreview}
            onRun={lambda -> None { handleRun(); }}
            onStop={lambda -> None { ide.stopPreview(); }}
            projectType={ide.projectType}
        />

        <CommandPalette
            onRun={handleRun}
            onStop={ide.stopPreview}
            onNewFile={triggerNewFile}
            onSave={lambda { saveFileWithLsp(); }}
            onTogglePreview={togglePreview}
            onToggleMinimap={editor.toggleMinimap}
            onOpenPreview={ide.openPreview}
            onToggleTerminal={lambda { terminalCollapsed = not terminalCollapsed; }}
            onShowShortcuts={modals.openShortcuts}
            fileList={ide.files}
            onFileClick={ide.openFile}
            previewStatus={ide.previewStatus}
            showPreview={showPreview}
            hasProject={hasProject}
            hasActiveTab={hasActiveTab}
            onSwitchView={switchToView}
            onOpenSettings={lambda { switchToView("settings"); }}
            onShareProject={openShareModal}
            onDeploy={ide.deployProject}
            onDestroyDeploy={ide.destroyDeployment}
            isDeployed={(ide.deploymentStatus == "running")}
            onOpenSymbolSearch={lambda { symbolSearchOpen = True; }}
            onCaptureVersion={lambda {
                if hasProject {
                    ide.captureVersion().then(lambda(_: Any) {
                        ide.refreshVersions();
                        notify("Checkpoint saved", "Version captured", "green");
                    });
                }
            }}
            onSwitchToExport={lambda {
                if hasProject {
                    ide.refreshVersions();
                    activeSidebarView = "export";
                    sidebarCollapsed = False;
                }
            }}
            git={git}
            onToggleSidebar={lambda { sidebarCollapsed = not sidebarCollapsed; }}
            projectType={ide.projectType}
        />

        <IDEModals modals={modals} />

        <input
            type="file"
            ref={folderUpload.fileInputRef}
            onChange={folderUpload.handleFileInputChange}
            style={{"display": "none"}}
            webkitdirectory=""
            directory=""
            multiple={True}
        />

        <Dialog open={folderUpload.showConfirm} onOpenChange={lambda v: Any { if not v { folderUpload.cancelUpload(); } }}>
            <DialogContent className="sm:max-w-sm">
                <DialogHeader>
                    <DialogTitle>Upload Folder</DialogTitle>
                </DialogHeader>
                <div className="space-y-3 pt-2">
                    <div className="text-sm text-foreground">
                        {String(folderUpload.scannedCount) + " files ready to upload."}
                    </div>
                    {folderUpload.skippedCount > 0 and <div className="text-xs text-muted-foreground">
                        {String(folderUpload.skippedCount) + " files skipped (too large or ignored)"}
                    </div> or None}
                    <div className="text-xs text-warning">
                        {folderUpload.confirmWarning}
                    </div>
                    <div className="flex justify-end gap-2 pt-1">
                        <Button size="sm" variant="outline" onClick={folderUpload.cancelUpload}>Cancel</Button>
                        <Button size="sm" onClick={folderUpload.confirmUpload}>Upload</Button>
                    </div>
                </div>
            </DialogContent>
        </Dialog>

        <Dialog open={folderUpload.isUploading and not folderUpload.showConfirm} onOpenChange={lambda _v: Any {}}>
            <DialogContent className="sm:max-w-sm">
                <DialogHeader>
                    <DialogTitle>Uploading Folder</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 pt-2">
                    <Progress value={folderUpload.progressPct} className="h-2" />
                    <div className="text-sm text-muted-foreground">
                        {folderUpload.uploadPhase == "scanning" and "Scanning files..." or None}
                        {folderUpload.uploadPhase == "reading" and ("Reading " + String(folderUpload.scannedCount) + " files...") or None}
                        {folderUpload.uploadPhase == "uploading" and ("Uploading " + String(folderUpload.scannedCount) + " files...") or None}
                        {folderUpload.uploadPhase == "done" and (String(folderUpload.uploadedCount) + " files uploaded") or None}
                    </div>
                    {folderUpload.skippedCount > 0 and <div className="text-xs text-muted-foreground">
                        {String(folderUpload.skippedCount) + " files skipped (too large or ignored)"}
                    </div> or None}
                    {folderUpload.errorCount > 0 and <div className="text-xs text-destructive">
                        {String(folderUpload.errorCount) + " files failed"}
                    </div> or None}
                </div>
            </DialogContent>
        </Dialog>

        <Dialog open={shareModalOpen} onOpenChange={lambda v: Any { if not v { shareModalOpen = False; } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Share to Community"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    <div className="flex flex-col gap-2">
                        <Label>{"Name"}</Label>
                        <Input
                            placeholder="My Awesome App"
                            value={shareName}
                            onChange={lambda e: Any { shareName = e.target.value; }}
                            disabled={isSharing}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label>{"Description"}</Label>
                        <Textarea
                            placeholder="A short description of your project..."
                            value={shareDescription}
                            onChange={lambda e: Any { shareDescription = e.target.value; }}
                            disabled={isSharing}
                            rows={3}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label>{"Tags (comma-separated)"}</Label>
                        <Input
                            placeholder="web, demo, api"
                            value={shareTags}
                            onChange={lambda e: Any { shareTags = e.target.value; }}
                            disabled={isSharing}
                        />
                    </div>
                    <div className="flex items-center gap-2">
                        <Checkbox
                            id="share-agree-ide"
                            checked={shareAgreed}
                            onCheckedChange={lambda v: Any { shareAgreed = Boolean(v); }}
                            disabled={isSharing}
                        />
                        <label htmlFor="share-agree-ide" className="text-sm text-muted-foreground cursor-pointer">
                            {"I agree this project will be publicly visible to all users"}
                        </label>
                    </div>
                    {shareError and <Alert variant="destructive">{shareError}</Alert>}
                    <Button
                        className="w-full"
                        disabled={not shareName or not shareAgreed or isSharing}
                        onClick={lambda { handleShare(); }}
                    >
                        {isSharing and <Spinner className="size-4" /> or None}
                        {"Share with Community"}
                    </Button>
                </div>
            </DialogContent>
        </Dialog>

        <WorkspaceSymbolSearch
            opened={symbolSearchOpen}
            onClose={lambda { symbolSearchOpen = False; }}
            searchWorkspaceSymbols={lsp.searchWorkspaceSymbols}
            onNavigate={navigateToSymbol}
        />

    </div>;
}

def _triggerDownload(fileName: str, contentBase64: str, mimeType: str) -> None {
    raw = atob(contentBase64);
    arr = Reflect.construct(Uint8Array, [raw.length]);
    i = 0;
    for i in range(raw.length) {
        arr[i] = raw.charCodeAt(i);
    }
    blob = Reflect.construct(Blob, [[arr], {"type": mimeType}]);
    url = URL.createObjectURL(blob);
    link = document.createElement("a");
    link.href = url;
    link.download = fileName;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
}

def DiffHeaderBar(props: Any) -> Any {
    diffData = props.diffData;
    if not diffData { return None; }
    mode = diffData.mode or "";
    filePath = diffData.filePath or "";
    origLabel = "HEAD";
    modLabel = "Working Tree";
    if mode == "staged" {
        origLabel = "HEAD";
        modLabel = "Staged";
    } elif mode == "last_commit" {
        origLabel = "HEAD~1";
        modLabel = "HEAD";
    }
    return <div className="flex h-[22px] flex-shrink-0 border-b border-border bg-muted/30">
        <div className="flex-1 flex items-center px-3 border-r border-border">
            <span className="text-[10px] font-semibold uppercase tracking-wider text-destructive">{origLabel}</span>
            <span className="text-[10px] text-muted-foreground ml-2 truncate font-mono">{filePath}</span>
        </div>
        <div className="flex-1 flex items-center px-3">
            <span className="text-[10px] font-semibold uppercase tracking-wider text-success">{modLabel}</span>
            <span className="text-[10px] text-muted-foreground ml-2 truncate font-mono">{filePath}</span>
        </div>
    </div>;
}

def WelcomeHint(props: Any) -> Any {
    keys = props.keys or [];
    label = props.label or "";

    return <div className="flex items-center justify-between gap-8">
        <span className="text-xs text-muted-foreground">{label}</span>
        <div className="flex items-center gap-1">
            {keys.map(lambda (k: str, i: int) -> Any {
                return <div key={String(i)} className="flex items-center gap-0.5">
                    <Kbd className="text-[10px]">{k}</Kbd>
                    {i < keys.length - 1 and <span className="text-xs text-muted-foreground">{"+"}</span> or None}
                </div>;
            })}
        </div>
    </div>;
}
