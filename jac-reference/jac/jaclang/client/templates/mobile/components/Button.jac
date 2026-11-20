"""Button for {{name}} - a mobUI Pressable with primary / secondary variants."""

import from "@jac/mobui" { Pressable, Text }
import from ..theme { C, S, R, F }

def:pub Button(
    label: str,
    onPress: Callable[[], None],
    variant: str = "primary",
    disabled: bool = False
) -> JsxElement {
    base_styles = {
        paddingVertical: S.md,
        paddingHorizontal: S.lg,
        borderRadius: R.md,
        alignItems: "center",
        justifyContent: "center",
        opacity: 0.5 if disabled else 1.0
    };

    variant_styles = {
        "primary": {backgroundColor: C.accent},
        "secondary": {backgroundColor: C.surface, borderWidth: 1, borderColor: C.border}
    };

    label_styles = {
        color: C.onAccent if variant == "primary" else C.text,
        fontSize: F.md,
        fontWeight: "600"
    };

    <Pressable
        style={[base_styles, variant_styles[variant]]}
        onPress={onPress}
        disabled={disabled}
    >
        <Text style={label_styles}>{label}</Text>
    </Pressable>
}
