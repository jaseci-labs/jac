"""Home-composer suggestion chip; prefills the prompt."""

cl {
    import from "@jac/mobui" { Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub SuggChip(text: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        return
            <Pressable style={styles.chip} key={text} onPress={lambda { s["setPrompt"](text); }}>
                <Icon name="spark" size={12} color={C.muted} fill={False} width={2}/>
                <Text style={styles.chipText}>{text}</Text>
            </Pressable>;
    }
}
