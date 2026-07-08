"""A DNS record row (A / CNAME) in the deploy tab's production panel."""

cl {
    import from "@jac/mobui" { View, Text }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub DnsRow(kind: str, host: str, val: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        return
            <View style={styles.row}>
                <View style={styles.rowBody}>
                    <Text style={styles.rowTitle}>{kind}  {host}</Text>
                    <Text style={styles.monoSmall}>{val}</Text>
                </View>
                <View style={styles.copyBtn}>
                    <Icon name="clone" size={12} color={C.muted} fill={False} width={2}/>
                    <Text style={styles.chipText}>Copy</Text>
                </View>
            </View>;
    }
}
