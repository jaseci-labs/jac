"""Header credit-balance pill; opens the billing screen."""

cl {
    import from "@jac/mobui" { Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub CreditsPill -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        return
            <Pressable style={styles.creditsPill} onPress={lambda { s["setBillingOpen"](True); }}>
                <Icon name="spark" size={12} color={C.accent} fill={True} width={2}/>
                <Text style={styles.creditsText}>{s["credits"]}</Text>
            </Pressable>;
    }
}
