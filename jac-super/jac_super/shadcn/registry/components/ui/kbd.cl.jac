cl import from ...lib.utils { cn }

cl {
    def:pub Kbd(props: Any) -> JsxElement {
        return
            <kbd
                data-slot="kbd"
                className={cn(
                    "cn-kbd pointer-events-none inline-flex items-center justify-center select-none",
                    props.className
                )}
                {...props}
            >
                {props.children}
            </kbd>;
    }

    def:pub KbdGroup(props: Any) -> JsxElement {
        return
            <kbd
                data-slot="kbd-group"
                className={cn("cn-kbd-group inline-flex items-center", props.className)}
                {...props}
            >
                {props.children}
            </kbd>;
    }
}
