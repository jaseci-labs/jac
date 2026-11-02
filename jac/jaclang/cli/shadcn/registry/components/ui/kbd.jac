import from ...lib.utils { cn }

def:pub Kbd(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <kbd
        data-slot="kbd"
        {**attrs}
        className={cn(
            "cn-kbd pointer-events-none inline-flex items-center justify-center select-none",
            props["className"]
        )}
    >
        {props["children"]}
    </kbd>
}

def:pub KbdGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <kbd
        data-slot="kbd-group"
        {**attrs}
        className={cn("cn-kbd-group inline-flex items-center", props["className"])}
    >
        {props["children"]}
    </kbd>
}
