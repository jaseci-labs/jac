cl import from "radix-ui" { Slot }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowRight01Icon, MoreHorizontalCircle01Icon }

cl {
    def:pub Breadcrumb(props: Any) -> JsxElement {
        return <nav
            {...props}
            aria-label="breadcrumb"
            data-slot="breadcrumb"
            className={cn("cn-breadcrumb", props.className)}
        />;
    }

    def:pub BreadcrumbList(props: Any) -> JsxElement {
        return <ol
            {...props}
            data-slot="breadcrumb-list"
            className={cn("text-muted-foreground gap-1.5 text-sm flex flex-wrap items-center wrap-break-word", props.className)}
        />;
    }

    def:pub BreadcrumbItem(props: Any) -> JsxElement {
        return <li
            {...props}
            data-slot="breadcrumb-item"
            className={cn("gap-1 inline-flex items-center", props.className)}
        />;
    }

    def:pub BreadcrumbLink(props: Any) -> JsxElement {
        asChild = props.asChild or False;
        if asChild {
            return <Slot.Root
                {...props}
                data-slot="breadcrumb-link"
                className={cn("hover:text-foreground transition-colors", props.className)}
            />;
        }
        return <a
            {...props}
            data-slot="breadcrumb-link"
            className={cn("hover:text-foreground transition-colors", props.className)}
        />;
    }

    def:pub BreadcrumbPage(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="breadcrumb-page"
            role="link"
            aria-disabled="true"
            aria-current="page"
            className={cn("text-foreground font-normal", props.className)}
        />;
    }

    def:pub BreadcrumbSeparator(props: Any) -> JsxElement {
        return <li
            {...props}
            data-slot="breadcrumb-separator"
            role="presentation"
            aria-hidden="true"
            className={cn("[&>svg]:size-3.5", props.className)}
        >
            {props.children or <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="cn-rtl-flip" />}
        </li>;
    }

    def:pub BreadcrumbEllipsis(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="breadcrumb-ellipsis"
            role="presentation"
            aria-hidden="true"
            className={cn("size-5 [&>svg]:size-4 flex items-center justify-center", props.className)}
        >
            <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2} />
            <span className="sr-only">More</span>
        </span>;
    }
}
