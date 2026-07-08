"""One row in the activity feed / notifications inbox."""

cl {
    import from "@jac/mobui" { View, Text }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub ActivityRow(a: any) -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        col = s["kindColor"](a["kind"]);
        return
            <View style={styles.row} key={a["id"]}>
                <View style={styles.actIcon}>
                    <Icon name={a["icon"]} size={18} color={col} fill={False} width={2}/>
                </View>
                <View style={styles.rowBody}>
                    <Text style={styles.actText}>{a["text"]}</Text>
                    <Text style={styles.actMeta}>{a["meta"]}</Text>
                </View>
            </View>;
    }
}
