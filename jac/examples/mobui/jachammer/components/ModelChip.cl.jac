"""Current-AI-model chip; opens the model picker sheet."""

cl {
    import from "@jac/mobui" { Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from ..kit.mappers { modelName }

    def:pub ModelChip -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        C = s["C"];
        return
            <Pressable
                style={styles.modelChip}
                onPress={lambda { s["setModelSheet"](True); }}
            >
                <Icon name="spark" size={12} color={C.muted} fill={True} width={2}/>
                <Text style={styles.modelChipText}>{modelName(s["model"])}</Text>
                <Icon name="chevron" size={12} color={C.muted} fill={False} width={2}/>
            </Pressable>;
    }
}
