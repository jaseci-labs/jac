import from core.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Copy01Icon, CheckmarkCircle01Icon }

def:pub CopyCommandBlock(lines: list[str], className: str = "") -> JsxElement {
    has copied: bool = False;

    def handle_copy(_e: MouseEvent);

    return
        <button
            onClick={handle_copy}
            title="Copy all four commands"
            className={cn(
                "group flex min-w-0 max-w-full cursor-pointer items-start gap-3 rounded-lg border border-border bg-card/70 pl-4 pr-4 pt-3.5 pb-3.5 text-left font-mono text-sm shadow-sm backdrop-blur transition-colors hover:border-primary/50 hover:bg-card",
                className
            )}
        >
            <div className="flex min-w-0 flex-1 flex-col gap-1.5">
                {for (i, ln) in enumerate(lines) {
                    <span key={str(i)} className="flex min-w-0 gap-3">
                        <span className="sh-prompt select-none text-primary">$</span>
                        <span className="truncate text-foreground">{ln}</span>
                    </span>
                }}
            </div>
            {if copied {
                <HugeiconsIcon
                    icon={CheckmarkCircle01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-primary"
                />
            } else {
                <HugeiconsIcon
                    icon={Copy01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-foreground"
                />
            } }
        </button>;
}

def:pub CopyCommand(
    command: str, display: str = "", className: str = ""
) -> JsxElement {
    has copied: bool = False;

    def handle_copy(_e: MouseEvent);

    return
        <button
            onClick={handle_copy}
            title="Copy to clipboard"
            className={cn(
                "group flex min-w-0 max-w-full cursor-pointer items-center gap-3 rounded-lg border border-border bg-card/70 pl-4 pr-4 pt-3 pb-3 font-mono text-sm shadow-sm backdrop-blur transition-colors hover:border-primary/50 hover:bg-card",
                className
            )}
        >
            <span className="sh-prompt select-none text-primary">$</span>
            <span className="min-w-0 flex-1 truncate text-left text-foreground">
                {display if display != "" else command}
            </span>
            {if copied {
                <HugeiconsIcon
                    icon={CheckmarkCircle01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-primary"
                />
            } else {
                <HugeiconsIcon
                    icon={Copy01Icon}
                    strokeWidth={2}
                    className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-foreground"
                />
            } }
        </button>;
}
