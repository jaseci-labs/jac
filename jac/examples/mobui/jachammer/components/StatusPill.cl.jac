"""Project status pill (running / building / failed / stopped)."""

cl {
    import from "@jac/mobui" { View, Text }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub StatusPill(status: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        col = s["statusColor"](status);
        return
            <View style={styles.pill}>
                <Icon name="dot" size={8} color={col} fill={True} width={2}/>
                <Text style={[styles.pillText, {color: col}]}>{s["statusLabel"](status)}</Text>
            </View>;
    }
}
