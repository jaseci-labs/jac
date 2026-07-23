import from ...lib.utils { cn }

def:pub Kbd(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <kbd
            data-slot="kbd"
            className={cn(
                "cn-kbd pointer-events-none inline-flex items-center justify-center select-none",
                props["className"]
            )}
            {**attrs}
        >
            {props["children"]}
        </kbd>;
}

def:pub KbdGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <kbd
            data-slot="kbd-group"
            className={cn("cn-kbd-group inline-flex items-center", props["className"])}
            {**attrs}
        >
            {props["children"]}
        </kbd>;
}
