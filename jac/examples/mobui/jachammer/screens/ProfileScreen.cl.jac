"""Profile tab — stats, billing entry, settings (notifications, theme), log out."""

cl {
    import from "@jac/mobui" { View, Text, Pressable, ScrollView }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }
    import from ..components.Toggle { Toggle }

    def:pub ProfileScreen -> JsxElement {
        s = useStudio();
        C = s["C"]; styles = s["styles"];
        projects = s["projects"]; me = s["me"]; plan = s["plan"];
        credits = s["credits"]; appTheme = s["appTheme"]; notifEnabled = s["notifEnabled"];
        running = len([p for p in projects if p["status"] == "running"]);
        themeLabel = "Dark";
        if appTheme == "light" { themeLabel = "Light"; }
        if appTheme == "system" { themeLabel = "System"; }
        return
            <ScrollView style={styles.scroll} contentContainerStyle={styles.scrollBody}>
                <View style={styles.profHead}>
                    <View style={styles.profAvatar}>
                        <Icon name="user" size={40} color={C.accent} fill={False} width={2}/>
                    </View>
                    <Text style={styles.profName}>{me}</Text>
                    <Text style={styles.profHandle}>@{me} · {plan} plan</Text>
                    <View style={styles.statsRow}>
                        <View>
                            <Text style={styles.statBig}>{len(projects)}</Text>
                            <Text style={styles.statLabel}>Projects</Text>
                        </View>
                        <View>
                            <Text style={styles.statBig}>{running}</Text>
                            <Text style={styles.statLabel}>Running</Text>
                        </View>
                        <View>
                            <Text style={styles.statBig}>{credits}</Text>
                            <Text style={styles.statLabel}>Credits</Text>
                        </View>
                    </View>
                </View>
                <Pressable style={styles.primaryBtn} onPress={lambda { s["setBillingOpen"](True); }}>
                    <Icon name="spark" size={16} color={C.accentText} fill={True} width={2}/>
                    <Text style={styles.primaryLabel}>Manage plan &amp; credits</Text>
                </Pressable>
                <Text style={styles.sectionLabel}>Settings</Text>
                <View style={styles.panel}>
                    <Pressable style={styles.row} onPress={lambda { s["setNotifEnabled"](not notifEnabled); }}>
                        <Icon name="bell" size={18} color={C.muted} fill={False} width={2}/>
                        <View style={styles.rowBody}>
                            <Text style={styles.rowTitle}>Deploy notifications</Text>
                            <Text style={styles.rowMeta}>{("On" if notifEnabled else "Off")}</Text>
                        </View>
                        <Toggle on={notifEnabled}/>
                    </Pressable>
                    <Pressable style={styles.rowLast} onPress={s["cycleTheme"]}>
                        <Icon name="palette" size={18} color={C.muted} fill={False} width={2}/>
                        <View style={styles.rowBody}>
                            <Text style={styles.rowTitle}>Theme</Text>
                            <Text style={styles.rowMeta}>Tap to cycle dark · light · system</Text>
                        </View>
                        <View style={styles.pill}>
                            <Text style={[styles.pillText, {color: C.text}]}>{themeLabel}</Text>
                        </View>
                    </Pressable>
                </View>
                <Pressable style={styles.outlineBtn} onPress={s["logout"]}>
                    <Icon name="logout" size={16} color={C.text} fill={False} width={2}/>
                    <Text style={styles.outlineLabel}>Log out</Text>
                </Pressable>
            </ScrollView>;
    }
}
