cl import from "radix-ui" { Slot }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon,
    MoreHorizontalCircle01Icon
}

cl {
    def:pub Breadcrumb(props: Any) -> JsxElement {
        return
            <nav
                {...props}
                aria-label="breadcrumb"
                data-slot="breadcrumb"
                className={cn("cn-breadcrumb", props.className)}
            />;
    }

    def:pub BreadcrumbList(props: Any) -> JsxElement {
        return
            <ol
                {...props}
                data-slot="breadcrumb-list"
                className={cn(
                    "cn-breadcrumb-list flex flex-wrap items-center wrap-break-word",
                    props.className
                )}
            />;
    }

    def:pub BreadcrumbItem(props: Any) -> JsxElement {
        return
            <li
                {...props}
                data-slot="breadcrumb-item"
                className={cn(
                    "cn-breadcrumb-item inline-flex items-center", props.className
                )}
            />;
    }

    def:pub BreadcrumbLink(props: Any) -> JsxElement {
        asChild = props.asChild or False;
        if asChild {
            return
                <Slot.Root
                    {...props}
                    data-slot="breadcrumb-link"
                    className={cn("cn-breadcrumb-link", props.className)}
                />;
        }
        return
            <a
                {...props}
                data-slot="breadcrumb-link"
                className={cn("cn-breadcrumb-link", props.className)}
            />;
    }

    def:pub BreadcrumbPage(props: Any) -> JsxElement {
        return
            <span
                {...props}
                data-slot="breadcrumb-page"
                role="link"
                aria-disabled="true"
                aria-current="page"
                className={cn("cn-breadcrumb-page", props.className)}
            />;
    }

    def:pub BreadcrumbSeparator(props: Any) -> JsxElement {
        return
            <li
                {...props}
                data-slot="breadcrumb-separator"
                role="presentation"
                aria-hidden="true"
                className={cn("cn-breadcrumb-separator", props.className)}
            >
                {props.children
                or <HugeiconsIcon
                    icon={ArrowRight01Icon}
                    strokeWidth={2}
                    className="cn-rtl-flip"
                />}
            </li>;
    }

    def:pub BreadcrumbEllipsis(props: Any) -> JsxElement {
        return
            <span
                {...props}
                data-slot="breadcrumb-ellipsis"
                role="presentation"
                aria-hidden="true"
                className={cn(
                    "cn-breadcrumb-ellipsis flex items-center justify-center",
                    props.className
                )}
            >
                <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2}/>
                <span className="sr-only">More</span>
            </span>;
    }
}
