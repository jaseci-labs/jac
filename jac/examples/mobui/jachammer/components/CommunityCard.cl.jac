"""Community gallery card with a Clone action."""

cl {
    import from "@jac/mobui" { View, Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from .Spinner { Spinner }

    def:pub CommunityCard(c: any) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        return
            <View style={styles.commCard} key={c["id"]}>
                <View style={styles.commTopRow}>
                    <View style={styles.cardIcon}>
                        <Icon name="box" size={22} color={C.accent} fill={False} width={2}/>
                    </View>
                    <View style={styles.commBody}>
                        <Text style={styles.cardName}>{c["name"]}</Text>
                        <Text style={styles.cardMeta}>by @{c["author"]} · {c["template"]}</Text>
                    </View>
                </View>
                <Text style={styles.commDesc}>{c["desc"]}</Text>
                <View style={styles.commFoot}>
                    <View style={styles.chip}>
                        <Icon name="star" size={13} color={C.warn} fill={True} width={2}/>
                        <Text style={styles.chipText}>{c["stars"]}</Text>
                    </View>
                    <Pressable style={styles.outlineBtn} onPress={lambda { s["cloneTemplate"](c); }} disabled={s["isBusy"]("clone")}>
                        {(<Spinner color={C.text}/>)
                            if s["isBusy"]("clone")
                            else (<Icon name="clone" size={15} color={C.text} fill={False} width={2}/>)}
                        <Text style={styles.outlineLabel}>Clone</Text>
                    </Pressable>
                </View>
            </View>;
    }
}
