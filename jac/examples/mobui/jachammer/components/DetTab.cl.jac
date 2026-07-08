"""Project-detail tab button (Chat / Files / Preview / Deploy / Monitor)."""

cl {
    import from "@jac/mobui" { Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub DetTab(tabKey: str, icon: str, label: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        active = s["detTab"] == tabKey;
        col = C.accent if active else C.muted;
        return
            <Pressable
                style={([styles.detailTab, styles.detailTabActive] if active else styles.detailTab)}
                onPress={lambda {
                    s["setDetTab"](tabKey);
                    if tabKey == "monitor" { s["loadMonitor"](s["selId"]); }
                    if tabKey == "files" { s["loadFiles"](s["selId"]); }
                }}
            >
                <Icon name={icon} size={18} color={col} fill={False} width={2}/>
                <Text style={[styles.detailTabText, {color: col}]}>{label}</Text>
            </Pressable>;
    }
}
