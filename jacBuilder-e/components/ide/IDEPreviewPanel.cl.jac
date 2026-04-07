import from react { useState, useRef, useEffect }
import from ..ui.button { Button }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ..ui.spinner { Spinner }
import from "..ui.toggle-group" { ToggleGroup, ToggleGroupItem }
import from "...lib.utils" { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Refresh01Icon, LinkSquare02Icon, ViewIcon, ViewOffSlashIcon,
    ComputerSettingsIcon, SmartPhone01Icon, TabletConnectedWifiIcon,
    PlayIcon, Camera01Icon, Tablet02Icon
}
def:pub IDEPreviewPanel(props: Any) -> Any {
    previewUrl = props.previewUrl or "";
    apiUrl = props.apiUrl or "";
    previewStatus = props.previewStatus or "stopped";
    onOpenExternal = props.onOpenExternal;
    onRun = props.onRun;
    onScreenshot = props.onScreenshot;
    externalRefreshKey = props.refreshKey or 0;
    projectType = props.projectType or "fullstack";

    has iframeKey: int = 0;
    has viewportMode: str = "desktop";
    has apiViewTab: str = ("swagger" if projectType == "backend" else "preview");

    iframeRef = useRef(None);

    isRunning = previewStatus == "running";
    isStarting = previewStatus == "starting";

    def handleRefresh() -> None {
        iframeKey = iframeKey + 1;
    }

    isBackend = projectType == "backend";

    iframeWidth = "100%";
    if not isBackend {
        if viewportMode == "tablet" {
            iframeWidth = "768px";
        } elif viewportMode == "mobile" {
            iframeWidth = "375px";
        }
    }

    # Compute iframe URL based on active tab
    # Vite proxies /docs, /graph, /admin, /redoc to the API server,
    # so use previewUrl as base for all tabs (works in both local and K8s).
    # Only fall back to apiUrl if previewUrl is unavailable.
    baseApiUrl = previewUrl or apiUrl;
    iframeSrc = previewUrl;
    if apiViewTab == "preview" {
        iframeSrc = previewUrl;
    } elif apiViewTab == "swagger" and baseApiUrl {
        iframeSrc = baseApiUrl + "/docs";
    } elif apiViewTab == "graph" and baseApiUrl {
        iframeSrc = baseApiUrl + "/graph";
    } elif apiViewTab == "admin" and baseApiUrl {
        iframeSrc = baseApiUrl + "/admin/";
    } elif apiViewTab == "redoc" and baseApiUrl {
        iframeSrc = baseApiUrl + "/redoc";
    }
    def switchTab(tab: str) -> None {
        apiViewTab = tab;
        iframeKey = iframeKey + 1;
    }

    tabCls = "px-2.5 py-1.5 text-[11px] font-medium border-b-2 transition-colors";
    activeCls = "border-primary text-foreground";
    inactiveCls = "border-transparent text-muted-foreground hover:text-foreground";

    # Tab bar: Preview (fullstack only) + Swagger / Graph / Admin / ReDoc
    apiTabBar = None;
    if isRunning {
        apiTabBar = <div className="flex items-center gap-0 px-1 border-b border-border bg-card flex-shrink-0">
            {not isBackend and <button
                className={cn(tabCls, (activeCls if apiViewTab == "preview" else inactiveCls))}
                onClick={lambda -> None { switchTab("preview"); }}
            >{"Preview"}</button> or None}
            <button
                className={cn(tabCls, (activeCls if apiViewTab == "swagger" else inactiveCls))}
                onClick={lambda -> None { switchTab("swagger"); }}
            >{"Swagger"}</button>
            <button
                className={cn(tabCls, (activeCls if apiViewTab == "graph" else inactiveCls))}
                onClick={lambda -> None { switchTab("graph"); }}
            >{"Graph"}</button>
            <button
                className={cn(tabCls, (activeCls if apiViewTab == "admin" else inactiveCls))}
                onClick={lambda -> None { switchTab("admin"); }}
            >{"Admin"}</button>
            <button
                className={cn(tabCls, (activeCls if apiViewTab == "redoc" else inactiveCls))}
                onClick={lambda -> None { switchTab("redoc"); }}
            >{"ReDoc"}</button>
        </div>;
    }

    header = <div className="flex items-center justify-between px-3 h-10 flex-shrink-0 border-b border-border bg-background">
        <div className="flex items-center gap-2">
            <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-3.5 text-muted-foreground" />
            <span className="text-[11px] font-semibold uppercase tracking-[0.06em] text-muted-foreground leading-none select-none">{("API Explorer" if isBackend else "Preview")}</span>
            {isRunning and <div className="flex items-center gap-1.5 ml-1">
                <span className="inline-block w-1.5 h-1.5 rounded-full bg-success animate-live-dot"></span>
                <span className="text-[11px] text-success font-semibold">Live</span>
            </div> or None}
        </div>

        <div className="flex items-center gap-1">
            {isRunning and apiViewTab == "preview" and <ToggleGroup
                type="single"
                value={viewportMode}
                onValueChange={lambda (val: str) { if val { viewportMode = val; } }}
                size="sm"
            >
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <ToggleGroupItem value="desktop" aria-label="Desktop view">
                            <HugeiconsIcon icon={ComputerSettingsIcon} strokeWidth={2} className="size-3" />
                        </ToggleGroupItem>
                    </TooltipTrigger>
                    <TooltipContent>{"Desktop view"}</TooltipContent>
                </Tooltip>
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <ToggleGroupItem value="tablet" aria-label="Tablet view">
                            <HugeiconsIcon icon={Tablet02Icon} strokeWidth={2} className="size-3" />
                        </ToggleGroupItem>
                    </TooltipTrigger>
                    <TooltipContent>{"Tablet view"}</TooltipContent>
                </Tooltip>
                <Tooltip>
                    <TooltipTrigger asChild={True}>
                        <ToggleGroupItem value="mobile" aria-label="Mobile view">
                            <HugeiconsIcon icon={SmartPhone01Icon} strokeWidth={2} className="size-3" />
                        </ToggleGroupItem>
                    </TooltipTrigger>
                    <TooltipContent>{"Mobile view"}</TooltipContent>
                </Tooltip>
            </ToggleGroup> or None}
            {isRunning and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost" onClick={handleRefresh}>
                        <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{"Refresh preview"}</TooltipContent>
            </Tooltip> or None}
            {isRunning and onScreenshot and apiViewTab == "preview" and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost" onClick={onScreenshot}>
                        <HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{"Capture screenshot"}</TooltipContent>
            </Tooltip> or None}
            {isRunning and <Tooltip>
                <TooltipTrigger asChild={True}>
                    <Button size="icon-xs" variant="ghost" onClick={onOpenExternal}>
                        <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-3" />
                    </Button>
                </TooltipTrigger>
                <TooltipContent>{"Open in new tab"}</TooltipContent>
            </Tooltip> or None}
        </div>
    </div>;
    urlBar = isRunning and <div className="flex items-center gap-2 px-3 py-1.5 border-b border-border bg-background">
        <div className="flex-1 rounded px-2.5 py-1 bg-background border border-border">
            <span className="text-[11px] text-muted-foreground font-mono truncate block">{previewUrl}</span>
        </div>
    </div> or None;
    content = None;
    if isRunning and previewUrl {
        content = <div className="flex-1 flex justify-center items-stretch bg-background overflow-hidden">
            <iframe
                ref={iframeRef}
                key={String(iframeKey) + "-" + String(externalRefreshKey) + "-" + apiViewTab}
                src={iframeSrc}
                style={{"width": iframeWidth, "maxWidth": "100%", "height": "100%", "border": "none", "backgroundColor": "#ffffff", "transition": "width 0.3s ease"}}
                title={("API Explorer" if isBackend else "Preview")}
                sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-modals"
            />
        </div>;
    } elif isStarting {
        content = <div className="flex-1 flex flex-col items-center justify-center bg-background gap-4">
            <Spinner className="size-5" />
            <div className="flex flex-col items-center gap-1">
                <span className="text-[13px] text-muted-foreground font-medium">{("Starting API server" if isBackend else "Starting preview server")}</span>
                <span className="text-[11px] text-muted-foreground">{("API server booting up..." if isBackend else "Vite + API server booting up...")}</span>
            </div>
        </div>;
    } else {
        stoppedTitle = ("No Server Running" if isBackend else "No Preview Running");
        stoppedDesc = ("Start your API server to explore endpoints" if isBackend else "Run your app to see it live here");
        runLabel = ("Start Server" if isBackend else "Run Preview");
        content = <div className="flex-1 flex flex-col items-center justify-center bg-gradient-to-b from-primary/[0.06] to-background gap-5">
            <div className="flex flex-col items-center gap-3">
                <div className="w-14 h-14 rounded-2xl bg-muted border border-border flex items-center justify-center">
                    <HugeiconsIcon icon={ViewOffSlashIcon} strokeWidth={2} className="size-6 text-muted-foreground" />
                </div>
                <div className="flex flex-col items-center gap-1">
                    <span className="text-[14px] font-semibold text-foreground">{stoppedTitle}</span>
                    <span className="text-[12px] text-muted-foreground text-center max-w-[200px] leading-relaxed">
                        {stoppedDesc}
                    </span>
                </div>
            </div>
            {onRun and <Button
                size="sm"
                variant="secondary"
                onClick={onRun}
            >
                <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-3.5" />
                {runLabel}
            </Button> or None}
        </div>;
    }

    return <div className="flex flex-col h-full bg-background border-l border-border overflow-hidden">
        {header}
        {apiTabBar}
        {urlBar}
        {content}
    </div>;
}
