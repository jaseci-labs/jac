import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { UnfoldMoreIcon }
import from ...lib.utils { cn }

glob _nativeSelectExcludeKeys: list[str] = ["className", "size", "children"];

def:pub NativeSelect(props: any) -> JsxElement {
    size = props["size"] or "default";

    restProps = {};
    for key in Object.keys(props) {
        if key not in _nativeSelectExcludeKeys {
            restProps[key] = props[key];
        }
    }

    return
        <div
            className={cn(
                "cn-native-select-wrapper group/native-select relative w-fit has-[select:disabled]:opacity-50",
                props["className"]
            )}
            data-slot="native-select-wrapper"
            data-size={size}
        >
            <select
                data-slot="native-select"
                data-size={size}
                className="cn-native-select outline-none disabled:pointer-events-none disabled:cursor-not-allowed"
                {**restProps}
            >
                {props["children"]}
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

def:pub NativeSelectOption(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <option data-slot="native-select-option" {**attrs}>{props["children"]}</option>;
}

def:pub NativeSelectOptGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <optgroup
            data-slot="native-select-optgroup"
            className={props["className"]}
            {**attrs}
        >
            {props["children"]}
        </optgroup>;
}
