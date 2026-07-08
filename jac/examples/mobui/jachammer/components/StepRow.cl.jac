"""A rollout step row with a done / current / pending dot."""

cl {
    import from "@jac/mobui" { View, Text }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub StepRow(idx: int, label: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        prodStep: int = s["prodStep"];
        done = prodStep > idx;
        hereNow = prodStep == idx;
        bg = C.ok if done else (C.accent if hereNow else C.elevated);
        return
            <View style={styles.stepRow}>
                <View style={[styles.stepDot, {backgroundColor: bg}]}>
                    {(<Icon name="check" size={12} color={C.accentText} fill={False} width={2}/>)
                        if done
                        else (<Text style={[styles.pillText, {color: (C.accentText if hereNow else C.muted)}]}>{idx}</Text>)}
                </View>
                <Text style={styles.stepText}>{label}</Text>
            </View>;
    }
}
