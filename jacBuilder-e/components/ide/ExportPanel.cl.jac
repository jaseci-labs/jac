import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.separator { Separator }
import from ..ui.spinner { Spinner }
import from "..ui.scroll-area" { ScrollArea }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    FloppyDiskIcon, Download04Icon, FileZipIcon, Refresh01Icon
}

def:pub ExportPanel(props: Any) -> Any {
    versions = props.versions or [];
    onCaptureVersion = props.onCaptureVersion;
    onExportJacpack = props.onExportJacpack;
    onExportZip = props.onExportZip;
    onRefresh = props.onRefresh;
    hasProject = props.hasProject or False;

    has isCapturing: bool = False;
    has exportingJacpackId: str = "";
    has exportingZipId: str = "";

    async def handleCapture() -> None {
        if not onCaptureVersion { return; }
        isCapturing = True;
        capFn = onCaptureVersion;
        await capFn.call(None);
        isCapturing = False;
    }

    async def handleExportJacpack(versionId: str) -> None {
        if not onExportJacpack { return; }
        exportingJacpackId = versionId;
        fn = onExportJacpack;
        await fn.call(None, versionId);
        exportingJacpackId = "";
    }

    async def handleExportZip(versionId: str) -> None {
        if not onExportZip { return; }
        exportingZipId = versionId;
        fn = onExportZip;
        await fn.call(None, versionId);
        exportingZipId = "";
    }

    return <div className="flex flex-col h-full bg-card">
        <div className="p-3 text-[11px] font-semibold uppercase tracking-[0.05em] text-muted-foreground border-b border-border flex items-center justify-between">
            <span>{"Export"}</span>
            <div className="flex items-center gap-1">
                <Button
                    size="icon-xs"
                    variant="ghost"
                    onClick={lambda { if onRefresh { refreshFn = onRefresh; refreshFn.call(None); } }}
                    disabled={not hasProject}
                    title="Refresh"
                >
                    <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />
                </Button>
            </div>
        </div>

        <div className="p-3 flex flex-col gap-2">
            <Button
                size="sm"
                variant="secondary"
                className="w-full"
                onClick={lambda { captureFn = handleCapture; captureFn.call(None); }}
                disabled={not hasProject or isCapturing}
            >
                {isCapturing and <Spinner className="size-3" /> or <HugeiconsIcon icon={FloppyDiskIcon} strokeWidth={2} className="size-3.5" />}
                {"Save Checkpoint"}
            </Button>
        </div>

        <Separator className="bg-border" />

        <div className="p-3 pb-1">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{"Checkpoints"}</span>
        </div>

        <ScrollArea className="flex-1">
            <div className="flex flex-col gap-1 px-3 pb-3">
                {(not versions or versions.length == 0) and <span className="text-xs text-muted-foreground pt-1">{"No checkpoints yet."}</span> or None}
                {versions.map(lambda(v: Any) -> Any {
                    isJpLoading = exportingJacpackId == v.id;
                    isZpLoading = exportingZipId == v.id;
                    commitLabel = v.commit_sha.substring(0, 8) if v.commit_sha else "---";
                    triggerLabel = v.trigger or "autosave";
                    dateStr = _formatDate(v.created_at);

                    vid = v.id;
                    jpFn = handleExportJacpack;
                    zpFn = handleExportZip;
                    return <div key={v.id} className="flex flex-col gap-1.5 px-2.5 py-2 rounded-md bg-accent/30 hover:bg-accent/50 transition-colors">
                        <div className="flex items-center justify-between gap-2">
                            <div className="flex items-center gap-1.5 min-w-0">
                                <code className="text-[11px] text-foreground font-mono">{commitLabel}</code>
                                <Badge variant="outline" className={cn("text-[9px] px-1 py-0 h-4 font-normal", _triggerColor(triggerLabel))}>
                                    {triggerLabel}
                                </Badge>
                            </div>
                        </div>
                        <span className="text-[10px] text-muted-foreground">{dateStr}</span>
                        <div className="flex items-center gap-1">
                            <Button
                                size="xs"
                                variant="ghost"
                                className="flex-1 h-6 text-[10px]"
                                onClick={lambda { jpFn.call(None, vid); }}
                                disabled={isJpLoading or isZpLoading}
                            >
                                {isJpLoading and <Spinner className="size-2.5" /> or <HugeiconsIcon icon={Download04Icon} strokeWidth={2} className="size-3" />}
                                {".jacpack"}
                            </Button>
                            <Button
                                size="xs"
                                variant="ghost"
                                className="flex-1 h-6 text-[10px]"
                                onClick={lambda { zpFn.call(None, vid); }}
                                disabled={isJpLoading or isZpLoading}
                            >
                                {isZpLoading and <Spinner className="size-2.5" /> or <HugeiconsIcon icon={FileZipIcon} strokeWidth={2} className="size-3" />}
                                {".zip"}
                            </Button>
                        </div>
                    </div>;
                })}
            </div>
        </ScrollArea>
    </div>;
}

def _formatDate(isoStr: str) -> str {
    if not isoStr { return ""; }
    d = Reflect.construct(Date, [isoStr]);
    now = Reflect.construct(Date, []);
    diffMs = now.getTime() - d.getTime();
    mins = Math.floor(diffMs / 60000);
    if mins < 1 { return "just now"; }
    if mins < 60 { return String(mins) + "m ago"; }
    hrs = Math.floor(mins / 60);
    if hrs < 24 { return String(hrs) + "h ago"; }
    days = Math.floor(hrs / 24);
    if days < 30 { return String(days) + "d ago"; }
    return d.toLocaleDateString("en-US", {"month": "short", "day": "numeric"}) + " " + d.toLocaleTimeString("en-US", {"hour": "2-digit", "minute": "2-digit"});
}

def _triggerColor(trigger: str) -> str {
    if trigger == "ai_chat" or trigger == "claude_chat" { return "text-claude border-claude/30"; }
    if trigger == "init" or trigger == "import" or trigger == "clone" { return "text-info border-info/30"; }
    if trigger == "folder_upload" { return "text-warning border-warning/30"; }
    if trigger == "replace" { return "text-warning border-warning/30"; }
    return "text-muted-foreground border-border";
}
