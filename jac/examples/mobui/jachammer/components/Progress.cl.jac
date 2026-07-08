"""Rollout progress bar."""

cl {
    import from "@jac/mobui" { View, Text }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }

    def:pub Progress(pct: int) -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        return
            <View style={{gap: S.xs}}>
                <View style={styles.progressTrack}>
                    <View style={[styles.progressFill, {width: f"{pct}%"}]}/>
                </View>
                <View style={styles.progressRow}>
                    <Text style={styles.cardMeta}>Rolling out…</Text>
                    <Text style={styles.cardMeta}>{pct}%</Text>
                </View>
            </View>;
    }
}
