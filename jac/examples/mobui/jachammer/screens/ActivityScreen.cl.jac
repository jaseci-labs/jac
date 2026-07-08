"""Activity tab — a client-side log of the operations performed this session."""

cl {
    import from "@jac/mobui" { View, Text, ScrollView }
    import from ..ui.icon { Icon }
    import from ..ui.theme { S }
    import from ..hooks.useStudio { useStudio }
    import from ..components.ActivityRow { ActivityRow }

    def:pub ActivityScreen -> JsxElement {
        s = useStudio();
        styles = s["styles"]; C = s["C"];
        activity = s["activity"];
        return
            <ScrollView style={styles.scroll} contentContainerStyle={{paddingBottom: S.huge}}>
                {(
                    <View style={styles.empty}>
                        <Icon name="activity" size={32} color={C.muted} fill={False} width={1.6}/>
                        <Text style={styles.emptyTitle}>No activity yet</Text>
                    </View>
                )
                    if (len(activity) == 0)
                    else (<View>{[<ActivityRow key={a["id"]} a={a}/> for a in activity]}</View>)}
            </ScrollView>;
    }
}
