"""Bottom nav tab button."""

cl {
    import from "@jac/mobui" { Text, Pressable }
    import from ..ui.icon { Icon }
    import from ..hooks.useStudio { useStudio }

    def:pub TabButton(tabKey: str, icon: str, label: str) -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        C = s["C"];
        active = s["tab"] == tabKey;
        col = C.accent if active else C.muted;
        return
            <Pressable
                style={styles.tabItem}
                onPress={lambda {
                    # closeProject(), not the raw setSelId setter — the selection
                    # is mirrored outside React state for the async build chain,
                    # and only the action keeps the two in step.
                    s["closeProject"]();
                    s["setTab"](tabKey);
                    if tabKey == "community" {
                        s["loadCommunity"]();
                    }
                    if tabKey == "projects" {
                        s["jbLoadProjects"]();
                    }
                }}
            >
                <Icon name={icon} size={22} color={col} fill={active} width={2}/>
                <Text style={[styles.tabLabel, {color: col}]}>{label}</Text>
            </Pressable>;
    }
}
