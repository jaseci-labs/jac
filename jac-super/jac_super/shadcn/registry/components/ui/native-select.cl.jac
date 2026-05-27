cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { UnfoldMoreIcon }
cl import from ...lib.utils { cn }

glob _nativeSelectExcludeKeys: list = ["className", "size", "children"];

cl {
    def:pub NativeSelect(props: Any) -> JsxElement {
        size = props.size or "default";

        restProps = {};
        excludeKeys = _nativeSelectExcludeKeys;
        Object.keys(props).forEach(
            lambda (key: Any) { if excludeKeys.indexOf(key) == -1 {
                restProps[key] = props[key];
            }}
        );

        return
            <div
                className={cn(
                    "cn-native-select-wrapper group/native-select relative w-fit has-[select:disabled]:opacity-50",
                    props.className
                )}
                data-slot="native-select-wrapper"
                data-size={size}
            >
                <select
                    data-slot="native-select"
                    data-size={size}
                    className="cn-native-select outline-none disabled:pointer-events-none disabled:cursor-not-allowed"
                    {...restProps}
                >
                    {props.children}
                </select>
                <HugeiconsIcon
                    icon={UnfoldMoreIcon}
                    className="cn-native-select-icon pointer-events-none absolute select-none"
                    aria-hidden="true"
                    data-slot="native-select-icon"
                    size={16}
                />
            </div>;
    }

    def:pub NativeSelectOption(props: Any) -> JsxElement {
        return
            <option data-slot="native-select-option" {...props}>
                {props.children}
            </option>;
    }

    def:pub NativeSelectOptGroup(props: Any) -> JsxElement {
        return
            <optgroup
                data-slot="native-select-optgroup"
                className={props.className}
                {...props}
            >
                {props.children}
            </optgroup>;
    }
}
