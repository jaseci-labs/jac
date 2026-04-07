cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Loading03Icon }

cl {
    def:pub Spinner(props: Any) -> JsxElement {
        return <HugeiconsIcon
            icon={Loading03Icon}
            strokeWidth={2}
            role="status"
            aria-label="Loading"
            {...props}
            className={cn("size-4 animate-spin", props.className)}
        />;
    }
}
