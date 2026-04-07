"""Git panel — accordion-based: branch, changes, sync, diff, history, remotes, checkpoints."""

import from react { useState, useRef, useEffect }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.input { Input }
import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.spinner { Spinner }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ..ui.accordion { Accordion, AccordionItem, AccordionTrigger, AccordionContent }
import from ..ui.table { Table, TableBody, TableRow, TableCell }
import from "..ui.alert-dialog" {
    AlertDialog, AlertDialogContent, AlertDialogHeader,
    AlertDialogTitle, AlertDialogDescription,
    AlertDialogFooter, AlertDialogCancel, AlertDialogAction
}
import from ..ui.dialog { Dialog, DialogContent, DialogHeader, DialogTitle }
import from ..ui.select { Select, SelectTrigger, SelectValue, SelectContent, SelectItem }
import from ..ui.switch { Switch }
import from ..ui.label { Label }
import from ..ui.textarea { Textarea }
import from ..ui.alert { Alert }
import from "...utils.toast" { notify }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GitBranchIcon, GitCommitIcon, GitMergeIcon,
    ArrowUp01Icon, ArrowDown01Icon, Refresh01Icon, PlusSignIcon, Tick02Icon,
    AlertCircleIcon, MinusSignIcon, Delete02Icon, Clock01Icon, ArrowTurnBackwardIcon,
    InternetIcon, Cancel01Icon, MoreHorizontalCircle01Icon, Copy01Icon,
    Link01Icon, GitPullRequestIcon
}
import from "...lib.utils" { cn }

def _notify(title: str, message: str, color: str) -> None {
    notify(title, message, color);
}

def _relativeTime(dateStr: str) -> str {
    if not dateStr { return ""; }
    try {
        now = Date.now();
        then = Reflect.construct(Date, [dateStr]).getTime();
        diffSec = Math.floor((now - then) / 1000);
        if diffSec < 60 { return String(diffSec) + "s ago"; }
        diffMin = Math.floor(diffSec / 60);
        if diffMin < 60 { return String(diffMin) + "m ago"; }
        diffHr = Math.floor(diffMin / 60);
        if diffHr < 24 { return String(diffHr) + "h ago"; }
        diffDay = Math.floor(diffHr / 24);
        if diffDay < 30 { return String(diffDay) + "d ago"; }
        diffMo = Math.floor(diffDay / 30);
        return String(diffMo) + "mo ago";
    } except Exception {
        return "";
    }
}

def StatusBadge(props: Any) -> Any {
    status = props.status;
    if not status { return None; }

    files = status.files or [];
    dirty = status.dirty or False;
    ahead = status.ahead or 0;
    behind = status.behind or 0;

    stagedCount = 0;
    unstagedCount = 0;
    for f in files {
        if f.staged { stagedCount = stagedCount + 1; }
        if f.unstaged { unstagedCount = unstagedCount + 1; }
    }

    return <div className="flex items-center gap-1.5 flex-wrap">
        {dirty and <Badge variant="secondary" className=" text-warning bg-warning/10 border-0">
            {String(files.length) + " changed"}
        </Badge> or <Badge variant="secondary" className="text-[10px]  px-1.5 text-success bg-success/10 border-0">{"Clean"}</Badge>}
        {stagedCount > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-success bg-success/10 border-0">
            {String(stagedCount) + " staged"}
        </Badge> or None}
        {ahead > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-info bg-info/10 border-0">
            {String.fromCharCode(8593) + String(ahead)}
        </Badge> or None}
        {behind > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-primary bg-primary/10 border-0">
            {String.fromCharCode(8595) + String(behind)}
        </Badge> or None}
    </div>;
}

def FileStatusList(props: Any) -> Any {
    files = props.files or [];
    onStage = props.onStage or None;
    onUnstage = props.onUnstage or None;
    onOpenDiff = props.onOpenDiff or None;
    diffMode = props.diffMode or "working";
    if files.length == 0 { return None; }

    return <div className="flex flex-col gap-0.5 mt-2">
        {files.map(lambda (f: Any, i: int) -> Any {
            statusCode = f.status or "";
            filePath = f.path or "";
            pathParts = filePath.split("/");
            fileName = pathParts[pathParts.length - 1];
            isStagedFile = f.staged or False;
            isUnstagedFile = f.unstaged or False;

            colorCls = "text-muted-foreground";
            if statusCode == "M" or statusCode == "MM" { colorCls = "text-warning"; }
            elif statusCode == "A" or statusCode == "??" { colorCls = "text-success"; }
            elif statusCode == "D" { colorCls = "text-destructive"; }
            elif statusCode == "R" { colorCls = "text-info"; }

            openDiffFn = onOpenDiff;

            return <div key={String(i)} className="flex items-center gap-1 py-0.5 px-1 group">
                <span className={cn("text-[10px] font-mono w-5 text-center flex-shrink-0", colorCls)}>
                    {statusCode}
                </span>
                {openDiffFn and <button
                    className="text-[11px] font-mono text-muted-foreground truncate flex-1 text-left hover:text-foreground hover:underline cursor-pointer bg-transparent border-0 p-0 pl-0.5"
                    title={filePath}
                    onClick={lambda -> None { openDiffFn.call(None, filePath, diffMode); }}>
                    {fileName}
                </button> or <span className="text-[11px] font-mono text-muted-foreground truncate flex-1 pl-0.5" title={filePath}>
                    {fileName}
                </span>}
                {isStagedFile and <Badge variant="secondary" className="text-[8px] h-3.5 px-1 text-success bg-success/10 border-0">{"S"}</Badge> or None}
                <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                    {isUnstagedFile and onStage and <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button variant="ghost" size="icon-xs"
                                className="size-4 text-success hover:bg-success/20"
                                onClick={lambda -> None {
                                    stageFn = onStage;
                                    stageFn.call(None, filePath);
                                }}>
                                <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-2.5" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent side="left">{"Stage file"}</TooltipContent>
                    </Tooltip> or None}
                    {isStagedFile and onUnstage and <Tooltip>
                        <TooltipTrigger asChild={True}>
                            <Button variant="ghost" size="icon-xs"
                                className="size-4 text-destructive hover:bg-destructive/20"
                                onClick={lambda -> None {
                                    unstageFn = onUnstage;
                                    unstageFn.call(None, filePath);
                                }}>
                                <HugeiconsIcon icon={MinusSignIcon} strokeWidth={2} className="size-2.5" />
                            </Button>
                        </TooltipTrigger>
                        <TooltipContent side="left">{"Unstage file"}</TooltipContent>
                    </Tooltip> or None}
                </div>
            </div>;
        })}
    </div>;
}

def:pub GitPanel(props: Any) -> Any {
    git = props.git;
    onOpenDiffProp = props.onOpenDiff or None;
    has commitMsg: str = "";
    has newBranchName: str = "";
    has showNewBranch: bool = False;
    has commitMode: str = "all";
    has checkpoints: list = [];

    has confirmOpen: bool = False;
    has confirmTitle: str = "";
    has confirmMessage: str = "";
    has confirmAction: str = "";
    has confirmTarget: str = "";
    has confirmColor: str = "red";

    has remoteUrl: str = "";
    has logLoaded: bool = False;
    has remotesLoaded: bool = False;
    has logLimit: int = 20;

    has pushDialogOpen: bool = False;
    has pushRepoName: str = "";
    has pushRepoPrivate: bool = True;
    has pushLoading: bool = False;
    has pushError: str = "";

    has repoNotFound: bool = False;

    has prDialogOpen: bool = False;
    has prTitle: str = "";
    has prBase: str = "main";
    has prBody: str = "";
    has prLoading: bool = False;
    has prError: str = "";
    has prResultUrl: str = "";

    has openSections: list = ["branch", "changes"];

    status = git.status;
    branches = git.branches or [];
    currentBranch = git.currentBranch or "";

    hasStagedFiles = False;
    if status and status.files {
        for f in (status.files or []) {
            if f.staged {
                hasStagedFiles = True;
                break;
            }
        }
    }

    fileCount = 0;
    if status and status.files {
        fileCount = (status.files or []).length;
    }

    def openConfirm(title: str, msg: str, action: str, target: str, color: str) -> None {
        confirmTitle = title;
        confirmMessage = msg;
        confirmAction = action;
        confirmTarget = target;
        confirmColor = color;
        confirmOpen = True;
    }

    def handleConfirmAction() -> None {
        action = confirmAction;
        target = confirmTarget;
        confirmOpen = False;

        if action == "delete_branch" {
            git.deleteBranch(target).then(lambda(r: Any) -> None {
                if r and r.success { _notify("Branch Deleted", "Deleted branch " + target, "green"); }
                else { _notify("Delete Failed", (r.error if r else "Unknown error"), "red"); }
            });
        } elif action == "restore_checkpoint" {
            git.restoreCheckpoint(target).then(lambda(r: Any) -> None {
                if r and r.success { _notify("Checkpoint Restored", "Restored to " + target.slice(0, 7), "green"); }
                else { _notify("Restore Failed", (r.error if r else "Unknown error"), "red"); }
            });
        } elif action == "remove_remote" {
            git.removeRemote(target).then(lambda(r: Any) -> None {
                if r and r.success { _notify("Remote Removed", "Removed remote " + target, "green"); }
                else { _notify("Remove Failed", (r.error if r else "Unknown error"), "red"); }
            });
        } elif action == "merge_branch" {
            git.mergeBranch(target).then(lambda(r: Any) -> None {
                if r and r.success { _notify("Merged", "Merged " + target + " into " + currentBranch, "green"); }
                elif r and r.conflicts { _notify("Merge Conflict", "Merge conflict with " + target + " — aborted", "red"); }
                else { _notify("Merge Failed", (r.error if r else "Unknown error"), "red"); }
            });
        }
    }

    def handleCommit() -> None {
        if not commitMsg.trim() { return; }
        msg = commitMsg;
        commitMsg = "";
        commitFn = None;
        if commitMode == "staged" and hasStagedFiles { commitFn = git.doCommitStaged; }
        else { commitFn = git.doCommit; }
        commitFn.call(None, msg).then(lambda(r: Any) -> None {
            if r and r.success {
                sha = r.sha or "";
                shortSha = sha.slice(0, 7) if sha else "";
                _notify("Committed", shortSha + " - " + msg, "green");
            } else { _notify("Commit Failed", (r.error if r else "Unknown error"), "red"); }
        });
    }

    def handleCreateBranch() -> None {
        if not newBranchName.trim() { return; }
        name = newBranchName;
        newBranchName = "";
        showNewBranch = False;
        git.createBranch(name).then(lambda(r: Any) -> None {
            if r and r.success { _notify("Branch Created", "Created and switched to " + name, "green"); }
            else { _notify("Branch Failed", (r.error if r else "Unknown error"), "red"); }
        });
    }

    def handlePush() -> None {
        git.doPush().then(lambda(r: Any) -> None {
            if r and r.success { _notify("Pushed", "Changes pushed to remote", "green"); }
            else { _notify("Push Failed", (r.error if r else "Unknown error"), "red"); }
        });
    }

    def handlePull() -> None {
        git.doPull().then(lambda(r: Any) -> None {
            if r and r.success { _notify("Pulled", "Latest changes pulled", "green"); }
            else { _notify("Pull Failed", (r.error if r else "Unknown error"), "red"); }
        });
    }

    def _handleGithubPush() -> None {
        git.githubPushProject().then(lambda(r: Any) -> None {
            if r and r.success {
                repoNotFound = False;
                _notify("Pushed to GitHub", "Changes pushed successfully", "green");
            } else {
                errMsg = (r.error if r else "Unknown error");
                if _isRepoNotFound(errMsg) {
                    repoNotFound = True;
                    _notify("Repository Not Found", "The remote repository may have been deleted on GitHub.", "red");
                } else {
                    _notify("Push Failed", errMsg, "red");
                }
            }
        });
    }

    def _handleGithubPull() -> None {
        git.githubPullProject().then(lambda(r: Any) -> None {
            if r and r.success {
                repoNotFound = False;
                _notify("Pulled from GitHub", "Changes pulled successfully", "green");
            } else {
                errMsg = (r.error if r else "Unknown error");
                if _isRepoNotFound(errMsg) {
                    repoNotFound = True;
                    _notify("Repository Not Found", "The remote repository may have been deleted on GitHub.", "red");
                } else {
                    _notify("Pull Failed", errMsg, "red");
                }
            }
        });
    }

    def _openPublishDialog() -> None {
        projectName = "";
        if props.ide and props.ide.project {
            projectName = props.ide.project.name or "";
        }
        pushRepoName = projectName;
        pushRepoPrivate = True;
        pushError = "";
        pushLoading = False;
        pushDialogOpen = True;
    }

    def _handlePublish() -> None {
        if not pushRepoName.trim() { pushError = "Repository name is required"; return; }
        pushLoading = True;
        pushError = "";
        git.githubPushNew(pushRepoName.trim(), pushRepoPrivate).then(lambda(r: Any) -> None {
            pushLoading = False;
            if r and r.success {
                pushDialogOpen = False;
                _notify("Published to GitHub", "Repository created and code pushed", "green");
            } else {
                pushError = (r.error if r else "Failed to publish");
            }
        });
    }

    def _openPRDialog() -> None {
        prTitle = "";
        prBase = "main";
        prBody = "";
        prError = "";
        prResultUrl = "";
        prLoading = False;
        prDialogOpen = True;
    }

    def _handleCreatePR() -> None {
        if not prTitle.trim() { prError = "PR title is required"; return; }
        prLoading = True;
        prError = "";
        prResultUrl = "";
        head = currentBranch or "main";
        git.githubCreatePR(prTitle.trim(), head, prBase or "main", prBody).then(lambda(r: Any) -> None {
            prLoading = False;
            if r and r.success and r.pr {
                prResultUrl = r.pr.html_url or "";
                _notify("PR Created", prTitle, "green");
            } else {
                prError = (r.error if r else "Failed to create PR");
            }
        });
    }

    def _getOriginUrl() -> str {
        if not git.remoteList or git.remoteList.length == 0 { return ""; }
        i = 0;
        while i < git.remoteList.length {
            r = git.remoteList[i];
            if r.name == "origin" { return r.url or ""; }
            i = i + 1;
        }
        return "";
    }

    def _copyToClipboard(text: str) -> None {
        navigator.clipboard.writeText(text);
        _notify("Copied", "URL copied to clipboard", "green");
    }

    def _isRepoNotFound(error: str) -> bool {
        if not error { return False; }
        lower = error.toLowerCase();
        if lower.indexOf("repository not found") >= 0 { return True; }
        if lower.indexOf("not found") >= 0 and lower.indexOf("remote") >= 0 { return True; }
        return False;
    }

    def _handleRemoveStaleRemote() -> None {
        git.removeRemote("origin").then(lambda(r: Any) -> None {
            if r and r.success {
                repoNotFound = False;
                git.refresh();
                _notify("Remote Removed", "Stale remote removed. You can now publish to a new repo.", "green");
            } else {
                _notify("Failed", (r.error if r else "Could not remove remote"), "red");
            }
        });
    }

    def handleCreateCheckpoint() -> None {
        git.createCheckpoint().then(lambda(result: Any) -> None {
            if result and result.success and result.checkpoint_ref {
                checkpoints = [{"ref": result.checkpoint_ref, "timestamp": Date.now()}].concat(checkpoints.slice(0, 9));
                _notify("Checkpoint Saved", "Checkpoint " + result.checkpoint_ref.slice(0, 7), "green");
            } else { _notify("Checkpoint Failed", (result.error if result else "Unknown error"), "red"); }
        });
    }

    def handleAddRemote() -> None {
        if not remoteUrl.trim() { return; }
        url = remoteUrl;
        remoteUrl = "";
        git.addRemote(url).then(lambda(r: Any) -> None {
            if r and r.success { _notify("Remote Added", "Added remote origin", "green"); }
            else { _notify("Add Remote Failed", (r.error if r else "Unknown error"), "red"); }
        });
    }

    def handleAccordionChange(val: Any) -> None {
        openSections = val or [];
        if val and val.includes and val.includes("remotes") and not remotesLoaded {
            remotesLoaded = True;
            git.fetchRemotes();
        }
    }

    def openDiffFile(filePath: str, mode: str) -> None {
        if onOpenDiffProp {
            diffFn = onOpenDiffProp;
            diffFn.call(None, filePath, mode);
        }
    }

    return <div className="flex flex-col h-full bg-card">
        <div className="flex items-center justify-between px-3 h-9 flex-shrink-0 border-b border-border">
            <div className="flex items-center gap-1.5">
                <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-3.5 text-primary" />
                <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{"Git"}</span>
            </div>
            <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button variant="ghost" size="icon-xs"
                        className="size-6 text-muted-foreground hover:bg-accent"
                        onClick={lambda -> None { git.refresh(); }}
                        disabled={git.isLoading}
                    >
                        {git.isLoading and <Spinner className="size-2.5" /> or <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />}
                    </Button>
                </TooltipTrigger>
                <TooltipContent side="bottom">{"Refresh"}</TooltipContent>
            </Tooltip>
        </div>

        <ScrollArea className="flex-1 min-h-0">
            <Accordion
                type="multiple"
                value={openSections}
                onValueChange={lambda(val: Any) -> None { handleAccordionChange(val); }}
                className="border-border"
            >

                <AccordionItem value="branch">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={GitBranchIcon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"Branch"}</span>
                            {currentBranch and <Badge variant="secondary" className="text-[10px]  px-1.5 bg-primary/10 text-primary border-0">{currentBranch}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        <div className="flex flex-col gap-2">
                            <Select value={currentBranch} onValueChange={lambda (val: str) -> None { if val { git.switchBranch(val); } }}>
                                <SelectTrigger className="h-7 text-xs w-full">
                                    <SelectValue placeholder="Select branch" />
                                </SelectTrigger>
                                <SelectContent>
                                    {branches.map(lambda b: Any -> Any {
                                        return <SelectItem key={b.name} value={b.name}>{b.name}</SelectItem>;
                                    })}
                                </SelectContent>
                            </Select>
                            <div className="flex items-center justify-end">
                                <Button variant="ghost" size="icon-xs"
                                    className="size-5 text-muted-foreground hover:bg-accent"
                                    onClick={lambda -> None { showNewBranch = not showNewBranch; }}
                                >
                                    <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-2.5" />
                                </Button>
                            </div>
                            {showNewBranch and <div className="flex items-center gap-1">
                                <Input className="flex-1 h-7 text-xs"
                                    value={newBranchName}
                                    onChange={lambda (e: Any) { newBranchName = e.currentTarget.value; }}
                                    placeholder="new-branch-name"
                                    onKeyDown={lambda (e: Any) -> None { if e.key == "Enter" { handleCreateBranch(); } }}
                                />
                                <Button variant="ghost" size="icon-xs"
                                    className="size-6 bg-success/20 text-success hover:bg-success/30"
                                    onClick={lambda -> None { handleCreateBranch(); }}
                                    disabled={not newBranchName.trim()}
                                >
                                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-2.5" />
                                </Button>
                            </div> or None}
                            {branches.length > 0 and <div className="flex flex-col gap-0.5 p-1.5 rounded bg-background border border-border">
                                {branches.map(lambda (b: Any, i: int) -> Any {
                                    isCurrent = b.name == currentBranch;
                                    return <div key={String(i)} className="flex items-center justify-between py-0.5 px-1 rounded hover:bg-muted">
                                        <span className={cn("text-[11px] truncate flex-1", ("text-primary font-medium" if isCurrent else "text-muted-foreground"))}>{b.name}</span>
                                        {not isCurrent and <div className="flex items-center gap-0.5">
                                            <Tooltip>
                                                <TooltipTrigger asChild={True}>
                                                    <Button variant="ghost" size="icon-xs"
                                                        className="size-4 text-info hover:bg-info/20"
                                                        onClick={lambda -> None {
                                                            openConfirm("Merge Branch", "Merge " + b.name + " into " + currentBranch + "?", "merge_branch", b.name, "blue");
                                                        }}
                                                    >
                                                        <HugeiconsIcon icon={GitMergeIcon} strokeWidth={2} className="size-2.5" />
                                                    </Button>
                                                </TooltipTrigger>
                                                <TooltipContent side="left">{"Merge " + b.name + " into " + currentBranch}</TooltipContent>
                                            </Tooltip>
                                            <Tooltip>
                                                <TooltipTrigger asChild={True}>
                                                    <Button variant="ghost" size="icon-xs"
                                                        className="size-4 text-destructive hover:bg-destructive/20"
                                                        onClick={lambda -> None {
                                                            openConfirm("Delete Branch", "Delete branch " + b.name + "? This cannot be undone.", "delete_branch", b.name, "red");
                                                        }}
                                                    >
                                                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-2.5" />
                                                    </Button>
                                                </TooltipTrigger>
                                                <TooltipContent side="left">{"Delete " + b.name}</TooltipContent>
                                            </Tooltip>
                                        </div> or None}
                                    </div>;
                                })}
                            </div> or None}
                        </div>
                    </AccordionContent>
                </AccordionItem>

                <AccordionItem value="changes">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={GitCommitIcon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"Changes"}</span>
                            {fileCount > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-warning bg-warning/10 border-0">{String(fileCount)}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        <div className="flex flex-col gap-2">
                            {status and <StatusBadge status={status} /> or None}
                            {status and status.dirty and <FileStatusList files={status.files or []} onStage={git.stageFile} onUnstage={git.unstageFile} onOpenDiff={openDiffFile} diffMode="working" /> or None}
                            {status and not status.dirty and status.last_commit_files and status.last_commit_files.length > 0 and <div className="flex flex-col gap-0.5">
                                <span className="text-[10px] text-muted-foreground italic">{"Last commit changes:"}</span>
                                <FileStatusList files={status.last_commit_files} onOpenDiff={openDiffFile} diffMode="last_commit" />
                            </div> or None}
                            {status and status.dirty and <div className="flex flex-col gap-1.5 mt-1">
                                <div className="flex items-center justify-between">
                                    <span className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">{"Commit"}</span>
                                    {hasStagedFiles and <div className="flex items-center gap-1">
                                        <Button variant="ghost" size="xs"
                                            className={cn("text-[9px] px-1.5 h-5", ("bg-primary text-primary-foreground hover:bg-primary" if commitMode == "staged" else "bg-background text-muted-foreground"))}
                                            onClick={lambda -> None { commitMode = "staged"; }}>
                                            {"Staged"}
                                        </Button>
                                        <Button variant="ghost" size="xs"
                                            className={cn("text-[9px] px-1.5 h-5", ("bg-primary text-primary-foreground hover:bg-primary" if commitMode == "all" else "bg-background text-muted-foreground"))}
                                            onClick={lambda -> None { commitMode = "all"; }}>
                                            {"All"}
                                        </Button>
                                    </div> or None}
                                </div>
                                <div className="flex items-center gap-1">
                                    <Input className="flex-1 h-7 text-xs"
                                        value={commitMsg}
                                        onChange={lambda (e: Any) { commitMsg = e.currentTarget.value; }}
                                        placeholder={("Commit staged files..." if commitMode == "staged" and hasStagedFiles else "Commit message...")}
                                        onKeyDown={lambda (e: Any) -> None {
                                            if e.key == "Enter" and not e.shiftKey { handleCommit(); }
                                        }}
                                    />
                                    <Button variant="ghost" size="icon-xs"
                                        className="size-6 bg-primary/20 text-primary hover:bg-primary/30"
                                        onClick={lambda -> None { handleCommit(); }}
                                        disabled={not commitMsg.trim() or git.isLoading}
                                    >
                                        <HugeiconsIcon icon={GitCommitIcon} strokeWidth={2} className="size-3" />
                                    </Button>
                                </div>
                            </div> or None}
                        </div>
                    </AccordionContent>
                </AccordionItem>

                {status and status.has_remote and <AccordionItem value="sync">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"Sync"}</span>
                            {(status.ahead or 0) > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-info bg-info/10 border-0">{String.fromCharCode(8593) + String(status.ahead)}</Badge> or None}
                            {(status.behind or 0) > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5 text-primary bg-primary/10 border-0">{String.fromCharCode(8595) + String(status.behind)}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        <div className="flex items-center gap-2">
                            <Button size="sm" variant="secondary" className="flex-1"
                                onClick={lambda -> None { handlePush(); }}
                                disabled={git.isLoading}>
                                <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3.5" />
                                {"Push" + (" (" + String(status.ahead) + ")" if (status.ahead or 0) > 0 else "")}
                            </Button>
                            <Button size="sm" variant="secondary" className="flex-1"
                                onClick={lambda -> None { handlePull(); }}
                                disabled={git.isLoading}>
                                <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-3.5" />
                                {"Pull" + (" (" + String(status.behind) + ")" if (status.behind or 0) > 0 else "")}
                            </Button>
                        </div>
                    </AccordionContent>
                </AccordionItem> or None}

                <AccordionItem value="github">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={InternetIcon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"GitHub"}</span>
                            {git.githubConnected and <Badge variant="outline" className="text-[10px] px-1.5 text-success border-success/30">{git.githubUsername}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        {not git.githubConnected and <div className="flex flex-col gap-2">
                            <p className="text-[10px] text-muted-foreground">{"Connect your GitHub account to push code and create pull requests."}</p>
                            <Button
                                variant="outline"
                                size="sm"
                                className="w-full text-xs"
                                onClick={lambda -> None { git.connectGithub(); }}
                                disabled={git.githubLoading}
                            >
                                {git.githubLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={InternetIcon} strokeWidth={2} className="size-3" />}
                                {"Connect GitHub"}
                            </Button>
                        </div> or None}
                        {git.githubConnected and <div className="flex flex-col gap-3">
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-1.5">
                                    <HugeiconsIcon icon={InternetIcon} strokeWidth={2} className="size-3 text-success" />
                                    <span className="text-[11px] text-success font-medium">{"@" + git.githubUsername}</span>
                                </div>
                                <button className="text-[9px] text-muted-foreground hover:text-destructive cursor-pointer bg-transparent border-0 p-0 underline"
                                    onClick={lambda -> None { git.disconnectGithub(); }}>
                                    {"Disconnect"}
                                </button>
                            </div>
                            {status and status.has_remote and <div className="flex flex-col gap-2">
                                {repoNotFound and <div className="flex flex-col gap-2 p-2 rounded bg-destructive/10 border border-destructive/20">
                                    <div className="flex items-center gap-1.5">
                                        <HugeiconsIcon icon={AlertCircleIcon} strokeWidth={2} className="size-3 text-destructive flex-shrink-0" />
                                        <span className="text-[10px] text-destructive font-medium">{"Remote repository not found"}</span>
                                    </div>
                                    <p className="text-[9px] text-destructive/70">{"The repository may have been deleted on GitHub. Remove the stale remote to publish to a new repo."}</p>
                                    <Button variant="destructive" size="sm" className="w-full text-xs"
                                        onClick={lambda -> None { _handleRemoveStaleRemote(); }}
                                        disabled={git.isLoading}>
                                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                                        {"Remove Stale Remote"}
                                    </Button>
                                </div> or None}
                                {not repoNotFound and <div className="flex items-center gap-1 p-1.5 rounded bg-background border border-border">
                                    <HugeiconsIcon icon={Link01Icon} strokeWidth={2} className="size-3 text-muted-foreground flex-shrink-0" />
                                    <span className="text-[9px] font-mono text-muted-foreground truncate flex-1" title={_getOriginUrl()}>
                                        {_getOriginUrl().replace("https://github.com/", "").replace(".git", "")}
                                    </span>
                                    <Tooltip>
                                        <TooltipTrigger asChild={True}>
                                            <Button variant="ghost" size="icon-xs" className="size-4 text-muted-foreground hover:bg-accent flex-shrink-0"
                                                onClick={lambda -> None { _copyToClipboard(_getOriginUrl()); }}>
                                                <HugeiconsIcon icon={Copy01Icon} strokeWidth={2} className="size-2.5" />
                                            </Button>
                                        </TooltipTrigger>
                                        <TooltipContent side="left">{"Copy URL"}</TooltipContent>
                                    </Tooltip>
                                </div> or None}
                                {not repoNotFound and <div className="flex items-center gap-2">
                                    <Button variant="outline" size="sm" className="flex-1 text-xs"
                                        onClick={lambda -> None { _handleGithubPush(); }}
                                        disabled={git.githubLoading or git.isLoading}>
                                        {git.githubLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3" />}
                                        {"Push" + (" (" + String(status.ahead) + ")" if (status.ahead or 0) > 0 else "")}
                                    </Button>
                                    <Button variant="outline" size="sm" className="flex-1 text-xs"
                                        onClick={lambda -> None { _handleGithubPull(); }}
                                        disabled={git.githubLoading or git.isLoading}>
                                        {git.githubLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={ArrowDown01Icon} strokeWidth={2} className="size-3" />}
                                        {"Pull" + (" (" + String(status.behind) + ")" if (status.behind or 0) > 0 else "")}
                                    </Button>
                                </div> or None}
                                {not repoNotFound and <Button variant="secondary" size="sm" className="w-full text-xs"
                                    onClick={lambda -> None { _openPRDialog(); }}
                                    disabled={git.githubLoading}>
                                    <HugeiconsIcon icon={GitPullRequestIcon} strokeWidth={2} className="size-3" />
                                    {"Create Pull Request"}
                                </Button> or None}
                            </div> or None}
                            {status and not status.has_remote and <div className="flex flex-col gap-2">
                                <p className="text-[10px] text-muted-foreground">{"Publish this project to GitHub to enable push, pull, and PRs."}</p>
                                <Button variant="default" size="sm" className="w-full text-xs"
                                    onClick={lambda -> None { _openPublishDialog(); }}
                                    disabled={git.githubLoading}>
                                    {git.githubLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3" />}
                                    {"Publish to GitHub"}
                                </Button>
                            </div> or None}
                        </div> or None}
                    </AccordionContent>
                </AccordionItem>

                <AccordionItem value="remotes">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={InternetIcon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"Remotes"}</span>
                            {remotesLoaded and git.remoteList.length > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5">{String(git.remoteList.length)}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        <div className="flex flex-col gap-2">
                            {not remotesLoaded and <div className="flex justify-center py-2"><Spinner className="size-4 text-primary" /></div> or None}
                            {remotesLoaded and git.remoteList.length == 0 and <span className="text-[10px] text-muted-foreground italic">{"No remotes configured"}</span> or None}
                            {remotesLoaded and git.remoteList.length > 0 and <Table className="text-[10px]">
                                <TableBody>
                                {git.remoteList.map(lambda (r: Any, i: int) -> Any {
                                    rName = r.name or "";
                                    rUrl = r.url or "";
                                    truncUrl = rUrl.slice(0, 30) + ("..." if rUrl.length > 30 else "");
                                    return <TableRow key={String(i)} className="border-0 hover:bg-muted group">
                                        <TableCell className="py-0.5 px-1 font-semibold text-foreground w-[60px]">{rName}</TableCell>
                                        <TableCell className="py-0.5 px-1 font-mono text-[9px] text-muted-foreground truncate max-w-[150px]" title={rUrl}>{truncUrl}</TableCell>
                                        <TableCell className="py-0.5 px-1 w-[24px]">
                                        <Button variant="ghost" size="icon-xs"
                                            className="size-4 text-destructive hover:bg-destructive/20 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
                                            onClick={lambda -> None {
                                                openConfirm("Remove Remote", "Remove remote " + rName + "?", "remove_remote", rName, "red");
                                            }}
                                        >
                                            <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-2.5" />
                                        </Button>
                                        </TableCell>
                                    </TableRow>;
                                })}
                                </TableBody>
                            </Table> or None}
                            <div className="flex items-center gap-1 mt-1">
                                <Input className="flex-1  text-xs"
                                    value={remoteUrl}
                                    onChange={lambda (e: Any) { remoteUrl = e.currentTarget.value; }}
                                    placeholder="https://github.com/..."
                                    onKeyDown={lambda (e: Any) -> None { if e.key == "Enter" { handleAddRemote(); } }}
                                />
                                <Button variant="ghost" size="icon-xs"
                                    className="size-6 bg-success/20 text-success hover:bg-success/30"
                                    onClick={lambda -> None { handleAddRemote(); }}
                                    disabled={not remoteUrl.trim()}
                                >
                                    <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-2.5" />
                                </Button>
                            </div>
                        </div>
                    </AccordionContent>
                </AccordionItem>

                <AccordionItem value="checkpoints">
                    <AccordionTrigger className=" text-[11px]">
                        <div className="flex items-center gap-2">
                            <HugeiconsIcon icon={ArrowTurnBackwardIcon} strokeWidth={2} className="size-3" />
                            <span className="text-[11px] font-semibold uppercase tracking-wider">{"Checkpoints"}</span>
                            {checkpoints.length > 0 and <Badge variant="secondary" className="text-[10px]  px-1.5">{String(checkpoints.length)}</Badge> or None}
                        </div>
                    </AccordionTrigger>
                    <AccordionContent className="px-3 pb-2">
                        <div className="flex flex-col gap-1.5">
                            <Button size="sm" variant="secondary" className="w-full"
                                onClick={lambda -> None { handleCreateCheckpoint(); }}
                                disabled={git.isLoading}>
                                <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-3.5" />
                                {"Save Checkpoint"}
                            </Button>
                            {checkpoints.length == 0 and <span className="text-[10px] text-muted-foreground italic">{"No checkpoints saved"}</span> or <div className="flex flex-col gap-0.5">
                                {checkpoints.map(lambda (cp: Any, i: int) -> Any {
                                    shortRef = cp.ref.slice(0, 7);
                                    timeStr = "";
                                    if cp.timestamp {
                                        d = Reflect.construct(Date, [cp.timestamp]);
                                        timeStr = d.toLocaleTimeString("en-US", {"hour": "2-digit", "minute": "2-digit"});
                                    }
                                    return <div key={String(i)} className="flex items-center justify-between py-0.5 px-1 rounded hover:bg-muted">
                                        <div className="flex items-center gap-1.5">
                                            <span className="text-[10px] font-mono text-primary">{shortRef}</span>
                                            {timeStr and <span className="text-[9px] text-muted-foreground">{timeStr}</span> or None}
                                        </div>
                                        <Tooltip>
                                            <TooltipTrigger asChild={True}>
                                                <Button variant="ghost" size="icon-xs"
                                                    className="size-4 text-warning hover:bg-warning/20"
                                                    onClick={lambda -> None {
                                                        openConfirm("Restore Checkpoint", "Restore to checkpoint " + shortRef + "? Current changes will be overwritten.", "restore_checkpoint", cp.ref, "yellow");
                                                    }}
                                                >
                                                    <HugeiconsIcon icon={ArrowTurnBackwardIcon} strokeWidth={2} className="size-2.5" />
                                                </Button>
                                            </TooltipTrigger>
                                            <TooltipContent side="left">{"Restore checkpoint"}</TooltipContent>
                                        </Tooltip>
                                    </div>;
                                })}
                            </div>}
                        </div>
                    </AccordionContent>
                </AccordionItem>
            </Accordion>

            {git.gitError and <div className="flex items-center gap-1.5 p-2 mx-3 my-2 rounded bg-destructive/10 border border-destructive/20">
                <HugeiconsIcon icon={AlertCircleIcon} strokeWidth={2} className="size-3 text-destructive" />
                <span className="text-[11px] text-destructive/70">{git.gitError}</span>
            </div> or None}
        </ScrollArea>

        <div className="flex flex-col flex-1 min-h-0 border-t border-border">
            <div className="flex items-center justify-between px-3 pt-2 pb-1 flex-shrink-0">
                <div className="flex items-center gap-2">
                    <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-3 text-muted-foreground" />
                    <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{"History"}</span>
                    {logLoaded and git.commits.length > 0 and <Badge variant="secondary" className="text-[10px] px-1.5">{String(git.commits.length)}</Badge> or None}
                </div>
                {not logLoaded and <Button
                    size="icon-xs"
                    variant="ghost"
                    className="size-5"
                    onClick={lambda { logLoaded = True; fetchFn = git.fetchLog; fetchFn.call(None, logLimit); }}
                >
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3 text-muted-foreground" />
                </Button> or None}
            </div>
            <div className="flex-1  overflow-y-auto px-3 pb-2">
                {not logLoaded and <button
                    className="w-full py-3 text-[10px] text-muted-foreground hover:text-foreground transition-colors cursor-pointer bg-transparent border-0"
                    onClick={lambda { logLoaded = True; fetchFn = git.fetchLog; fetchFn.call(None, logLimit); }}
                >
                    {"Click to load history"}
                </button> or None}
                {logLoaded and git.commits.length == 0 and <span className="text-[10px] text-muted-foreground italic">{"No commits"}</span> or None}
                {logLoaded and git.commits.length > 0 and <div className="flex flex-col gap-0.5">
                    {git.commits.map(lambda (c: Any, i: int) -> Any {
                        sha = c.sha or "";
                        shortSha = sha.slice(0, 7);
                        msg = c.message or "";
                        truncMsg = msg.slice(0, 40) + ("..." if msg.length > 40 else "");
                        relTime = _relativeTime(c.date or "");
                        return <div key={String(i)} className="flex flex-col gap-0.5 py-1.5 px-1.5 rounded-md hover:bg-accent/50 border-b border-border/50 last:border-0">
                            <div className="flex items-center justify-between">
                                <span className="text-[10px] font-mono text-primary font-medium">{shortSha}</span>
                                <span className="text-[9px] text-muted-foreground">{relTime}</span>
                            </div>
                            <span className="text-[11px] text-foreground leading-tight" title={msg}>{truncMsg}</span>
                        </div>;
                    })}
                    {git.commits.length >= logLimit and <Button
                        size="xs"
                        variant="ghost"
                        className="w-full mt-1 text-[10px] text-muted-foreground"
                        onClick={lambda {
                            newLimit = logLimit + 30;
                            logLimit = newLimit;
                            fetchFn = git.fetchLog;
                            fetchFn.call(None, newLimit);
                        }}
                    >
                        {"Load more..."}
                    </Button> or None}
                </div> or None}
            </div>
        </div>

        <AlertDialog open={confirmOpen} onOpenChange={lambda v: Any { if not v { confirmOpen = False; } }}>
            <AlertDialogContent>
                <AlertDialogHeader>
                    <AlertDialogTitle>{confirmTitle}</AlertDialogTitle>
                    <AlertDialogDescription>{confirmMessage}</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                    <AlertDialogCancel onClick={lambda -> None { confirmOpen = False; }}>{"Cancel"}</AlertDialogCancel>
                    <AlertDialogAction variant={confirmColor == "red" and "destructive" or "default"} onClick={lambda -> None { handleConfirmAction(); }}>{"Confirm"}</AlertDialogAction>
                </AlertDialogFooter>
            </AlertDialogContent>
        </AlertDialog>

        <Dialog open={pushDialogOpen} onOpenChange={lambda v: Any { if not v { pushDialogOpen = False; } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Publish to GitHub"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    <div className="flex flex-col gap-2">
                        <Label className="text-xs">{"Repository name"}</Label>
                        <Input className=" text-xs"
                            value={pushRepoName}
                            onChange={lambda (e: Any) { pushRepoName = e.currentTarget.value; }}
                            placeholder="my-project"
                            disabled={pushLoading}
                            onKeyDown={lambda (e: Any) -> None { if e.key == "Enter" { _handlePublish(); } }}
                        />
                    </div>
                    <div className="flex items-center justify-between">
                        <Label className="text-xs">{"Private repository"}</Label>
                        <Switch checked={pushRepoPrivate}
                            onCheckedChange={lambda (v: Any) { pushRepoPrivate = v; }}
                            disabled={pushLoading}
                        />
                    </div>
                    {pushError and <Alert variant="destructive" className="text-xs py-2">{pushError}</Alert> or None}
                    <div className="flex items-center gap-2 justify-end">
                        <Button variant="ghost" size="sm" className="text-xs"
                            onClick={lambda -> None { pushDialogOpen = False; }}
                            disabled={pushLoading}>
                            {"Cancel"}
                        </Button>
                        <Button size="sm" className="text-xs"
                            onClick={lambda -> None { _handlePublish(); }}
                            disabled={not pushRepoName.trim() or pushLoading}>
                            {pushLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={ArrowUp01Icon} strokeWidth={2} className="size-3" />}
                            {"Create & Push"}
                        </Button>
                    </div>
                </div>
            </DialogContent>
        </Dialog>

        <Dialog open={prDialogOpen} onOpenChange={lambda v: Any { if not v { prDialogOpen = False; } }}>
            <DialogContent className="sm:max-w-md">
                <DialogHeader>
                    <DialogTitle>{"Create Pull Request"}</DialogTitle>
                </DialogHeader>
                <div className="flex flex-col gap-4">
                    <div className="flex items-center gap-2">
                        <Badge variant="secondary" className="text-[10px] px-2">{currentBranch or "main"}</Badge>
                        <span className="text-xs text-muted-foreground">{String.fromCharCode(8594)}</span>
                        <Input className=" text-xs flex-1"
                            value={prBase}
                            onChange={lambda (e: Any) { prBase = e.currentTarget.value; }}
                            placeholder="main"
                            disabled={prLoading}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label className="text-xs">{"Title"}</Label>
                        <Input className="text-xs"
                            value={prTitle}
                            onChange={lambda (e: Any) { prTitle = e.currentTarget.value; }}
                            placeholder="What does this PR do?"
                            disabled={prLoading}
                            onKeyDown={lambda (e: Any) -> None { if e.key == "Enter" { _handleCreatePR(); } }}
                        />
                    </div>
                    <div className="flex flex-col gap-2">
                        <Label className="text-xs">{"Description"}</Label>
                        <Textarea className="text-xs resize-none"
                            value={prBody}
                            onChange={lambda (e: Any) { prBody = e.currentTarget.value; }}
                            placeholder="Optional description..."
                            disabled={prLoading}
                            rows={3}
                        />
                    </div>
                    {prError and <Alert variant="destructive" className="text-xs py-2">{prError}</Alert> or None}
                    {prResultUrl and <div className="flex items-center gap-1.5 p-2 rounded bg-success/10 border border-success/20">
                        <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="size-3 text-success flex-shrink-0" />
                        <a href={prResultUrl} target="_blank" rel="noopener noreferrer"
                            className="text-[11px] text-primary underline truncate">
                            {prResultUrl}
                        </a>
                    </div> or None}
                    <div className="flex items-center gap-2 justify-end">
                        <Button variant="ghost" size="sm" className="text-xs"
                            onClick={lambda -> None { prDialogOpen = False; }}
                            disabled={prLoading}>
                            {prResultUrl and "Close" or "Cancel"}
                        </Button>
                        {not prResultUrl and <Button size="sm" className="text-xs"
                            onClick={lambda -> None { _handleCreatePR(); }}
                            disabled={not prTitle.trim() or prLoading}>
                            {prLoading and <Spinner className="size-3" /> or <HugeiconsIcon icon={GitPullRequestIcon} strokeWidth={2} className="size-3" />}
                            {"Create PR"}
                        </Button> or None}
                    </div>
                </div>
            </DialogContent>
        </Dialog>

    </div>;
}
