cl import from "radix-ui" { Avatar as AvatarPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Avatar(props: Any) -> JsxElement {
        size = props.size or "default";
        return <AvatarPrimitive.Root
            {...props}
            data-slot="avatar"
            data-size={size}
            className={cn("size-8 rounded-full after:rounded-full data-[size=lg]:size-10 data-[size=sm]:size-6 after:border-border group/avatar relative flex shrink-0 select-none after:absolute after:inset-0 after:border after:mix-blend-darken dark:after:mix-blend-lighten", props.className)}
        />;
    }

    def:pub AvatarImage(props: Any) -> JsxElement {
        return <AvatarPrimitive.Image
            {...props}
            data-slot="avatar-image"
            className={cn("rounded-full aspect-square size-full object-cover", props.className)}
        />;
    }

    def:pub AvatarFallback(props: Any) -> JsxElement {
        return <AvatarPrimitive.Fallback
            {...props}
            data-slot="avatar-fallback"
            className={cn("bg-muted text-muted-foreground rounded-full flex size-full items-center justify-center text-sm group-data-[size=sm]/avatar:text-xs", props.className)}
        />;
    }

    def:pub AvatarBadge(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="avatar-badge"
            className={cn(
                "bg-primary text-primary-foreground ring-background absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-blend-color ring-2 select-none",
                "group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden",
                "group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2",
                "group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2",
                props.className
            )}
        />;
    }

    def:pub AvatarGroup(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="avatar-group"
            className={cn("size-8 rounded-full after:rounded-full data-[size=lg]:size-10 data-[size=sm]:size-6-group *:data-[slot=avatar]:ring-background group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2", props.className)}
        />;
    }

    def:pub AvatarGroupCount(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="avatar-group-count"
            className={cn("bg-muted text-muted-foreground size-8 rounded-full text-sm group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3 ring-background relative flex shrink-0 items-center justify-center ring-2", props.className)}
        />;
    }
}
