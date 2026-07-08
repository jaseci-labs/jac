"""Chat message row — user bubble, or AI bubble with a build timeline."""

cl {
    import from "@jac/mobui" { View, Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub MsgRow(m: any) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        if m["role"] == "user" {
            return
                <View style={styles.msgUserRow} key={m["id"]}>
                    <View style={styles.bubbleUser}>
                        <Text style={styles.bubbleUserText}>{m["text"]}</Text>
                    </View>
                </View>;
        }
        return
            <View style={styles.msgAIRow} key={m["id"]}>
                <View style={styles.aiAvatar}>
                    <Icon name="spark" size={16} color={C.accent} fill={True} width={2}/>
                </View>
                <View style={styles.bubbleAI}>
                    {[
                        <View style={styles.tlRow} key={f"{m['id']}-{i}"}>
                            <Icon name="check" size={12} color={C.ok} fill={False} width={2}/>
                            <Text style={styles.tlTextDone}>{step}</Text>
                        </View>
                        for (i, step) in enumerate(m["steps"])
                    ]}
                    {(<Text style={styles.aiText}>{m["text"]}</Text>) if (m["text"] != "") else <View/>}
                    {(
                        <View style={styles.tlRow}>
                            <Icon name="spark" size={12} color={C.accent} fill={True} width={2}/>
                            <Text style={styles.tlText}>working…</Text>
                        </View>
                    )
                        if (not m["done"])
                        else (
                            <Pressable style={styles.revertBtn}>
                                <Icon name="restart" size={12} color={C.muted} fill={False} width={2}/>
                                <Text style={styles.revertText}>Revert this turn</Text>
                            </Pressable>
                        )}
                </View>
            </View>;
    }
}
