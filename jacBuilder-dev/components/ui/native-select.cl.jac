cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { UnfoldMoreIcon }
cl import from ...lib.utils { cn }

glob _nativeSelectExcludeKeys: list = ["className", "size", "children"];

cl {
    def:pub NativeSelect(props: Any) -> JsxElement {
        size = props.size or "default";

        restProps = {};
        excludeKeys = _nativeSelectExcludeKeys;
        Object.keys(props).forEach(lambda(key: Any) -> None {
            if excludeKeys.indexOf(key) == -1 {
                restProps[key] = props[key];
            }
        });

        return <div
            className={cn("border-input placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 h-8 w-full min-w-0 appearance-none rounded-lg border bg-transparent py-1 pr-8 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] data-[size=sm]:py-0.5-wrapper group/native-select relative w-fit has-[select:disabled]:opacity-50", props.className)}
            data-slot="native-select-wrapper"
            data-size={size}
        >
            <select
                data-slot="native-select"
                data-size={size}
                className="border-input placeholder:text-muted-foreground selection:bg-primary selection:text-primary-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 h-8 w-full min-w-0 appearance-none rounded-lg border bg-transparent py-1 pr-8 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] data-[size=sm]:py-0.5 outline-none disabled:pointer-events-none disabled:cursor-not-allowed"
                {...restProps}
            >
                {props.children}
            </select>
            <HugeiconsIcon
                icon={UnfoldMoreIcon}
                className="text-muted-foreground top-1/2 right-2.5 size-4 -translate-y-1/2 pointer-events-none absolute select-none"
                aria-hidden="true"
                data-slot="native-select-icon"
                size={16}
            />
        </div>;
    }

    def:pub NativeSelectOption(props: Any) -> JsxElement {
        return <option data-slot="native-select-option" {...props}>
            {props.children}
        </option>;
    }

    def:pub NativeSelectOptGroup(props: Any) -> JsxElement {
        return <optgroup
            data-slot="native-select-optgroup"
            className={props.className}
            {...props}
        >
            {props.children}
        </optgroup>;
    }
}
