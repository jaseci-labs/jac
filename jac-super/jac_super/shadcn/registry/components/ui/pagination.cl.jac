cl import from ...lib.utils { cn }
cl import from ".button" { Button, buttonVariants }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    ArrowLeft01Icon,
    ArrowRight01Icon,
    MoreHorizontalCircle01Icon
}

cl {
    def:pub Pagination(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <nav
                {**attrs}
                role="navigation"
                aria-label="pagination"
                data-slot="pagination"
                className={cn(
                    "cn-pagination mx-auto flex w-full justify-center",
                    props["className"]
                )}
            />;
    }

    def:pub PaginationContent(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <ul
                {**attrs}
                data-slot="pagination-content"
                className={cn(
                    "cn-pagination-content flex items-center", props["className"]
                )}
            />;
    }

    def:pub PaginationItem(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return <li data-slot="pagination-item" {**attrs}/>;
    }

    def:pub PaginationLink(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        isActive = props["isActive"] or False;
        size = props["size"] or "icon";
        variantsFn: any = buttonVariants();
        computedClass = cn(
            variantsFn.call(
                None, {"variant": isActive and "outline" or "ghost", "size": size}
            ),
            "cn-pagination-link",
            props["className"]
        );
        return
            <a
                {**attrs}
                aria-current={isActive and "page" or None}
                data-slot="pagination-link"
                data-active={isActive}
                className={computedClass}
            />;
    }

    def:pub PaginationPrevious(props: any) -> JsxElement {
        text = props["text"] or "Previous";
        return
            <PaginationLink
                {**props}
                aria-label="Go to previous page"
                size="default"
                className={cn("cn-pagination-previous", props["className"])}
            >
                <HugeiconsIcon
                    icon={ArrowLeft01Icon}
                    strokeWidth={2}
                    data-icon="inline-start"
                    className="cn-rtl-flip"
                />
                <span className="cn-pagination-previous-text hidden sm:block">
                    {text}
                </span>
            </PaginationLink>;
    }

    def:pub PaginationNext(props: any) -> JsxElement {
        text = props["text"] or "Next";
        return
            <PaginationLink
                {**props}
                aria-label="Go to next page"
                size="default"
                className={cn("cn-pagination-next", props["className"])}
            >
                <span className="cn-pagination-next-text hidden sm:block">{text}</span>
                <HugeiconsIcon
                    icon={ArrowRight01Icon}
                    strokeWidth={2}
                    data-icon="inline-end"
                    className="cn-rtl-flip"
                />
            </PaginationLink>;
    }

    def:pub PaginationEllipsis(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <span
                {**attrs}
                aria-hidden={True}
                data-slot="pagination-ellipsis"
                className={cn(
                    "cn-pagination-ellipsis flex items-center justify-center",
                    props["className"]
                )}
            >
                <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2}/>
                <span className="sr-only">More pages</span>
            </span>;
    }
}
