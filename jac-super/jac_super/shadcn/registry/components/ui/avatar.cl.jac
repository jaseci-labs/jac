import from "radix-ui" { Avatar as AvatarPrimitive }
import from ...lib.utils { cn }

def:pub Avatar(props: any) -> JsxElement {
    size = props["size"] or "default";
    return
        <AvatarPrimitive.Root
            {**props}
            data-slot="avatar"
            data-size={size}
            className={cn(
                "cn-avatar after:border-border group/avatar relative flex shrink-0 select-none after:absolute after:inset-0 after:border after:mix-blend-darken dark:after:mix-blend-lighten",
                props["className"]
            )}
        />;
}

def:pub AvatarImage(props: any) -> JsxElement {
    return
        <AvatarPrimitive.Image
            {**props}
            data-slot="avatar-image"
            className={cn(
                "cn-avatar-image aspect-square size-full object-cover",
                props["className"]
            )}
        />;
}

def:pub AvatarFallback(props: any) -> JsxElement {
    return
        <AvatarPrimitive.Fallback
            {**props}
            data-slot="avatar-fallback"
            className={cn(
                "cn-avatar-fallback flex size-full items-center justify-center text-sm group-data-[size=sm]/avatar:text-xs",
                props["className"]
            )}
        />;
}

def:pub AvatarBadge(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <span
            {**attrs}
            data-slot="avatar-badge"
            className={cn(
                "cn-avatar-badge absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-blend-color ring-2 select-none",
                "group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden",
                "group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2",
                "group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2",
                props["className"]
            )}
        />;
}

def:pub AvatarGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="avatar-group"
            className={cn(
                "cn-avatar-group *:data-[slot=avatar]:ring-background group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2",
                props["className"]
            )}
        />;
}

def:pub AvatarGroupCount(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="avatar-group-count"
            className={cn(
                "cn-avatar-group-count ring-background relative flex shrink-0 items-center justify-center ring-2",
                props["className"]
            )}
        />;
}
