cl import from "radix-ui" { Menubar as MenubarPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick02Icon, ArrowRight01Icon }

cl {
    def:pub Menubar(props: any) -> JsxElement {
        return
            <MenubarPrimitive.Root
                {**props}
                data-slot="menubar"
                className={cn("cn-menubar flex items-center", props["className"])}
            />;
    }

    def:pub MenubarMenu(props: any) -> JsxElement {
        return <MenubarPrimitive.Menu data-slot="menubar-menu" {**props}/>;
    }

    def:pub MenubarGroup(props: any) -> JsxElement {
        return <MenubarPrimitive.Group data-slot="menubar-group" {**props}/>;
    }

    def:pub MenubarPortal(props: any) -> JsxElement {
        return <MenubarPrimitive.Portal data-slot="menubar-portal" {**props}/>;
    }

    def:pub MenubarRadioGroup(props: any) -> JsxElement {
        return <MenubarPrimitive.RadioGroup data-slot="menubar-radio-group" {**props}/>;
    }

    def:pub MenubarTrigger(props: any) -> JsxElement {
        return
            <MenubarPrimitive.Trigger
                {**props}
                data-slot="menubar-trigger"
                className={cn(
                    "cn-menubar-trigger flex items-center outline-hidden select-none",
                    props["className"]
                )}
            />;
    }

    def:pub MenubarContent(props: any) -> JsxElement {
        align = props["align"] or "start";
        alignOffset = props["alignOffset"] or -4;
        sideOffset = props["sideOffset"] or 8;
        return
            <MenubarPrimitive.Portal>
                <MenubarPrimitive.Content
                    {**props}
                    data-slot="menubar-content"
                    align={align}
                    alignOffset={alignOffset}
                    sideOffset={sideOffset}
                    className={cn(
                        "cn-menubar-content cn-menu-target z-50 origin-(--radix-menubar-content-transform-origin) overflow-hidden",
                        props["className"]
                    )}
                />
            </MenubarPrimitive.Portal>;
    }

    def:pub MenubarItem(props: any) -> JsxElement {
        variant = props["variant"] or "default";
        return
            <MenubarPrimitive.Item
                {**props}
                data-slot="menubar-item"
                data-inset={props["inset"]}
                data-variant={variant}
                className={cn(
                    "cn-menubar-item group/menubar-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0",
                    props["className"]
                )}
            />;
    }

    def:pub MenubarCheckboxItem(props: any) -> JsxElement {
        return
            <MenubarPrimitive.CheckboxItem
                {**props}
                data-slot="menubar-checkbox-item"
                data-inset={props["inset"]}
                className={cn(
                    "cn-menubar-checkbox-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0",
                    props["className"]
                )}
                checked={props["checked"]}
            >
                <span
                    className="cn-menubar-checkbox-item-indicator pointer-events-none absolute flex items-center justify-center"
                >
                    <MenubarPrimitive.ItemIndicator>
                        <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
                    </MenubarPrimitive.ItemIndicator>
                </span>
                {props["children"]}
            </MenubarPrimitive.CheckboxItem>;
    }

    def:pub MenubarRadioItem(props: any) -> JsxElement {
        return
            <MenubarPrimitive.RadioItem
                {**props}
                data-slot="menubar-radio-item"
                data-inset={props["inset"]}
                className={cn(
                    "cn-menubar-radio-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0",
                    props["className"]
                )}
            >
                <span
                    className="cn-menubar-radio-item-indicator pointer-events-none absolute flex items-center justify-center"
                >
                    <MenubarPrimitive.ItemIndicator>
                        <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
                    </MenubarPrimitive.ItemIndicator>
                </span>
                {props["children"]}
            </MenubarPrimitive.RadioItem>;
    }

    def:pub MenubarLabel(props: any) -> JsxElement {
        return
            <MenubarPrimitive.Label
                {**props}
                data-slot="menubar-label"
                data-inset={props["inset"]}
                className={cn("cn-menubar-label", props["className"])}
            />;
    }

    def:pub MenubarSeparator(props: any) -> JsxElement {
        return
            <MenubarPrimitive.Separator
                {**props}
                data-slot="menubar-separator"
                className={cn(
                    "cn-menubar-separator -mx-1 my-1 h-px", props["className"]
                )}
            />;
    }

    def:pub MenubarShortcut(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <span
                {**attrs}
                data-slot="menubar-shortcut"
                className={cn("cn-menubar-shortcut ml-auto", props["className"])}
            />;
    }

    def:pub MenubarSub(props: any) -> JsxElement {
        return <MenubarPrimitive.Sub data-slot="menubar-sub" {**props}/>;
    }

    def:pub MenubarSubTrigger(props: any) -> JsxElement {
        return
            <MenubarPrimitive.SubTrigger
                {**props}
                data-slot="menubar-sub-trigger"
                data-inset={props["inset"]}
                className={cn(
                    "cn-menubar-sub-trigger flex cursor-default items-center outline-none select-none",
                    props["className"]
                )}
            >
                {props["children"]}
                <HugeiconsIcon
                    icon={ArrowRight01Icon}
                    strokeWidth={2}
                    className="cn-rtl-flip ml-auto size-4"
                />
            </MenubarPrimitive.SubTrigger>;
    }

    def:pub MenubarSubContent(props: any) -> JsxElement {
        return
            <MenubarPrimitive.SubContent
                {**props}
                data-slot="menubar-sub-content"
                className={cn(
                    "cn-menubar-sub-content cn-menu-target z-50 origin-(--radix-menubar-content-transform-origin) overflow-hidden",
                    props["className"]
                )}
            />;
    }
}
