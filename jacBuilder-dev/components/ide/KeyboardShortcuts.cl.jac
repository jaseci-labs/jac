import from "..ui.dialog" { Dialog, DialogContent, DialogHeader, DialogTitle }
import from "..ui.kbd" { Kbd }
import from "..ui.separator" { Separator }

def:pub KeyboardShortcuts(props: Any) -> Any {
    opened = props.opened or False;
    onClose = props.onClose;

    return <Dialog open={opened} onOpenChange={lambda(open: bool) { if not open { closeFn = onClose; closeFn.call(None); } }}>
        <DialogContent className="sm:max-w-md">
            <DialogHeader>
                <DialogTitle className="text-[14px]">Keyboard Shortcuts</DialogTitle>
            </DialogHeader>
            <div className="flex flex-col gap-3">
                <span className="text-[11px] font-semibold uppercase tracking-[0.06em] leading-none select-none text-primary">General</span>
                <ShortcutRow keys={["Ctrl", "K"]} description="Open command palette" />
                <ShortcutRow keys={["Ctrl", "S"]} description="Save current file" />
                <ShortcutRow keys={["Shift", "?"]} description="Show keyboard shortcuts" />

                <Separator className="my-1" />

                <span className="text-[11px] font-semibold uppercase tracking-[0.06em] leading-none select-none text-primary">Editor</span>
                <ShortcutRow keys={["Ctrl", "Z"]}       description="Undo" />
                <ShortcutRow keys={["Ctrl", "Shift", "Z"]} description="Redo" />
                <ShortcutRow keys={["Ctrl", "D"]}       description="Select next occurrence" />
                <ShortcutRow keys={["Ctrl", "F"]}       description="Find in file" />
                <ShortcutRow keys={["Ctrl", "H"]}       description="Find and replace" />
                <ShortcutRow keys={["Ctrl", "/"]}       description="Toggle comment" />
                <ShortcutRow keys={["Alt", "Up/Down"]}  description="Move line up/down" />
                <ShortcutRow keys={["Ctrl", "Shift", "K"]} description="Delete line" />
                <ShortcutRow keys={["Ctrl", "["]}       description="Outdent line" />
                <ShortcutRow keys={["Ctrl", "]"]}       description="Indent line" />

                <Separator className="my-1" />

                <span className="text-[11px] font-semibold uppercase tracking-[0.06em] leading-none select-none text-primary">Navigation</span>
                <ShortcutRow keys={["Ctrl", "G"]} description="Go to line" />
                <ShortcutRow keys={["Ctrl", "P"]} description="Quick open file" />
                <ShortcutRow keys={["Ctrl", "T"]} description="Go to symbol in workspace" />
            </div>
        </DialogContent>
    </Dialog>;
}

def ShortcutRow(props: Any) -> Any {
    keys = props.keys or [];
    description = props.description or "";

    return <div className="flex items-center justify-between py-1">
        <span className="text-[13px] text-muted-foreground">{description}</span>
        <div className="flex items-center gap-1">
            {keys.map(lambda (key: str, i: int) -> Any {
                return <span key={String(i)} className="flex items-center gap-1">
                    <Kbd className="bg-background text-foreground border-border text-[11px]">
                        {key}
                    </Kbd>
                    {<span className="text-[10px] text-muted-foreground">+</span> if i < keys.length - 1 else None}
                </span>;
            })}
        </div>
    </div>;
}
