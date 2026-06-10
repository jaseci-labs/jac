import from "radix-ui" { Slot }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon,
    MoreHorizontalCircle01Icon
}

def:pub Breadcrumb(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <nav
            {**attrs}
            aria-label="breadcrumb"
            data-slot="breadcrumb"
            className={cn("cn-breadcrumb", props["className"])}
        />;
}

def:pub BreadcrumbList(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <ol
            {**attrs}
            data-slot="breadcrumb-list"
            className={cn(
                "cn-breadcrumb-list flex flex-wrap items-center wrap-break-word",
                props["className"]
            )}
        />;
}

def:pub BreadcrumbItem(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <li
            {**attrs}
            data-slot="breadcrumb-item"
            className={cn(
                "cn-breadcrumb-item inline-flex items-center", props["className"]
            )}
        />;
}

def:pub BreadcrumbLink(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    asChild = props["asChild"] or False;
    if asChild {
        return
            <Slot.Root
                {**props}
                data-slot="breadcrumb-link"
                className={cn("cn-breadcrumb-link", props["className"])}
            />;
    }
    return
        <a
            {**attrs}
            data-slot="breadcrumb-link"
            className={cn("cn-breadcrumb-link", props["className"])}
        />;
}

def:pub BreadcrumbPage(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <span
            {**attrs}
            data-slot="breadcrumb-page"
            role="link"
            aria-disabled="true"
            aria-current="page"
            className={cn("cn-breadcrumb-page", props["className"])}
        />;
}

def:pub BreadcrumbSeparator(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <li
            {**attrs}
            data-slot="breadcrumb-separator"
            role="presentation"
            aria-hidden="true"
            className={cn("cn-breadcrumb-separator", props["className"])}
        >
            {props["children"]
            or <HugeiconsIcon
                icon={ArrowRight01Icon}
                strokeWidth={2}
                className="cn-rtl-flip"
            />}
        </li>;
}

def:pub BreadcrumbEllipsis(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <span
            {**attrs}
            data-slot="breadcrumb-ellipsis"
            role="presentation"
            aria-hidden="true"
            className={cn(
                "cn-breadcrumb-ellipsis flex items-center justify-center",
                props["className"]
            )}
        >
            <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2}/>
            <span className="sr-only">More</span>
        </span>;
}
