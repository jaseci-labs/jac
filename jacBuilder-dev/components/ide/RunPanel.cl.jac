import from ..ui.button { Button }
import from ..ui.badge { Badge }
import from ..ui.tooltip { Tooltip, TooltipTrigger, TooltipContent }
import from ..ui.separator { Separator }
import from ..ui.spinner { Spinner }
import from "..ui.scroll-area" { ScrollArea }
import from ..ui.progress { Progress }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    PlayIcon, StopIcon, ViewIcon, ViewOffSlashIcon,
    LinkSquare02Icon, Rocket01Icon, Delete02Icon, Camera01Icon,
    Clock01Icon, Refresh01Icon, Alert02Icon
}

def:pub RunPanel(props: Any) -> Any {
    previewStatus = props.previewStatus or "stopped";
    onRun = props.onRun;
    onStop = props.onStop;
    hasProject = props.hasProject or False;
    showPreview = props.showPreview or False;
    onTogglePreview = props.onTogglePreview;
    onOpenPreview = props.onOpenPreview;
    deploymentStatus = props.deploymentStatus or "";
    deploymentUrl = props.deploymentUrl or "";
    onDeploy = props.onDeploy;
    onDestroyDeploy = props.onDestroyDeploy;
    sandboxStatus = props.sandboxStatus or "";
    sandboxUrl = props.sandboxUrl or "";
    onSandboxDeploy = props.onSandboxDeploy;
    onDestroySandbox = props.onDestroySandbox;
    onScreenshot = props.onScreenshot;
    projectType = props.projectType or "fullstack";

    isScript = projectType == "script";
    isBackend = projectType == "backend";
    isRunning = previewStatus == "running" or previewStatus == "starting";
    isDeploying = deploymentStatus == "deploying";
    isDeployed = deploymentStatus == "running";
    isDestroyingDeploy = deploymentStatus == "destroying";
    isDeployFailed = deploymentStatus == "failed";
    isSandboxDeploying = sandboxStatus == "deploying";
    isSandboxRunning = sandboxStatus == "running";
    isSandboxDestroying = sandboxStatus == "destroying";
    isSandboxFailed = sandboxStatus == "failed";

    dotCls = "bg-muted-foreground";
    if previewStatus == "running" { dotCls = "bg-success"; }
    elif previewStatus == "starting" { dotCls = "bg-warning"; }
    elif previewStatus == "error" { dotCls = "bg-destructive"; }

    sectionTitle = "Run & Preview";
    runLabel = "Run";
    if isScript { sectionTitle = "Run Script"; runLabel = "Run Script"; }
    elif isBackend { sectionTitle = "Run Server"; runLabel = "Start Server"; }

    return <ScrollArea className="flex flex-col h-full bg-card">
        <div className="p-3 text-[11px] font-semibold uppercase tracking-[0.05em] text-muted-foreground border-b border-border">
            {sectionTitle}
        </div>

        <div className="p-3 flex flex-col gap-2">
            {not isRunning and <Button
                size="sm"
                variant="default"
                className="w-full bg-success hover:bg-success/80 text-success-foreground"
                onClick={onRun}
                disabled={not hasProject}
            >
                <HugeiconsIcon icon={PlayIcon} strokeWidth={2} className="size-3.5" />
                {runLabel}
            </Button> or <Button
                size="sm"
                variant="destructive"
                className="w-full"
                onClick={onStop}
            >
                <HugeiconsIcon icon={StopIcon} strokeWidth={2} className="size-3.5" />
                {"Stop"}
            </Button>}

            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                <div className={cn("w-[7px] h-[7px] rounded-full flex-shrink-0", dotCls)} />
                <span>{previewStatus}</span>
                {isRunning and <Button size="icon-xs" variant="ghost" onClick={onOpenPreview}>
                    <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-3" />
                </Button> or None}
            </div>
            {previewStatus == "starting" and <Progress value={100} className="h-0.5 [&>[data-slot=progress-indicator]]:animate-pulse [&>[data-slot=progress-indicator]]:bg-warning" /> or None}
        </div>

        {not isScript and <Separator className="bg-border" /> or None}

        {not isScript and <div className="p-3 flex flex-col gap-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{("API Explorer" if isBackend else "Preview Panel")}</span>
            <Button
                size="sm"
                variant={("secondary" if showPreview else "ghost")}
                className="w-full justify-start"
                onClick={onTogglePreview}
            >
                {showPreview and <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-3.5" /> or <HugeiconsIcon icon={ViewOffSlashIcon} strokeWidth={2} className="size-3.5" />}
                {("Hide Preview" if showPreview else "Show Preview")}
            </Button>
            {isRunning and not isBackend and <Button
                size="sm"
                variant="ghost"
                className="w-full justify-start"
                onClick={onScreenshot}
            >
                <HugeiconsIcon icon={Camera01Icon} strokeWidth={2} className="size-3" />
                {"Take Screenshot"}
            </Button> or None}
        </div> or None}

        {not isScript and <Separator className="bg-border" /> or None}

        {not isScript and <div className="p-3 flex flex-col gap-3">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">{"Deployment"}</span>

            <div className="flex flex-col gap-1.5">
                <span className="text-[10px] font-medium text-muted-foreground flex items-center gap-1">
                    <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-2.5" />
                    {"Sandbox (1 week TTL)"}
                </span>
                {isSandboxDeploying and <div className="flex flex-col gap-1.5">
                    <Button size="sm" variant="secondary" disabled={True} className="w-full">
                        <Spinner className="size-3" />
                        {"Deploying Sandbox..."}
                    </Button>
                    <Progress value={100} className="h-0.5 [&>[data-slot=progress-indicator]]:animate-pulse [&>[data-slot=progress-indicator]]:bg-warning" />
                </div> or (isSandboxRunning and <div className="flex flex-col gap-1.5">
                    <div className="flex items-center gap-1.5">
                        <Badge className="flex-1 bg-warning/10 text-warning border-warning/30 justify-center">
                            <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-2.5 mr-1" />
                            {"SANDBOX"}
                        </Badge>
                        {sandboxUrl and <Button size="icon-xs" variant="ghost" onClick={lambda -> None { window.open(sandboxUrl, "_blank"); }}>
                            <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-3" />
                        </Button> or None}
                    </div>
                    <Button size="sm" variant="ghost" className="w-full text-destructive hover:text-destructive" onClick={onDestroySandbox} disabled={isSandboxDestroying}>
                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                        {"Destroy Sandbox"}
                    </Button>
                </div> or (isSandboxFailed and <div className="flex flex-col gap-1.5">
                    <Badge className="bg-destructive/10 text-destructive border-destructive/20">{"Sandbox Failed"}</Badge>
                    <Button size="sm" variant="secondary" className="w-full" onClick={onSandboxDeploy}>
                        <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />
                        {"Retry"}
                    </Button>
                </div> or (isSandboxDestroying and <div className="flex flex-col gap-1.5">
                    <Button size="sm" variant="secondary" disabled={True} className="w-full">
                        <Spinner className="size-3" />
                        {"Destroying..."}
                    </Button>
                    <Progress value={100} className="h-0.5 [&>[data-slot=progress-indicator]]:animate-pulse [&>[data-slot=progress-indicator]]:bg-destructive" />
                </div> or <Button
                    size="sm"
                    variant="default"
                    className="w-full bg-warning hover:bg-warning/80 text-warning-foreground"
                    onClick={onSandboxDeploy}
                    disabled={not hasProject}
                >
                    <HugeiconsIcon icon={Clock01Icon} strokeWidth={2} className="size-3.5" />
                    {"Sandbox Deploy"}
                </Button>)))}
            </div>

            <div className="flex flex-col gap-1.5">
                <span className="text-[10px] font-medium text-muted-foreground flex items-center gap-1">
                    <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-2.5" />
                    {"Permanent"}
                </span>
                {isDeploying and <div className="flex flex-col gap-1.5">
                    <Button size="sm" variant="secondary" disabled={True} className="w-full">
                        <Spinner className="size-3" />
                        {"Deploying..."}
                    </Button>
                    <Progress value={100} className="h-0.5 [&>[data-slot=progress-indicator]]:animate-pulse [&>[data-slot=progress-indicator]]:bg-primary" />
                </div> or (isDeployed and <div className="flex flex-col gap-1.5">
                    <div className="flex items-center gap-1.5">
                        <Badge className="flex-1 bg-success/10 text-success border-success/30 justify-center">
                            <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-2.5 mr-1" />
                            {"DEPLOYED"}
                        </Badge>
                        {deploymentUrl and <Button size="icon-xs" variant="ghost" onClick={lambda -> None { window.open(deploymentUrl, "_blank"); }}>
                            <HugeiconsIcon icon={LinkSquare02Icon} strokeWidth={2} className="size-3" />
                        </Button> or None}
                    </div>
                    <Button size="sm" variant="ghost" className="w-full text-destructive hover:text-destructive" onClick={onDestroyDeploy} disabled={isDestroyingDeploy}>
                        <HugeiconsIcon icon={Delete02Icon} strokeWidth={2} className="size-3" />
                        {"Destroy"}
                    </Button>
                </div> or (isDeployFailed and <div className="flex flex-col gap-1.5">
                    <Badge className="bg-destructive/10 text-destructive border-destructive/20">{"Deploy Failed"}</Badge>
                    <Button size="sm" variant="secondary" className="w-full" onClick={onDeploy}>
                        <HugeiconsIcon icon={Refresh01Icon} strokeWidth={2} className="size-3" />
                        {"Retry"}
                    </Button>
                </div> or (isDestroyingDeploy and <div className="flex flex-col gap-1.5">
                    <Button size="sm" variant="secondary" disabled={True} className="w-full">
                        <Spinner className="size-3" />
                        {"Destroying..."}
                    </Button>
                    <Progress value={100} className="h-0.5 [&>[data-slot=progress-indicator]]:animate-pulse [&>[data-slot=progress-indicator]]:bg-destructive" />
                </div> or <Button
                    size="sm"
                    variant="default"
                    className="w-full"
                    onClick={onDeploy}
                    disabled={not hasProject}
                >
                    <HugeiconsIcon icon={Rocket01Icon} strokeWidth={2} className="size-3.5" />
                    {"Permanent Deploy"}
                </Button>)))}
            </div>
        </div> or None}

    </ScrollArea>;
}
