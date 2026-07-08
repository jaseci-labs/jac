"""Project summary card used on Home and the Projects tab."""

cl {
    import from "@jac/mobui" { View, Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from .StatusPill { StatusPill }
    import from .Progress { Progress }

    def:pub ProjectCard(p: any) -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        return
            <View style={styles.card} key={p["id"]}>
                <View style={styles.cardTop}>
                    <Pressable style={styles.cardIcon} onPress={lambda { s["openProject"](p["id"]); }}>
                        <Icon name="box" size={22} color={C.accent} fill={False} width={2}/>
                    </Pressable>
                    <Pressable style={styles.cardHeadCol} onPress={lambda { s["openProject"](p["id"]); }}>
                        <Text style={styles.cardName}>{p["name"]}</Text>
                        <View style={styles.cardMetaRow}>
                            <Icon name="branch" size={12} color={C.muted} fill={False} width={2}/>
                            <Text style={styles.cardMeta}>{p["branch"]} · {p["template"]}</Text>
                        </View>
                    </Pressable>
                    <StatusPill status={p["status"]}/>
                    <Pressable style={styles.overflowBtn} onPress={lambda { s["setProjMenu"](p["id"]); }}>
                        <Icon name="dots" size={18} color={C.muted} fill={False} width={2}/>
                    </Pressable>
                </View>
                {(<Progress pct={p["progress"]}/>) if (p["status"] == "building") else <View/>}
                <View style={styles.cardMetaRow}>
                    <Icon name="clock" size={12} color={C.faint} fill={False} width={2}/>
                    <Text style={styles.cardMeta}>Updated {p["updated"]}</Text>
                    <Text style={styles.cardMeta}>·</Text>
                    <Icon name="server" size={12} color={C.faint} fill={False} width={2}/>
                    <Text style={styles.cardMeta}>{len(p["services"])} services</Text>
                </View>
            </View>;
    }
}
