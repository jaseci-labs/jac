import from "radix-ui" { ContextMenu as ContextMenuPrimitive }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Tick02Icon, ArrowRight01Icon }

def:pub ContextMenu(props: any) -> JsxElement {
    return <ContextMenuPrimitive.Root data-slot="context-menu" {**props}/>;
}

def:pub ContextMenuTrigger(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.Trigger
            {**props}
            data-slot="context-menu-trigger"
            className={cn("cn-context-menu-trigger select-none", props["className"])}
        />;
}

def:pub ContextMenuGroup(props: any) -> JsxElement {
    return <ContextMenuPrimitive.Group data-slot="context-menu-group" {**props}/>;
}

def:pub ContextMenuPortal(props: any) -> JsxElement {
    return <ContextMenuPrimitive.Portal data-slot="context-menu-portal" {**props}/>;
}

def:pub ContextMenuSub(props: any) -> JsxElement {
    return <ContextMenuPrimitive.Sub data-slot="context-menu-sub" {**props}/>;
}

def:pub ContextMenuRadioGroup(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.RadioGroup
            data-slot="context-menu-radio-group"
            {**props}
        />;
}

def:pub ContextMenuContent(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.Portal>
            <ContextMenuPrimitive.Content
                {**props}
                data-slot="context-menu-content"
                className={cn(
                    "cn-context-menu-content cn-menu-target z-50 max-h-(--radix-context-menu-content-available-height) origin-(--radix-context-menu-content-transform-origin) overflow-x-hidden overflow-y-auto",
                    props["className"]
                )}
            />
        </ContextMenuPrimitive.Portal>;
}

def:pub ContextMenuItem(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    return
        <ContextMenuPrimitive.Item
            {**props}
            data-slot="context-menu-item"
            data-inset={props["inset"]}
            data-variant={variant}
            className={cn(
                "cn-context-menu-item group/context-menu-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
                props["className"]
            )}
        />;
}

def:pub ContextMenuSubTrigger(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.SubTrigger
            {**props}
            data-slot="context-menu-sub-trigger"
            data-inset={props["inset"]}
            className={cn(
                "cn-context-menu-sub-trigger flex cursor-default items-center outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0",
                props["className"]
            )}
        >
            {props["children"]}
            <HugeiconsIcon
                icon={ArrowRight01Icon}
                strokeWidth={2}
                className="cn-rtl-flip ml-auto"
            />
        </ContextMenuPrimitive.SubTrigger>;
}

def:pub ContextMenuSubContent(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.SubContent
            {**props}
            data-slot="context-menu-sub-content"
            className={cn(
                "cn-context-menu-sub-content cn-menu-target z-50 origin-(--radix-context-menu-content-transform-origin) overflow-hidden",
                props["className"]
            )}
        />;
}

def:pub ContextMenuCheckboxItem(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.CheckboxItem
            {**props}
            data-slot="context-menu-checkbox-item"
            data-inset={props["inset"]}
            className={cn(
                "cn-context-menu-checkbox-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
                props["className"]
            )}
            checked={props["checked"]}
        >
            <span className="cn-context-menu-item-indicator pointer-events-none">
                <ContextMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
                </ContextMenuPrimitive.ItemIndicator>
            </span>
            {props["children"]}
        </ContextMenuPrimitive.CheckboxItem>;
}

def:pub ContextMenuRadioItem(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.RadioItem
            {**props}
            data-slot="context-menu-radio-item"
            data-inset={props["inset"]}
            className={cn(
                "cn-context-menu-radio-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
                props["className"]
            )}
        >
            <span className="cn-context-menu-item-indicator pointer-events-none">
                <ContextMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
                </ContextMenuPrimitive.ItemIndicator>
            </span>
            {props["children"]}
        </ContextMenuPrimitive.RadioItem>;
}

def:pub ContextMenuLabel(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.Label
            {**props}
            data-slot="context-menu-label"
            data-inset={props["inset"]}
            className={cn("cn-context-menu-label", props["className"])}
        />;
}

def:pub ContextMenuSeparator(props: any) -> JsxElement {
    return
        <ContextMenuPrimitive.Separator
            {**props}
            data-slot="context-menu-separator"
            className={cn("cn-context-menu-separator", props["className"])}
        />;
}

def:pub ContextMenuShortcut(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <span
            {**attrs}
            data-slot="context-menu-shortcut"
            className={cn("cn-context-menu-shortcut", props["className"])}
        />;
}
